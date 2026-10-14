extends Node

var failures: Array[String] = []

func check(value: bool,message: String) -> void:
	if not value:
		failures.append(message)
		push_error("TEST_FAIL: "+message)

func run(game) -> void:
	game.set_quality(0)
	game.world.refresh(game.player.position,true)
	game.running = true
	game.sound.enabled = false
	await get_tree().physics_frame
	check(game.world.chunks.size()>=4,"Initial playable city chunks loaded")
	check(game.vehicles.size()>=12,"Cars, motorcycles and aircraft available")
	check(game.vehicles[10] is StreetAircraft and game.vehicles[11] is StreetAircraft,"Helicopter and airplane ready for boarding")
	check(game.pickups.size()==12,"Twelve discoverable weapon placements")
	var house=StreetModels.architecture(2,Vector3(12,7,14))
	check(house!=null,"Licensed Kenney building model imported")
	house.free()
	check(StreetMissions.STORIES.size()==10,"Ten campaign missions")
	for clip in ["idle","walk","run","jump","fall","land","death","riding","aim"]:
		check(game.player.visual.clips.has(clip),"Character animation imported: "+clip)
	check(game.player.visual.skeleton.find_bone("RightHand")>=0,"Weapon attaches to an animated hand")
	check(StreetModels.surface("asphalt").albedo_texture!=null,"Photographic road texture imported")
	check(game.sound.clips.music.get_length()>30,"Full music track bundled offline")
	var review_actor = StreetModels.person(0)
	add_child(review_actor)
	var thigh = review_actor.skeleton.find_bone("LeftUpLeg")
	var poses: Array[Quaternion] = []
	for label in ["idle","walk","run","jump"]:
		review_actor.animator.play(review_actor.clips[label],0)
		review_actor.animator.advance(0)
		review_actor.animator.seek(0.25,true)
		review_actor.animator.advance(0)
		poses.append(review_actor.skeleton.get_bone_pose_rotation(thigh))
	print("ANIMATION_POSES: ",poses)
	check(poses[0].angle_to(poses[1])>0.05,"Walking moves the skinned leg from its idle pose")
	check(poses[1].angle_to(poses[2])>0.05,"Running has a distinct stride")
	review_actor.queue_free()
	# Nearby entities outside the active terrain must not fall into unloaded space.
	game.player.position=Vector3(115,0.2,6)
	var idle_car=game.vehicles[2]
	idle_car.position=Vector3(260,0.2,5)
	var waiting_npc=game.spawn_npc(Vector3(260,0,18),2,"hostage")
	check(not game.world.is_loaded(idle_car.position),"Streaming test starts outside loaded terrain")
	for frame in range(40): await get_tree().physics_frame
	check(idle_car.position.y>0,"Vehicle waits safely for terrain collision")
	check(waiting_npc.position.y>0,"NPC waits safely for terrain collision")
	waiting_npc.queue_free()
	# Mount, exit, and character/collision restoration are integration paths.
	var car = game.vehicles[0]
	for wheel in car.wheels:
		if String(wheel.name).begins_with("WFront"):
			check(wheel.position.z<0,"Front wheels face the vehicle's forward movement axis")
	# Simulate real physics ticks: acceleration and contact with a solid wall.
	game.player.position=Vector3(18,0.2,60)
	car.position=Vector3(40,0.2,-6)
	car.rotation.y=-PI/2
	car.set_driver(true)
	game.controls.states["accelerate"]=true
	var wall = StaticBody3D.new()
	wall.collision_layer=1
	game.add_child(wall)
	wall.position=Vector3(70,3,-6)
	var shape=CollisionShape3D.new()
	var box=BoxShape3D.new()
	box.size=Vector3(1,6,12)
	shape.shape=box
	wall.add_child(shape)
	for frame in range(240): await get_tree().physics_frame
	print("PHYSICS_CHECK: car=",car.position," speed=",car.speed," health=",car.health)
	check(car.position.x>45,"Vehicle accelerates and moves through physics ticks")
	check(car.position.x<69,"Vehicle cannot pass through a solid wall")
	check(car.position.y>-1,"Vehicle remains on the road")
	check(car.position.y>-0.02,"Imported tires do not sink under road collision")
	wall.queue_free()
	car.set_driver(false)
	car.speed=0
	game.controls.clear()
	await get_tree().physics_frame
	game.player.position = car.position+Vector3(2.2,0,0)
	await get_tree().physics_frame
	game.interact()
	check(game.player.vehicle==car,"Can enter a nearby car")
	check(game.player.collision_layer==0,"No player/vehicle self-collision while driving")
	car.speed=0
	game.interact()
	check(game.player.vehicle==null and game.player.visible,"Can exit car and restore player")
	check(game.player.collision_layer==2,"Player collisions restored on exit")
	game.player.pickup(0)
	game.player.magazines[0]=0
	game.player.reload_weapon()
	game.player.reload_left=0.001
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(game.player.magazines[0]>0,"Empty magazine reloads from reserve")
	# Independent mobile aiming must move the camera without consuming ammo.
	game.player.position=Vector3(60,.2,6)
	game.world.refresh(game.player.position,true)
	game.controls.clear()
	game.controls.states["aim"]=true
	var ammo_before=game.player.magazines[0]
	for frame in range(30): await get_tree().physics_frame
	check(game.player.aiming and game.aim_blend>.9,"Aiming enters shoulder camera independently")
	check(game.camera.fov<57,"Aiming narrows the camera FOV")
	check(game.player.magazines[0]==ammo_before,"Aiming alone does not fire")
	game.controls.states["fire"]=true
	for frame in range(3): await get_tree().physics_frame
	check(game.player.magazines[0]<ammo_before,"Fire works while independently holding aim")
	game.controls.clear()
	game.heat=0
	# Ragdoll must physically fall and remain bounded on actual streamed terrain.
	var body_actor=StreetModels.person(2)
	game.add_child(body_actor)
	body_actor.position=Vector3(65,3,6)
	await get_tree().physics_frame
	body_actor.death_pose(Vector3(1,0,0))
	check(body_actor.simulator.is_simulating_physics(),"Ragdoll simulation starts")
	var hips=body_actor.simulator.get_node("Body_Hips") as PhysicalBone3D
	var start_height=hips.global_position.y
	for frame in range(100): await get_tree().physics_frame
	print("RAGDOLL_CHECK: start=",start_height," end=",hips.global_position)
	check(hips.global_position.y<start_height-.7,"Ragdoll falls under gravity")
	check(hips.global_position.y>-.3 and hips.global_position.distance_to(Vector3(65,0,6))<9,"Ragdoll collides with terrain and joints stay bounded")
	body_actor.recover()
	check(not body_actor.simulator.is_simulating_physics() and not body_actor.dead,"Ragdoll can return to animation")
	body_actor.queue_free()
	# Helicopter climb, real ejection, manual chute opening and safe descent.
	var helicopter=game.vehicles[10] as StreetAircraft
	helicopter.position=Vector3(78,.4,6)
	helicopter.rotation.y=0
	game.player.vehicle=helicopter
	game.player.collision_layer=0
	helicopter.set_driver(true)
	game.controls.states["climb"]=true
	for frame in range(100): await get_tree().physics_frame
	check(helicopter.position.y>11,"Helicopter gains controllable altitude")
	game.controls.clear()
	game.interact()
	check(game.player.vehicle==null and game.player.visible and not game.player.parachute,"Aircraft ejection starts free fall")
	game.controls.presses["parachute"]=true
	for frame in range(35): await get_tree().physics_frame
	print("CHUTE_CHECK: open=",game.player.parachute," velocity=",game.player.velocity," pos=",game.player.position)
	check(game.player.parachute and game.player.velocity.y>=-4.3,"Manual parachute slows descent")
	for frame in range(280): await get_tree().physics_frame
	check(game.player.is_on_floor() and not game.player.parachute and game.player.health>0,"Parachute lands safely and folds")
	# A biplane cannot climb while stationary, but can take off with airspeed.
	var plane=game.vehicles[11] as StreetAircraft
	plane.position=Vector3(40,.2,6)
	plane.rotation.y=PI/2
	plane.speed=0
	plane.flight_lift=0
	plane.set_driver(true)
	game.player.vehicle=plane
	game.player.collision_layer=0
	game.controls.clear()
	game.controls.states["climb"]=true
	for frame in range(20): await get_tree().physics_frame
	check(plane.position.y<2,"Aircraft cannot take off without speed")
	game.controls.states["accelerate"]=true
	for frame in range(260): await get_tree().physics_frame
	print("FLIGHT_CHECK: speed=",plane.speed," pos=",plane.position)
	check(plane.speed>18 and plane.position.y>5,"Airplane accelerates and takes off")
	plane.set_driver(false)
	game.player.vehicle=null
	game.player.collision_layer=2
	game.player.position=Vector3(60,.2,6)
	game.controls.clear()
	game.time_of_day=12
	game.update_weather(0)
	var daytime=game.sun.light_energy
	game.time_of_day=23
	game.update_weather(0)
	check(game.daylight<.2 and game.sun.light_energy<daytime*.5,"Day/night changes world illumination")
	game.time_of_day=10.5
	game.weather=2
	game.update_weather(0)
	check(game.sky_material.get_shader_parameter("cloudiness")>.9,"Overcast weather changes sky density")
	game.weather=0
	game.update_weather(0)
	# Advance using objective conditions, not calling mission-complete directly.
	for mission in range(10):
		game.missions.start(mission)
		check(game.missions.index==mission,"Mission starts: "+str(mission+1))
		if mission==4:
			for body in game.missions.entities:
				if is_instance_valid(body) and body.get_meta("range_target",false): game.missions.hit_target(body)
			game.missions.tick(0.01)
		else:
			for step in range(game.missions.targets.size()):
				var p = game.missions.current_target()
				if mission in [1,9]: game.player.vehicle=game.vehicles[0]
				elif mission in [2,6]: game.player.vehicle=game.vehicles[1]
				else: game.player.vehicle=null
				if game.player.vehicle: game.player.vehicle.position=p
				else: game.player.position=p
				if mission in [5,9]:
					for npc in game.missions.entities.duplicate():
						if is_instance_valid(npc) and npc is StreetNPC and npc.role=="enemy" and not npc.dead: npc.take_hit(1000)
				if mission==8: game.heat=0
				game.missions.tick(0.01)
		check(game.missions.index==mission+1,"Mission completion reachable: "+str(mission+1))
	game.player.vehicle=null
	game.missions.start(2)
	game.player.position=game.missions.current_target()
	game.missions.tick(0.01)
	check(game.missions.stage==0,"Motorcycle mission rejects walking")
	game.player.vehicle=game.vehicles[0]
	game.vehicles[0].position=game.missions.current_target()
	game.missions.tick(0.01)
	check(game.missions.stage==0,"Motorcycle mission rejects a car")
	game.player.vehicle=game.vehicles[1]
	game.missions.countdown=0.001
	game.missions.tick(1)
	check(game.missions.stage==0 and game.missions.countdown==180,"Failed race can restart")
	var saved = game.save_data()
	check(JSON.parse_string(JSON.stringify(saved)).completed==game.missions.index,"Save round-trip retains campaign progress")
	game.player.vehicle=null
	game.player.take_hit(1000)
	game.perform_respawn()
	check(game.player.health==100 and game.player.vehicle==null,"Death restores a playable on-foot state")
	game.running=false
	if failures.is_empty():
		print("PORTO_SELF_TEST_OK: city, vehicles, shoulder aim, ragdoll, helicopter, airplane, parachute, weather, 10 missions, retry, save, respawn")
		get_tree().quit(0)
	else:
		print("PORTO_SELF_TEST_FAILED: ",failures)
		get_tree().quit(1)
