class_name StreetPlayer
extends CharacterBody3D

const WEAPONS = ["PISTOLA","SMG","ESCOPETA","CARABINA"]
const CAPACITY = [12,24,6,20]
const DAMAGE = [28,17,15,42]
const FIRE_DELAY = [0.30,0.10,0.80,0.22]
var game
var visual: StreetActor
var health = 100.0
var stamina = 100.0
var owned: Array = [false,false,false,false]
var magazines: Array = [0,0,0,0]
var reserve: Array = [0,0,0,0]
var weapon = -1
var vehicle: StreetVehicle
var phase = 0.0
var cooldown = 0.0
var reload_left = 0.0
var gun_visual: Node3D

func setup(owner_game) -> void:
	game = owner_game
	collision_layer = 2
	collision_mask = 1|4
	floor_snap_length = 0.35
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	visual = StreetModels.person(0)
	visual.rotation.y = -PI/2
	add_child(visual)

func _physics_process(dt: float) -> void:
	if not game or not game.running: return
	cooldown = maxf(cooldown-dt,0)
	if reload_left>0:
		reload_left = maxf(0,reload_left-dt)
		if reload_left==0 and weapon>=0:
			var count = mini(CAPACITY[weapon]-magazines[weapon],reserve[weapon])
			magazines[weapon] += count
			reserve[weapon] -= count
			game.sound.play("reload")
	if vehicle:
		global_position = vehicle.global_position
		return
	var move = game.controls.move
	var direction = Basis(Vector3.UP,game.camera_yaw)*Vector3(move.x,0,move.y)
	var sprinting = game.controls.held("sprint") and stamina>2 and direction.length()>0.1
	var target = direction.limit_length()* (7.3 if sprinting else 4.1)
	velocity.x = move_toward(velocity.x,target.x,22*dt)
	velocity.z = move_toward(velocity.z,target.z,22*dt)
	velocity.y -= 23*dt
	if is_on_floor():
		velocity.y = -0.4
		if game.controls.consume("jump"): velocity.y = 7.4
	stamina = clampf(stamina+(-21 if sprinting else 15)*dt,0,100)
	var was_grounded = is_on_floor()
	var impact_speed = -velocity.y
	move_and_slide()
	var landed = not was_grounded and is_on_floor() and impact_speed>3
	if landed:
		game.sound.play("land")
		if impact_speed>12: take_hit((impact_speed-12)*4)
	phase += Vector2(velocity.x,velocity.z).length()*dt*2.0
	var moving = Vector2(velocity.x,velocity.z).length()/7.3
	var aiming = game.controls.held("fire") and weapon>=0
	if aiming:
		visual.rotation.y = lerp_angle(visual.rotation.y,game.camera_yaw,minf(dt*14,1))
	elif moving>0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y,atan2(-velocity.x,-velocity.z),minf(dt*12,1))
	visual.move_pose(Vector2(velocity.x,velocity.z).length(),is_on_floor(),velocity.y,aiming,dt,landed)
	if aiming: fire()
	if position.y < -8: take_hit(200)

func equip(index: int) -> void:
	if index<0 or index>3 or not owned[index]: return
	weapon = index
	reload_left = 0
	if gun_visual: gun_visual.queue_free()
	gun_visual = StreetModels.gun(index)
	visual.attach_weapon(gun_visual)

func cycle_weapon() -> void:
	for offset in range(1,5):
		var next = (weapon+offset)%4
		if owned[next]: equip(next); return
	game.notify("Explore: as armas aparecem como marcadores dourados.")

func pickup(index: int,ammo: int = 24) -> void:
	if not owned[index]:
		owned[index] = true
		magazines[index] = CAPACITY[index]
	reserve[index] += ammo
	equip(index)
	game.notify("Encontrou " + WEAPONS[index] + "  +" + str(ammo) + " munições")
	game.sound.play("pickup")

func reload_weapon() -> void:
	if weapon>=0 and reload_left==0 and magazines[weapon]<CAPACITY[weapon] and reserve[weapon]>0:
		reload_left = 1.8 if weapon==2 else 1.25

func fire() -> void:
	if weapon<0 or cooldown>0 or reload_left>0: return
	if magazines[weapon]<=0: reload_weapon(); return
	magazines[weapon] -= 1
	cooldown = FIRE_DELAY[weapon]
	game.fire_weapon(weapon,DAMAGE[weapon])
	game.sound.play("shot",0.80 if weapon==2 else 1.1)

func take_hit(amount: float) -> void:
	health = maxf(0,health-amount)
	game.damage_flash = 0.35
	if health<=0: game.respawn()
