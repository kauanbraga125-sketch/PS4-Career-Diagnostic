extends Node

var failures: Array[String] = []

func check(value: bool,message: String) -> void:
	if not value:
		failures.append(message)
		push_error("TEST_FAIL: "+message)

func run(game) -> void:
	game.running = true
	game.sound.enabled = false
	await get_tree().physics_frame
	check(game.world.chunks.size()>=4,"Initial playable city chunks loaded")
	check(game.vehicles.size()>=10,"Cars and motorcycles available")
	check(game.pickups.size()==12,"Twelve discoverable weapon placements")
	check(StreetMissions.STORIES.size()==10,"Ten campaign missions")
	# Mount, exit, and character/collision restoration are integration paths.
	var car = game.vehicles[0]
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
		print("PORTO_SELF_TEST_OK: city, vehicles, weapons, 10 missions, conditions, retry, save, respawn")
		get_tree().quit(0)
	else:
		print("PORTO_SELF_TEST_FAILED: ",failures)
		get_tree().quit(1)
