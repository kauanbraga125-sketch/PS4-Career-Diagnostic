extends Node3D

const SAVE_PATH = "user://porto_livre_v1.json"
const START = Vector3(60,0,6)
const PICKUPS = [
	[-108,-360,0],[255,18,1],[-468,-120,2],[612,258,3],
	[138,18,0],[-348,258,1],[498,-108,2],[-108,498,3],
	[18,-588,0],[618,498,2],[-588,-468,3],[378,378,1]
]
var world: CityWorld
var player: StreetPlayer
var controls: StreetControls
var missions: StreetMissions
var sound: StreetSound
var hud: StreetHUD
var camera: Camera3D
var sun: DirectionalLight3D
var environment: Environment
var vehicles: Array[StreetVehicle] = []
var citizens: Array[StreetNPC] = []
var pickups: Array[Node3D] = []
var pickup_ids: Array = []
var saved: Dictionary = {}
var running = false
var quality = 2
var draw_distance = 235.0
var camera_yaw = -PI/2
var camera_pitch = -0.24
var camera_look_idle = 0.0
var heat = 0.0
var money = 0
var damage_flash = 0.0
var notice = ""
var notice_time = 0.0
var population_timer = 0.0
var heat_timer = 0.0
var save_timer = 0.0
var frame_timer = 0.0
var frame_samples = 0
var fps = 60.0
var dynamic_resolution = 0.80
var death_pending = false
var footstep = 0.0
var test_mode = false

func _ready() -> void:
	test_mode = "--self-test" in OS.get_cmdline_user_args()
	if not test_mode: saved = read_save()
	quality = clampi(int(saved.get("quality",2)),0,2)
	money = int(saved.get("money",0))
	pickup_ids = saved.get("pickups",[])
	setup_environment()
	controls = StreetControls.new()
	controls.game = self
	add_child(controls)
	sound = StreetSound.new()
	add_child(sound)
	sound.enabled = saved.get("sound",true)
	sound.music_enabled = saved.get("music",true)
	world = CityWorld.new()
	add_child(world)
	world.setup(self)
	player = StreetPlayer.new()
	player.setup(self)
	add_child(player)
	player.position = CityWorld.ground(START,0.15)
	if saved.has("position"):
		var p = saved.position
		if p is Array and p.size()==3:
			player.position = CityWorld.ground(Vector3(clampf(float(p[0]),-690,690),0,clampf(float(p[2]),-690,690)),0.3)
	if saved.has("owned") and saved.owned is Array and saved.owned.size()==4:
		player.owned = saved.owned
		for i in range(4):
			player.magazines[i] = int(clampf(float(saved.get("magazines",[0,0,0,0])[i]),0,StreetPlayer.CAPACITY[i]))
			player.reserve[i] = maxi(0,int(saved.get("reserve",[0,0,0,0])[i]))
		var equip = clampi(int(saved.get("weapon",-1)),-1,3)
		if equip>=0: player.equip(equip)
	camera = Camera3D.new()
	camera.fov = 68
	camera.near = 0.12
	add_child(camera)
	camera.current = true
	camera.position = player.position+Vector3(0,3.1,5)
	spawn_vehicles()
	spawn_pickups()
	missions = StreetMissions.new()
	missions.index = clampi(int(saved.get("completed",0)),0,10)
	add_child(missions)
	missions.setup(self)
	var canvas = CanvasLayer.new()
	add_child(canvas)
	hud = StreetHUD.new()
	hud.game = self
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(hud)
	set_quality(quality)
	world.refresh(player.position,true)
	update_camera(1.0)
	if test_mode:
		call_deferred("run_self_test")
	elif "--capture" in OS.get_cmdline_user_args():
		start_game()
		call_deferred("capture_preview")

func setup_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("658fa8")
	sky_material.sky_horizon_color = Color("d6ceb8")
	sky_material.ground_horizon_color = Color("d6ceb8")
	sky_material.ground_bottom_color = Color("58675b")
	sky_material.sun_angle_max = 3
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_color = Color("c8d6d6")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("bdc8c4")
	environment.fog_density = 0.0025
	var node = WorldEnvironment.new()
	node.environment = environment
	add_child(node)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-34,0)
	sun.light_color = Color("fff1d9")
	sun.light_energy = 0.88
	sun.shadow_enabled = false
	add_child(sun)

