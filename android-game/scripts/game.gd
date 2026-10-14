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
var camera_pitch = -0.12
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
var test_mode=false
var sky_material: ShaderMaterial
var time_of_day=10.5
var weather=0
var weather_timer=0.0
var daylight=1.0
var wind_time=0.0
var death_delay=0.0
var aim_blend=0.0

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
	sky_material=ShaderMaterial.new()
	sky_material.shader=load("res://shaders/coastal_sky.gdshader")
	sky_material.set_shader_parameter("day_sky",load("res://assets/realism/sky/day.png"))
	sky_material.set_shader_parameter("dawn_sky",load("res://assets/realism/sky/morning.png"))
	sky_material.set_shader_parameter("night_sky",load("res://assets/realism/sky/night.png"))
	var noise=FastNoiseLite.new()
	noise.seed=7219;noise.frequency=.055;noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;noise.fractal_octaves=3
	var volume=NoiseTexture3D.new()
	volume.width=64;volume.height=32;volume.depth=64;volume.seamless=true;volume.noise=noise
	sky_material.set_shader_parameter("cloud_noise",volume)
	sky.sky_material=sky_material
	sky.radiance_size=Sky.RADIANCE_SIZE_64
	sky.process_mode=Sky.PROCESS_MODE_REALTIME
	environment.sky=sky
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_color=Color("b8d6ee")
	environment.ambient_light_energy=.36
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled=true
	environment.fog_light_color=Color("a7c8da")
	environment.fog_density=.0006
	time_of_day=float(saved.get("hour",10.5))
	weather=clampi(int(saved.get("weather",0)),0,2)
	var node = WorldEnvironment.new()
	node.environment = environment
	add_child(node)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-34,0)
	sun.light_color = Color("fff3db")
	sun.light_energy = 0.97
	sun.shadow_enabled = false
	add_child(sun)
	update_weather(0)

func update_weather(dt: float) -> void:
	time_of_day=fposmod(time_of_day+dt/60.0,24.0)
	wind_time+=dt
	weather_timer+=dt
	if weather_timer>240:
		weather_timer=0;weather=(weather+1)%3
	var solar=sin((time_of_day-6)/24*TAU)
	daylight=clampf(solar*1.6+.12,0,1)
	var sunset=clampf(1.0-absf(solar)*3,0,1)*daylight
	sky_material.set_shader_parameter("daylight",daylight)
	sky_material.set_shader_parameter("sunset",sunset)
	sky_material.set_shader_parameter("cloudiness",[.3,.65,.95][weather])
	sky_material.set_shader_parameter("wind_time",wind_time)
	sun.rotation_degrees=Vector3(-maxf(12,solar*72),-35+(time_of_day-12)*10,0)
	sun.light_color=Color("a2c5ff").lerp(Color("fff0cc").lerp(Color("ffc38b"),sunset),daylight)
	sun.light_energy=lerpf(.22,.82,daylight)*(1.0-weather*.12)
	environment.ambient_light_energy=lerpf(.30,.32,daylight)
	environment.ambient_light_color=Color("6587b4").lerp(Color("b4d5ed"),daylight)
	environment.fog_light_color=Color("263d60").lerp(Color("a7c8da"),daylight)

func cycle_time() -> void:
	time_of_day=14.0 if time_of_day<8 else (18.2 if time_of_day<17 else (22.0 if time_of_day<21 else 7.0))
	update_weather(0)
	save_game()

func cycle_weather() -> void:
	weather=(weather+1)%3;weather_timer=0
	update_weather(0)
	save_game()

func spawn_vehicles() -> void:
	var spawns = [[78,6,false,0],[44,7,true,0],[125,-95,false,1],[-115,12,true,1],[365,8,false,2],[-475,-115,true,0],[485,14,false,3],[125,252,false,4],[-350,15,true,1],[605,365,false,1]]
	for a in spawns:
		var v = StreetVehicle.new()
		v.setup(self,a[2],a[3])
		add_child(v)
		v.position = CityWorld.ground(Vector3(a[0],0,a[1]),0.15)
		v.rotation.y = -PI/2
		vehicles.append(v)
	# The airfield sits on the port plateau, clear of container traffic.
	for item in [[532.0,629.0,false],[572.0,658.0,true]]:
		var aircraft = StreetAircraft.new()
		aircraft.setup_aircraft(self,item[2])
		add_child(aircraft)
		aircraft.position = CityWorld.ground(Vector3(item[0],0,item[1]),1.0)
		aircraft.rotation.y = PI/2 if item[2] else -PI/2
		vehicles.append(aircraft)

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
	if camera: camera.far = 1800
	sun.shadow_enabled = quality>=1
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X][quality]
	sun.directional_shadow_max_distance = [50.0,75.0,120.0][quality]
	if world: world.set_quality(quality)
	environment.fog_density=[.0012,.0008,.00055][quality]
	sky_material.set_shader_parameter("volumetric",quality==2)

