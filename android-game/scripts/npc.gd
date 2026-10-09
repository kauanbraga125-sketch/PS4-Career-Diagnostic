class_name StreetNPC
extends CharacterBody3D

var game
var visual: Node3D
var role = "civilian"
var health = 100.0
var phase = 0.0
var target = Vector3.ZERO
var home = Vector3.ZERO
var decision = 0.0
var fire_timer = 1.0
var panic = 0.0
var dead = false
var npc_id = 0
var dead_time = 0.0

func setup(owner_game,style: int,kind: String = "civilian") -> void:
	game = owner_game
	role = kind
	collision_layer = 8
	collision_mask = 1|4
	floor_snap_length = 0.4
	visual = StreetModels.person(4 if kind=="police" else (7 if kind=="enemy" else style))
	add_child(visual)
	var collider = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.85
	collider.shape = capsule
	collider.position.y = 0.93
	add_child(collider)
	if kind in ["police","enemy"]:
		var gun = StreetModels.gun(0)
		visual.get_node("ArmR").add_child(gun)
		gun.position = Vector3(0,-0.55,0)
		gun.rotation.x = PI/2

func _physics_process(dt: float) -> void:
	if not game or not game.running: return
	if dead:
		dead_time += dt
		visual.rotation.z = move_toward(visual.rotation.z,PI/2,dt*5)
		if dead_time>15: queue_free()
		return
	var player_pos = game.focus_position()
	# A rescued passenger stays with the vehicle even across streaming boundaries.
	if role=="hostage" and game.missions.index==5 and game.missions.stage==1 and game.player.vehicle:
		visible = false
		global_position = player_pos+Vector3(1.3,0,0)
		velocity = Vector3.ZERO
		return
	var dist = global_position.distance_to(player_pos)
	visible = dist < game.draw_distance*0.65
	if dist>160: return
	if not game.world.is_loaded(global_position):
		velocity = Vector3.ZERO
		return
	decision -= dt
	panic = maxf(0,panic-dt)
	var aggressive = role=="enemy" or (role=="police" and game.heat>5)
	var direction = Vector3.ZERO
	if aggressive and dist<80:
		direction = (player_pos-global_position).normalized()
		if dist<18: direction *= 0.10
		fire_timer -= dt
		if dist<38 and fire_timer<=0:
			fire_timer = 1.5+randf()*1.3
			var from = global_position+Vector3(0,1.5,0)
			var to = player_pos+Vector3(0,1.2,0)
			var query = PhysicsRayQueryParameters3D.create(from,to,1|2|4)
			var hit = get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and (hit.collider==game.player or hit.collider==game.player.vehicle):
				if randf()<0.58:
					game.player.take_hit(6 if role=="police" else 8)
				game.tracer(from,to,Color("e6b85b"))
	elif role=="hostage" and game.missions.index==5 and game.missions.stage==1:
		visible = game.player.vehicle==null
		if game.player.vehicle:
			global_position = player_pos+Vector3(1.3,0,0)
		elif dist>3:
			direction = (player_pos-global_position).normalized()
	elif panic>0:
		direction = (global_position-player_pos).normalized()
	elif role!="hostage":
		if decision<=0 or position.distance_to(target)<1.3:
			decision = 8+randf()*12
			var block_x = floorf(position.x/120)*120
			var block_z = floorf(position.z/120)*120
			var corners = [Vector3(block_x+18,0,block_z+18),Vector3(block_x+108,0,block_z+18),Vector3(block_x+108,0,block_z+108),Vector3(block_x+18,0,block_z+108)]
			target = CityWorld.ground(corners[randi()%4])
		direction = (target-position).normalized()
	direction.y = 0
	var pace = 3.7 if aggressive or panic>0 else 1.25
	velocity.x = direction.x*pace
	velocity.z = direction.z*pace
	velocity.y -= dt*22
	if is_on_floor(): velocity.y = -0.3
	move_and_slide()
	if direction.length()>0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y,atan2(-direction.x,-direction.z),minf(dt*8,1))
	phase += dt*pace*2.8
	StreetModels.animate_person(visual,phase,0.8 if direction.length()>0.1 else 0.0,aggressive and dist<40)
	for v in game.vehicles:
		if is_instance_valid(v) and absf(v.speed)>8 and v.global_position.distance_squared_to(global_position)<3.1:
			take_hit(absf(v.speed)*5)
			break

func take_hit(damage: float) -> void:
	if dead: return
	health -= damage
	panic = 8
	if role=="civilian" or role=="hostage" or role=="police": game.add_heat(22)
	if health<=0:
		dead = true
		collision_layer = 0
		game.missions.on_defeat(self)