func spawn_vehicles() -> void:
	var spawns = [[78,6,false,0],[44,7,true,0],[125,-95,false,1],[-115,12,true,1],[365,8,false,2],[-475,-115,true,0],[485,14,false,3],[125,252,false,4],[-350,15,true,1],[605,365,false,1]]
	for a in spawns:
		var v = StreetVehicle.new()
		v.setup(self,a[2],a[3])
		add_child(v)
		v.position = CityWorld.ground(Vector3(a[0],0,a[1]),0.15)
		v.rotation.y = -PI/2
		vehicles.append(v)

func spawn_pickups() -> void:
	for i in range(PICKUPS.size()):
		if i in pickup_ids: continue
		var a = PICKUPS[i]
		var node = Node3D.new()
		node.set_meta("id",i)
		node.set_meta("kind",a[2])
		add_child(node)
		node.position = CityWorld.ground(Vector3(a[0],0,a[1]),0.1)
		StreetModels.part(node,Vector3(1.25,0.35,0.8),Vector3(0,0.18,0),Color("6d7869"))
		var gun = StreetModels.gun(a[2])
		gun.position.y = 1.25
		gun.scale = Vector3.ONE*2.2
		gun.name = "Display"
		node.add_child(gun)
		var label = Label3D.new()
		label.text = StreetPlayer.WEAPONS[a[2]]
		label.font_size = 38
		label.pixel_size = 0.014
		label.modulate = Color("f0c676")
		label.position.y = 2.2
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.visibility_range_end = 45
		node.add_child(label)
		pickups.append(node)

func start_game() -> void:
	running = true
	hud.show_briefing = false
	controls.clear()
	if not controls.mobile: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	notify(StreetMissions.STORIES[missions.index][1] if missions.index<10 else "Bem-vindo de volta a Porto Livre.",7)

func toggle_pause() -> void:
	if hud.credits_open:
		hud.credits_open = false
		return
	if hud.map_open:
		hud.map_open = false
		running = true
	elif running:
		running = false
		save_game()
	else:
		start_game()
	controls.clear()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if running and not controls.mobile else Input.MOUSE_MODE_VISIBLE

func set_quality(value: int) -> void:
	quality = clampi(value,0,2)
	draw_distance = [235.0,350.0,470.0][quality]
	dynamic_resolution = [0.72,0.86,1.0][quality]
	get_viewport().scaling_3d_scale = dynamic_resolution
	Engine.max_fps = 30 if quality==0 else 60
	if camera: camera.far = draw_distance
	sun.shadow_enabled = quality>=1
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X][quality]
	sun.directional_shadow_max_distance = [50.0,75.0,120.0][quality]
	if world: world.set_quality(quality)
	environment.fog_density = [0.0035,0.0022,0.0015][quality]

func focus_position() -> Vector3:
	if not player: return START
	return player.vehicle.global_position if player.vehicle else player.global_position

func _process(dt: float) -> void:
	if not hud: return
	hud.queue_redraw()
	if not running:
		sound.update_motor(0,false)
		return
	if death_pending:
		perform_respawn()
		return
	if controls.consume("pause"): toggle_pause(); return
	if controls.consume("map"):
		hud.map_open = true
		running = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		controls.clear()
		return
	if controls.consume("briefing"):
		hud.show_briefing = true
		toggle_pause()
		return
	if controls.consume("enter"): interact()
	if controls.consume("weapon"): player.cycle_weapon()
	if controls.consume("reload"): player.reload_weapon()
	update_camera(dt)
	missions.tick(dt)
	notice_time = maxf(0,notice_time-dt)
	damage_flash = maxf(0,damage_flash-dt)
	for node in pickups:
		if not is_instance_valid(node): continue
		var d = node.position.distance_to(focus_position())
		node.visible = d<75
		if d<75: node.get_node("Display").rotation.y += dt
		if d<2.5 and not player.vehicle:
			player.pickup(node.get_meta("kind"))
			pickup_ids.append(node.get_meta("id"))
			node.queue_free()
			save_game()
	population_timer -= dt
	if population_timer<=0:
		population_timer = 3
		update_population()
	update_heat(dt)
	save_timer += dt
	if save_timer>30:
		save_timer = 0
		save_game()
	frame_timer += dt
	frame_samples += 1
	if frame_timer>3:
		fps = frame_samples/frame_timer
		var target_fps = 28.0 if quality==0 else 50.0
		if fps<target_fps: dynamic_resolution=maxf([0.60,0.70,0.80][quality],dynamic_resolution-0.035)
		elif fps>target_fps+4: dynamic_resolution=minf([0.75,0.88,1.0][quality],dynamic_resolution+0.02)
		get_viewport().scaling_3d_scale = dynamic_resolution
		frame_timer = 0
		frame_samples = 0
	sound.update_motor(player.vehicle.speed if player.vehicle else 0,player.vehicle!=null)
	if not player.vehicle and Vector2(player.velocity.x,player.velocity.z).length()>1 and player.is_on_floor():
		footstep -= dt
		if footstep<=0:
			footstep = 0.34 if controls.held("sprint") else 0.48
			sound.play("step")

