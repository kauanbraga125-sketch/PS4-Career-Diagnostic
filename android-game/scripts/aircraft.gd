class_name StreetAircraft
extends StreetVehicle

# Lightweight arcade flight model for the mobile Compatibility renderer.
var airplane = false
var rotor: Node3D
var flight_lift = 0.0

func setup_aircraft(owner_game,plane: bool) -> void:
	game = owner_game
	airplane = plane
	collision_layer = 4
	collision_mask = 1|2|4
	floor_snap_length = 0.25
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(3.0,2.0,7.0) if plane else Vector3(2.5,2.0,5.0)
	shape.shape = box
	shape.position.y = 1.05
	add_child(shape)
	visual = StreetModels.aircraft(airplane)
	add_child(visual)
	rotor = visual.get_node_or_null("Rotor") as Node3D

func _physics_process(dt: float) -> void:
	if not game or not game.running: return
	if not driver and (not game.world.is_loaded(global_position) or global_position.distance_squared_to(game.focus_position())>400.0*400.0):
		velocity = Vector3.ZERO
		return
	if driver:
		var gas = maxf(-game.controls.move.y,1.0 if game.controls.held("accelerate") else 0.0)
		var steer = game.controls.move.x
		var rise = (1.0 if game.controls.held("jump") else 0.0)-(1.0 if game.controls.held("sprint") else 0.0)
		var target_speed = (45.0 if gas>0.12 else 14.0) if airplane else (21.0 if gas>0.12 else 0.0)
		speed = move_toward(speed,target_speed,dt*(8.0 if airplane else 11.0))
		rotation.y += steer*dt*(0.70 if airplane else 1.25)
		var up_target = rise*(8.5 if airplane else 10.0)
		if airplane and rise==0.0: up_target = -0.35 if speed<26.0 else 0.8
		flight_lift = move_toward(flight_lift,up_target,dt*11.0)
		velocity = -global_basis.z*speed
		velocity.y = flight_lift
	else:
		speed = move_toward(speed,0.0,dt*6.0)
		velocity = -global_basis.z*speed
		velocity.y -= 14.0*dt
	if is_on_floor() and velocity.y<0: velocity.y = -0.15
	move_and_slide()
	if driver:
		visual.rotation.z = lerpf(visual.rotation.z,clampf(-game.controls.move.x*0.22,-0.22,0.22),minf(dt*3.0,1.0))
		visual.rotation.x = lerpf(visual.rotation.x,clampf(-flight_lift*0.025,-0.20,0.20),minf(dt*3.0,1.0))
	else:
		visual.rotation.x = lerpf(visual.rotation.x,0.0,minf(dt*3,1))
		visual.rotation.z = lerpf(visual.rotation.z,0.0,minf(dt*3,1))
	if rotor: rotor.rotate_y(dt*(18.0 if driver else 6.0))
	if absf(position.x)>710 or absf(position.z)>710:
		position.x = clampf(position.x,-702.0,702.0)
		position.z = clampf(position.z,-702.0,702.0)
	if position.y < CityWorld.elevation(position.x)-4.0:
		position.y = CityWorld.elevation(position.x)+2.0
		velocity = Vector3.ZERO
		speed = 0.0

func display_name() -> String:
	return "AVIÃO / GAIVOTA" if airplane else "HELICÓPTERO / ARARA"
