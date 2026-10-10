class_name StreetVehicle
extends CharacterBody3D

var game
var motorcycle = false
var driver = false
var traffic = false
var police = false
var health = 100.0
var speed = 0.0
var steering = 0.0
var throttle = 0.0
var turn = 0.0
var brake = false
var visual: Node3D
var ai_turn = 0.0
var engine_pitch = 0.0
var wheels: Array[Node3D] = []
var wheel_angle = 0.0

func setup(owner_game,bike: bool,style: int,auto_drive: bool = false) -> void:
	game = owner_game
	motorcycle = bike
	traffic = auto_drive
	collision_layer = 4
	collision_mask = 1|2|4
	floor_snap_length = 0.7
	floor_max_angle = deg_to_rad(46)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(0.70,1.05,1.9) if bike else Vector3(2.16,1.10,4.16)
	shape.shape = box
	# Imported models have their tires at local Y=0; the collider must too.
	shape.position.y = box.size.y*0.5
	add_child(shape)
	visual = StreetModels.bike(style) if bike else StreetModels.car(style)
	add_child(visual)
	for child in visual.find_children("W*","MeshInstance3D",true,false): wheels.append(child)
	if bike:
		var rider = StreetModels.person(0)
		rider.name = "Rider"
		rider.position = Vector3(0,-0.30,0.20)
		rider.scale = Vector3.ONE*0.94
		rider.mount_pose()
		visual.add_child(rider)
		rider.visible = traffic

func _physics_process(dt: float) -> void:
	if not game or not game.running: return
	# Suspend gravity until the streamed terrain has collision underneath us.
	if not game.world.is_loaded(global_position):
		velocity = Vector3.ZERO
		return
	if global_position.distance_squared_to(game.focus_position())>pow(340,2) and not driver:
		return
	if driver:
		throttle = -game.controls.move.y
		turn = game.controls.move.x
		brake = game.controls.held("brake")
	elif traffic:
		throttle = 0.30 if absf(speed)<11 else 0.0
		turn = 0.0
		brake = false
		# Traffic follows the road grid and turns at the city boundary.
		if absf(position.x)>670 or absf(position.z)>670:
			rotation.y += PI
			position = CityWorld.ground(position-basis.z*3,0.15)
	else:
		throttle = 0.0
		turn = 0.0
		brake = true
	if health<=0:
		throttle = 0
		brake = true
	var old_speed = speed
	var acceleration = 7.4 if motorcycle else 5.2
	var max_speed = 31.0 if motorcycle else 35.0
	var resistance = (0.20+0.005*speed*speed)*signf(speed)
	if absf(throttle)>0.08:
		if signf(throttle)!=signf(speed) and absf(speed)>1:
			speed = move_toward(speed,0,12*dt)
		else:
			speed += throttle*acceleration*maxf(0.15,1.0-absf(speed)/max_speed)*dt
	else:
		speed = move_toward(speed,0,0.65*dt)
	speed -= resistance*dt
	if brake: speed = move_toward(speed,0,15*dt)
	speed = clampf(speed,-7,max_speed)
	var steering_limit = lerpf(0.55,0.16,clampf(absf(speed)/35,0,1))
	steering = move_toward(steering,-turn*steering_limit,2.0*dt)
	var wheelbase = 1.6 if motorcycle else 2.7
	rotation.y += speed/wheelbase*tan(steering)*dt
	var forward = -global_basis.z
	var vertical = velocity.y
	var lateral = velocity-global_basis.z*velocity.dot(global_basis.z)
	lateral.y = 0
	velocity = forward*speed+lateral*exp(-dt*(3.0 if brake and absf(speed)>12 else 11.0))
	velocity.y = vertical-24*dt
	if is_on_floor() and velocity.y<0: velocity.y = -0.6
	var before = velocity
	move_and_slide()
	if get_slide_collision_count()>0:
		for i in get_slide_collision_count():
			var hit = get_slide_collision(i)
			if absf(hit.get_normal().y)<0.65 and absf(speed)>2:
				var loss = absf(before.dot(hit.get_normal()))
				if loss>4 and driver: game.sound.play("impact")
				health = maxf(0,health-maxf(0,loss-4)*0.75)
				speed *= clampf(1.0-loss/(absf(speed)+0.1),0.05,0.90)
				if traffic: rotation.y += PI/2
				break
	wheel_angle = fmod(wheel_angle-speed*dt/(0.31 if motorcycle else 0.40),TAU)
	for wheel in wheels:
		wheel.rotation = Vector3(wheel_angle,steering if String(wheel.name).begins_with("WFront") else 0.0,0)
	var acceleration_now = (speed-old_speed)/maxf(dt,0.001)
	var roll = steering*speed*0.035 if not motorcycle else steering*speed*0.13
	visual.rotation.z = lerpf(visual.rotation.z,clampf(roll,-0.45,0.45),minf(dt*7,1))
	visual.rotation.x = lerpf(visual.rotation.x,clampf(-acceleration_now*0.004,-0.07,0.07),minf(dt*6,1))
	if is_on_floor():
		var normal = get_floor_normal()
		visual.rotation.x += normal.dot(forward)*dt*3
	if position.y < -10 or absf(position.x)>740 or absf(position.z)>740:
		position = CityWorld.ground(Vector3(clampf(position.x,-690,690),0,clampf(position.z,-690,690)),1)
		speed = 0
		velocity = Vector3.ZERO

func set_driver(value: bool) -> void:
	driver = value
	traffic = false
	if visual.has_node("Rider"): visual.get_node("Rider").visible = value

func take_hit(amount: float) -> void:
	health = maxf(health-amount*0.30,0)
	if not driver: game.add_heat(8)

func display_name() -> String:
	return "MOTO / VENTO 250" if motorcycle else "CARRO / COSTA GT"