func update_camera(dt: float) -> void:
	if controls.look_delta.length()>0:
		camera_yaw -= controls.look_delta.x
		camera_pitch = clampf(camera_pitch-controls.look_delta.y,-0.90,0.45)
		controls.look_delta = Vector2.ZERO
		camera_look_idle = 0
	else:
		camera_look_idle += dt
	if player.vehicle and camera_look_idle>1.5 and absf(player.vehicle.speed)>1:
		camera_yaw = lerp_angle(camera_yaw,player.vehicle.rotation.y,minf(dt*1.4,1))
	var focus = focus_position()+Vector3(0,1.55 if not player.vehicle else 1.75,0)
	var distance = 5.4 if not player.vehicle else 8.0
	if controls.held("fire") and not player.vehicle: distance = 2.9
	var orbit = Basis(Vector3.UP,camera_yaw)*Basis(Vector3.RIGHT,camera_pitch)
	var desired = focus+orbit*Vector3(0.65,0.5,distance)
	var query = PhysicsRayQueryParameters3D.create(focus,desired,1)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): desired=hit.position+hit.normal*0.25
	camera.global_position = camera.global_position.lerp(desired,minf(dt*12,1))
	camera.look_at(focus-orbit.z*10,Vector3.UP)
	camera.fov = lerpf(camera.fov,68+(absf(player.vehicle.speed)*0.35 if player.vehicle else 0),minf(dt*4,1))

func interact() -> void:
	if player.vehicle:
		var v = player.vehicle
		if absf(v.speed)>5:
			notify("Freie antes de sair do veículo.")
			return
		var exit_position = Vector3.ZERO
		var safe = false
		for side in [1,-1]:
			var p = v.global_position+v.global_basis.x*2.2*side+Vector3(0,0.25,0)
			var query = PhysicsShapeQueryParameters3D.new()
			var capsule = CapsuleShape3D.new()
			capsule.radius = 0.35
			capsule.height = 1.8
			query.shape = capsule
			query.transform.origin = p+Vector3(0,0.9,0)
			query.collision_mask = 1|4
			if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
				exit_position=p
				safe=true
				break
		if not safe: notify("Sem espaço para sair. Mova o veículo."); return
		player.vehicle = null
		sound.play("door")
		v.set_driver(false)
		player.position = exit_position
		player.velocity = Vector3.ZERO
		player.collision_layer = 2
		player.visible = true
		camera_yaw = v.rotation.y
		return
	var nearest: StreetVehicle
	var distance = 4.2
	for v in vehicles:
		if is_instance_valid(v) and v.health>0:
			var d = v.global_position.distance_to(player.position)
			if d<distance: nearest=v; distance=d
	if nearest:
		player.vehicle = nearest
		sound.play("door")
		player.collision_layer = 0
		player.visible = false
		nearest.set_driver(true)
		camera_yaw = nearest.rotation.y
		controls.clear()
		notify(nearest.display_name()+"  /  analógico: dirigir · FREIO: parar")
	elif player.position.distance_to(CityWorld.ground(Vector3(60,0,18)))<14:
		player.health=100
		for i in range(4):
			if player.owned[i]: player.reserve[i]=maxi(player.reserve[i],48)
		for v in vehicles:
			if v.position.distance_to(player.position)<45: v.health=100
		notify("Oficina: saúde, munição e veículos próximos recuperados.")
		save_game()
	else:
		notify("Aproxime-se de um veículo para entrar. Armas são recolhidas a pé.")