func focus_position() -> Vector3:
	if not player: return START
	return player.vehicle.global_position if player.vehicle else player.global_position

func _process(dt: float) -> void:
	if not hud: return
	hud.queue_redraw()
	if not running:
		sound.update_motor(0,false)
		return
	update_weather(dt)
	if death_pending:
		death_delay-=dt
		update_camera(dt)
		if death_delay<=0: perform_respawn()
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
	sound.update_motor(player.vehicle.speed if player.vehicle else 0,player.vehicle!=null,player.vehicle.throttle if player.vehicle else 0)
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
	aim_blend=move_toward(aim_blend,1.0 if player.aiming and not player.vehicle else 0.0,dt*6)
	distance=lerpf(distance,1.85,aim_blend)
	if player.vehicle is StreetAircraft: distance=14.0
	if player.parachute: distance=10.0
	var orbit = Basis(Vector3.UP,camera_yaw)*Basis(Vector3.RIGHT,camera_pitch)
	var desired = focus+orbit*Vector3(lerpf(.65,.60,aim_blend),lerpf(.5,.08,aim_blend),distance)
	var query = PhysicsRayQueryParameters3D.create(focus,desired,1)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): desired=hit.position+hit.normal*0.25
	camera.global_position = camera.global_position.lerp(desired,minf(dt*12,1))
	camera.look_at(camera.global_position-orbit.z*10,Vector3.UP)
	camera.fov = lerpf(camera.fov,lerpf(68,52,aim_blend)+(absf(player.vehicle.speed)*0.35 if player.vehicle else 0),minf(dt*4,1))

func interact() -> void:
	if player.vehicle:
		var v = player.vehicle
		if v is StreetAircraft and v.global_position.y>CityWorld.elevation(v.global_position.x)+11:
			player.vehicle = null
			v.set_driver(false)
			player.global_position=v.global_position+v.global_basis.x*5+Vector3(0,1,0)
			player.velocity=v.velocity
			player.exit_air_frames=3
			player.collision_layer = 2
			player.visible = true
			controls.clear()
			notify("Salto livre! Toque PARAQUEDAS para abrir; analógico para guiar.",6)
			return
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
	var distance = 6.0
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
		notify(nearest.display_name()+("  /  ACELERAR: voar · SUBIR/DESCER: altitude" if nearest is StreetAircraft else "  /  ACELERAR: dirigir · FREIO: parar"))
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
		var muzzle=player.visual.muzzle()
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
	death_pending=true
	death_delay=3.0
	controls.clear()

func perform_respawn() -> void:
	death_pending = false
	if player.vehicle: player.vehicle.set_driver(false)
	player.vehicle = null
	player.collision_layer = 2
	player.visible = true
	player.position = CityWorld.ground(START,0.2)
	player.velocity = Vector3.ZERO
	player.health=100
	player.visual.recover()
	player.parachute=false
	player.chute_visual.hide()
	player.stamina = 100
	player.parachute = false
	player.chute_visual.visible = false
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
	return {"version":1,"completed":missions.index,"money":money,"position":[p.x,p.y,p.z],"owned":player.owned,"magazines":player.magazines,"reserve":player.reserve,"weapon":player.weapon,"pickups":pickup_ids,"quality":quality,"sound":sound.enabled,"music":sound.music_enabled,"hour":time_of_day,"weather":weather}

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

func capture_frame(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE_SAVED "+path)

func capture_preview() -> void:
	await get_tree().create_timer(3).timeout
	var path=OS.get_environment("PORTO_CAPTURE_PATH")
	if path.is_empty(): path="user://porto-livre-preview.png"
	var base=path.get_basename()
	await capture_frame(path)
	player.pickup(3)
	controls.states["aim"]=true
	await get_tree().create_timer(.7).timeout
	await capture_frame(base+"-aim.png")
	controls.clear()
	time_of_day=22;weather=1
	update_weather(0)
	await get_tree().create_timer(.3).timeout
	await capture_frame(base+"-night.png")
	time_of_day=14;weather=0
	update_weather(0)
	running=false
	var helicopter=vehicles[10] as StreetAircraft
	helicopter.position=CityWorld.ground(Vector3(532,0,629),80)
	helicopter.set_driver(true)
	player.vehicle=helicopter
	player.visible=false
	world.refresh(helicopter.position,true)
	camera_yaw=.65;camera_pitch=-.24
	update_camera(1)
	await capture_frame(base+"-flight.png")
	player.vehicle=null
	player.position=CityWorld.ground(Vector3(-535,0,417))
	world.refresh(player.position,true)
	hud.hide()
	camera.position=Vector3(-485,78,540)
	camera.look_at(Vector3(-600,30,400))
	camera.fov=68
	await capture_frame(base+"-terrain.png")
	var review=Node3D.new()
	add_child(review)
	review.position=Vector3(3000,0,3000)
	var floor_mesh=StreetModels.part(review,Vector3(40,.1,40),Vector3(0,-.1,2),Color.WHITE)
	floor_mesh.material_override=StreetModels.surface("concrete")
	var floor_body=StaticBody3D.new()
	floor_body.collision_layer=1
	review.add_child(floor_body)
	var collider=CollisionShape3D.new()
	var box=BoxShape3D.new()
	box.size=Vector3(40,.5,40)
	collider.shape=box
	collider.position.y=-.3
	floor_body.add_child(collider)
	var actors: Array[StreetActor]=[]
	for i in range(4):
		var actor=StreetModels.person(i)
		review.add_child(actor)
		actor.position=Vector3(-3+i*2,0,-1)
		actors.append(actor)
	var car=StreetModels.car()
	review.add_child(car)
	car.position=Vector3(-3,0,3)
	var bike=StreetVehicle.new()
	bike.setup(self,true,0)
	review.add_child(bike)
	bike.set_driver(true)
	bike.position=Vector3(3,0,3)
	camera.position=review.position+Vector3(2,2.8,-9)
	camera.fov=52
	camera.look_at(review.position+Vector3(0,1.4,0))
	get_viewport().scaling_3d_scale=1
	await capture_frame(base+"-models.png")
	for i in range(4):
		actors[i].animator.play(actors[i].clips[["walk","run","jump","riding"][i]],0)
		actors[i].animator.advance(0)
		actors[i].animator.seek(.25,true)
		actors[i].animator.pause()
	await capture_frame(base+"-movement.png")
	for actor in actors: actor.hide()
	car.hide();bike.hide()
	var air=StreetModels.aircraft(false)
	review.add_child(air)
	air.position=Vector3(-5,0,1)
	var plane=StreetModels.aircraft(true)
	review.add_child(plane)
	plane.position=Vector3(6,0,1)
	camera.position=review.position+Vector3(12,7,-16)
	camera.look_at(review.position+Vector3(0,1.5,0))
	await capture_frame(base+"-aircraft.png")
	air.hide();plane.hide()
	for i in range(4):
		var gun=StreetModels.gun(i)
		review.add_child(gun)
		gun.position=Vector3(-2.5+i*1.7,1,0)
		gun.scale=Vector3.ONE*2
		gun.rotation.y=.45
	camera.position=review.position+Vector3(2,2,-5)
	camera.look_at(review.position+Vector3(0,1.2,0))
	await capture_frame(base+"-weapons.png")
	var fallen=StreetModels.person(0)
	review.add_child(fallen)
	fallen.position=Vector3(0,2,-3)
	camera.position=review.position+Vector3(4,2,-9)
	camera.look_at(review.position+Vector3(1,.6,-3))
	await capture_frame(base+"-ragdoll-before.png")
	await get_tree().create_timer(.3).timeout
	fallen.death_pose(Vector3(2,0,0))
	await get_tree().create_timer(2.5).timeout
	camera.position=review.position+Vector3(4,2,-9)
	camera.look_at(review.position+Vector3(1,.6,-3))
	await capture_frame(base+"-ragdoll.png")
	get_tree().quit()

func run_self_test() -> void:
	var suite = load("res://tests/game_smoke.gd").new()
	add_child(suite)
	await suite.run(self)