func fire_weapon(kind: int,damage: float) -> void:
	var origin = camera.global_position
	var basis_aim = camera.global_basis
	var count = 7 if kind==2 else 1
	for pellet in range(count):
		var spread = 0.045 if kind==2 else (0.012 if kind==1 else 0.003)
		var direction = (-basis_aim.z+basis_aim.x*randf_range(-spread,spread)+basis_aim.y*randf_range(-spread,spread)).normalized()
		var endpoint = origin+direction*180
		var query = PhysicsRayQueryParameters3D.create(origin,endpoint,1|4|8|16,[player.get_rid()])
		var hit = get_world_3d().direct_space_state.intersect_ray(query)
		var muzzle = player.position+Vector3(0,1.4,0)-Basis(Vector3.UP,camera_yaw).z*0.5
		if not hit.is_empty(): endpoint=hit.position
		# A second ray from the character prevents shooting through nearby cover.
		var obstruction = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle,endpoint,1,[player.get_rid()]))
		if not obstruction.is_empty(): hit=obstruction; endpoint=obstruction.position
		if not hit.is_empty():
			var body = hit.collider
			if body.get_meta("range_target",false): missions.hit_target(body)
			elif body.has_method("take_hit"): body.take_hit(damage)
		tracer(muzzle,endpoint,Color("e5c488"))
	for npc in citizens:
		if is_instance_valid(npc) and npc.position.distance_to(player.position)<40: npc.panic=8
	if missions.index!=4: add_heat(1.5)

func tracer(a: Vector3,b: Vector3,color: Color) -> void:
	if a.distance_to(b)<0.01: return
	var beam = StreetModels.segment(self,a,b,0.024,color)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var timer = get_tree().create_timer(0.06)
	timer.timeout.connect(beam.queue_free)

func spawn_npc(pos: Vector3,style: int,role: String = "civilian") -> StreetNPC:
	var npc = StreetNPC.new()
	npc.setup(self,style,role)
	add_child(npc)
	npc.position = CityWorld.ground(pos,0.15)
	npc.home = npc.position
	npc.target = npc.position
	npc.scale = Vector3.ONE*(0.91+float(style%4)*0.045)
	citizens.append(npc)
	return npc

func update_population() -> void:
	var pos = focus_position()
	var live = 0
	for i in range(citizens.size()-1,-1,-1):
		var npc = citizens[i]
		if not is_instance_valid(npc): citizens.remove_at(i); continue
		if npc.role=="civilian":
			if npc.position.distance_to(pos)>160:
				npc.queue_free()
				citizens.remove_at(i)
			else: live+=1
	var budget = [10,18,28][quality]
	for i in range(mini(3,budget-live)):
		var p = pos+Vector3(randf_range(-100,100),0,randf_range(-100,100))
		p.x = floorf(p.x/120)*120+18
		p.z = clampf(p.z,-675,675)
		p.x = clampf(p.x,-675,675)
		spawn_npc(p,randi()%8)
	var traffic_count = 0
	for v in vehicles:
		if v.traffic:
			traffic_count += 1
			if v.position.distance_to(pos)>330:
				v.position = CityWorld.ground(Vector3(clampf(floorf(pos.x/120)*120+8,-670,670),0,clampf(pos.z+100,-650,650)),0.3)
	if traffic_count<[2,4,6][quality]:
		var v = StreetVehicle.new()
		v.setup(self,false,randi()%5,true)
		add_child(v)
		v.position = CityWorld.ground(Vector3(clampf(floorf(pos.x/120)*120+8,-670,670),0,clampf(pos.z-90,-650,650)),0.3)
		vehicles.append(v)

func add_heat(amount: float) -> void:
	heat = clampf(heat+amount,0,100)
	heat_timer = 10

func spawn_patrol() -> void:
	var existing = 0
	for npc in citizens:
		if is_instance_valid(npc) and npc.role=="police" and not npc.dead: existing+=1
	if existing>=3: return
	var pos = focus_position()
	for i in range(3-existing):
		var p = pos+Vector3(40+i*8,0,60)
		p.x = floorf(p.x/120)*120+18
		p.x = clampf(p.x,-690,690)
		p.z = clampf(p.z,-690,690)
		spawn_npc(p,4,"police")

func update_heat(dt: float) -> void:
	if heat<=0: return
	if heat>30: spawn_patrol()
	heat_timer = maxf(0,heat_timer-dt)
	var seen = false
	for npc in citizens:
		if is_instance_valid(npc) and npc.role=="police" and not npc.dead and npc.position.distance_to(focus_position())<52:
			var from = npc.position+Vector3(0,1.5,0)
			var to = focus_position()+Vector3(0,1.2,0)
			var ray = PhysicsRayQueryParameters3D.create(from,to,1)
			if get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): seen=true; break
	if not seen and heat_timer<=0: heat=maxf(0,heat-dt*3)

func respawn() -> void:
	death_pending = true

func perform_respawn() -> void:
	death_pending = false
	if player.vehicle: player.vehicle.set_driver(false)
	player.vehicle = null
	player.collision_layer = 2
	player.visible = true
	player.position = CityWorld.ground(START,0.2)
	player.velocity = Vector3.ZERO
	player.health = 100
	player.stamina = 100
	heat = 0
	money = maxi(0,money-100)
	world.refresh(player.position,true)
	missions.start(missions.index)
	notify("Recuperado na oficina. A missão atual foi reiniciada.",5)
	save_game()

func notify(message: String,duration: float = 3.5) -> void:
	notice = message
	notice_time = duration

func save_data() -> Dictionary:
	var p = focus_position()
	return {"version":1,"completed":missions.index,"money":money,"position":[p.x,p.y,p.z],"owned":player.owned,"magazines":player.magazines,"reserve":player.reserve,"weapon":player.weapon,"pickups":pickup_ids,"quality":quality,"sound":sound.enabled,"music":sound.music_enabled}

func save_game() -> void:
	if test_mode or not missions or not player: return
	var file = FileAccess.open(SAVE_PATH+".tmp",FileAccess.WRITE)
	if not file: notify("Não foi possível salvar o progresso."); return
	file.store_string(JSON.stringify(save_data()))
	file.flush()
	file.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH+".bak")
		DirAccess.rename_absolute(SAVE_PATH,SAVE_PATH+".bak")
	if DirAccess.rename_absolute(SAVE_PATH+".tmp",SAVE_PATH)!=OK: notify("Falha ao salvar; o backup anterior foi preservado.")

func read_save() -> Dictionary:
	for path in [SAVE_PATH,SAVE_PATH+".bak"]:
		if not FileAccess.file_exists(path): continue
		var value = JSON.parse_string(FileAccess.get_file_as_string(path))
		if value is Dictionary and value.get("version",0)==1:
			var valid = true
			for key in ["owned","magazines","reserve"]:
				if not value.get(key) is Array or value[key].size()!=4: valid=false
			if valid: return value
	return {}

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_PAUSED and is_instance_valid(hud):
		save_game()
		running = false
		controls.clear()
	if what==NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(hud): toggle_pause()
	if what==NOTIFICATION_WM_CLOSE_REQUEST: save_game()

func capture_preview() -> void:
	await get_tree().create_timer(3).timeout
	await RenderingServer.frame_post_draw
	var path = OS.get_environment("PORTO_CAPTURE_PATH")
	if path.is_empty(): path="user://porto-livre-preview.png"
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE_SAVED "+path)
	# A second in-engine view checks imported materials, scale and handedness.
	running = false
	hud.hide()
	var review = Node3D.new()
	add_child(review)
	review.position = Vector3(3000,0,3000)
	var floor_mesh = StreetModels.part(review,Vector3(32,0.1,32),Vector3(0,-0.1,2),Color.WHITE)
	floor_mesh.material_override = StreetModels.surface("concrete")
	var actors: Array[StreetActor] = []
	for i in range(4):
		var actor = StreetModels.person(i)
		review.add_child(actor)
		actor.position = Vector3(-3+i*2,0,-1)
		actors.append(actor)
	var review_car = StreetModels.car()
	review.add_child(review_car)
	review_car.position = Vector3(-3,0,3)
	var review_bike = StreetVehicle.new()
	review_bike.setup(self,true,0)
	review.add_child(review_bike)
	review_bike.set_driver(true)
	review_bike.position = Vector3(3,0,3)
	var review_tree = StreetModels.imported("tree")
	review.add_child(review_tree)
	review_tree.position = Vector3(-6,0,6)
	review_tree.scale = Vector3.ONE*0.55
	camera.position = review.position+Vector3(2,2.8,-9)
	camera.fov = 52
	camera.look_at(review.position+Vector3(0,1.4,0))
	get_viewport().scaling_3d_scale = 1.0
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path.get_basename()+"-models.png")
	for i in range(4):
		actors[i].animator.play(actors[i].clips[["walk","run","jump","riding"][i]],0)
		actors[i].animator.advance(0)
		actors[i].animator.seek(0.25,true)
		actors[i].animator.pause()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path.get_basename()+"-movement.png")
	get_tree().quit()

func run_self_test() -> void:
	var suite = load("res://tests/game_smoke.gd").new()
	add_child(suite)
	await suite.run(self)
