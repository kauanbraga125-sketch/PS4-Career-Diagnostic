class_name HordeActor
extends RefCounted


var art: HordeArt
var facing = 1.0
var basis_angle = 0.0
var zombie: HordeZombieSprite

func _init(source: HordeArt) -> void :
	art = source
	zombie = HordeZombieSprite.new()

static func stride_foot(phase: float) -> Vector2:
	var t = fposmod(phase, 1.0)
	if t < 0.58: return Vector2(25 - 50 * t / 0.58, -4)
	var u = (t - 0.58) / 0.42
	var tangent = -50 / 0.58 * 0.42
	var x = (2 * u * u * u - 3 * u * u + 1) * -25 + (u * u * u - 2 * u * u + u) * tangent + (-2 * u * u * u + 3 * u * u) * 25 + (u * u * u - u * u) * tangent
	return Vector2(x, -4 - 18 * pow(maxf(0, sin(u * PI)), 1.4))

static func knee(hip: Vector2, ankle: Vector2) -> Vector2:
	var delta = ankle - hip
	var distance = clampf(delta.length(), 0.1, 45.9)
	var direction = delta.normalized()
	var along = (24.0 * 24.0 - 22.0 * 22.0 + distance * distance) / (2.0 * distance)
	var bend = sqrt(maxf(0, 24.0 * 24.0 - along * along))
	return hip + direction * along + Vector2(direction.y, - direction.x) * bend

func part(canvas: Node2D, kind: int, index: int, position: Vector2, size: Vector2, angle: float, tint: Color, root: Vector2, scale: float, pivot: Vector2 = Vector2(0.5, 0.5)) -> void :
	canvas.draw_set_transform(root + Vector2(position.x * facing, position.y).rotated(basis_angle) * scale, angle * facing + basis_angle, Vector2(facing, 1) * scale)
	canvas.draw_texture_rect(art.rigs[kind][index], Rect2( - size * pivot, size), false, tint)

func bone(canvas: Node2D, kind: int, index: int, from: Vector2, to: Vector2, width: float, tint: Color, root: Vector2, scale: float) -> void :
	var delta = to - from
	part(canvas, kind, index, from, Vector2(width, delta.length() + 8), delta.angle() - PI * 0.5, tint, root, scale, Vector2(0.5, 0.12))

func leg(canvas: Node2D, kind: int, hip: Vector2, ankle: Vector2, tint: Color, root: Vector2, scale: float, angle: float = 0) -> void :
	var joint = knee(hip, ankle)
	bone(canvas, kind, 5, hip, joint, 12 if kind != 1 else 8, tint, root, scale)
	bone(canvas, kind, 6, joint, ankle, 10 if kind != 1 else 7, tint, root, scale)
	part(canvas, kind, 7, ankle + Vector2(5, 1), Vector2(20, 10), angle, tint, root, scale, Vector2(0.35, 0.6))

func arm(canvas: Node2D, kind: int, shoulder: Vector2, swing: float, tint: Color, root: Vector2, scale: float, weapon: bool = false, aim: bool = false) -> void :
	var elbow = shoulder + Vector2(0, 17).rotated(swing)
	var hand = elbow + Vector2(0, 16).rotated(swing - 1.3)
	if aim: elbow = shoulder + Vector2(16, -1);hand = shoulder + Vector2(30, 0)
	bone(canvas, kind, 2, shoulder, elbow, 11 if kind != 1 else 7, tint, root, scale)
	bone(canvas, kind, 3, elbow, hand, 10 if kind != 1 else 6, tint, root, scale)
	if weapon:
		if kind == 8:
			var sign_pos = hand + Vector2(5, -26)
			canvas.draw_set_transform(root + Vector2(sign_pos.x * facing, sign_pos.y).rotated(basis_angle) * scale, basis_angle + sin(root.x * 0.003) * 0.04, Vector2.ONE * scale)
			canvas.draw_texture_rect(art.rigs[kind][8], Rect2(Vector2(-18.5, -57.04), Vector2(37, 62)), false, tint)
		elif kind == 5: part(canvas, kind, 8, hand + Vector2(-2, -3), Vector2(44, 15), 0, tint, root, scale, Vector2(0.25, 0.5))
		else: part(canvas, kind, 8, hand + Vector2(4, -9), Vector2(11, 36), 0.55 + swing * 0.2, tint, root, scale, Vector2(0.5, 0.88))
	part(canvas, kind, 4, hand, Vector2(12, 13), swing - 0.7, tint, root, scale, Vector2(0.5, 0.2))

func paint(canvas: Node2D, kind: int, foot: Vector2, height: float, phase: float, state: String = "run", time: float = 0, landing: float = 0, tint: Color = Color.WHITE, reverse: bool = false, pose_mix: float = 1.0, show_prop: bool = true, air_age: float = -1, vertical_speed: float = 0) -> void :
	kind = clampi(kind, 0, art.rigs.size() - 1)
	if kind == 0:
		zombie.paint(canvas, foot, height, phase, state, time, landing, tint, reverse, air_age, vertical_speed)
		return
	facing = -1.0 if reverse else 1.0
	var scale = height / 112.0
	basis_angle = 0.0
	var run = state in ["run", "panic_run", "police_run", "capture"]
	var wave = sin(phase * TAU)
	var bob = absf(sin(phase * TAU)) * 4.2 if run else sin(time * 2.8) * 1.2
	var compression = sin(clampf(landing / 0.2, 0, 1) * PI) * 6
	var hip = Vector2(-2 + sin(phase * TAU) * 1.3 if run else -2, -37 + bob + compression)
	var near_foot = stride_foot(phase) if run else Vector2(13, -4)
	var far_foot = stride_foot(phase + 0.5) if run else Vector2(-12, -4)
	if state in ["rise", "fly"]:
		near_foot = stride_foot(phase).lerp(Vector2(19, -22), pose_mix);far_foot = stride_foot(phase + 0.5).lerp(Vector2(-24, -18), pose_mix)
		hip.y = -37
	elif state == "fall":
		near_foot = stride_foot(phase).lerp(Vector2(14, -8), pose_mix);far_foot = stride_foot(phase + 0.5).lerp(Vector2(-13, -5), pose_mix)
	var shade = tint * Color(0.7, 0.72, 0.82, 1)
	if kind == 1:
		part(canvas, kind, 8, hip + Vector2(-5, -27), Vector2(31, 34), - 0.55 + sin(time * 7) * 0.11, shade, foot, scale, Vector2(0.75, 0.1))
	elif kind == 3:
		var flap = sin(time * (48.0 if state == "capture" else 35.0))
		for wing in range(2):
			part(canvas, kind, 8, hip + Vector2(-7, -23), Vector2(25, 40 - absf(flap) * 14), - 0.95 - wing * 0.55 + flap * 0.3, tint * Color(1, 1, 1, 0.85), foot, scale, Vector2(0.5, 1))
	elif kind in [4, 6, 7]:
		part(canvas, kind, 8, hip + Vector2(-11, -25), Vector2(23, 28), - 0.2 + sin(time * 8) * 0.07, tint, foot, scale, Vector2(0.5, 0.1))
	var arm_swing = - 0.3 + wave * (0.95 if kind in [0, 1] else 0.72) if run else - 0.25 + sin(time * 3) * 0.14
	var capturing = state == "capture"
	var attack = sin(phase * PI) if capturing else 0.0
	if state in ["panic", "panic_run"]: arm_swing = -2.1 + sin(time * 13) * 0.42
	if capturing:
		hip.x += attack * (8 if kind == 0 else 4);hip.y -= attack * (10 if kind == 1 else 2)
		arm_swing = [-1.65, -2.55, -1.3, -1.9][clampi(kind, 0, 3)] + sin(time * 26) * 0.2
	if state == "push":
		arm_swing = -1.4;hip.x += 6 + sin(time * 8) * 1.4;hip.y += 2;near_foot = Vector2(18, -4);far_foot = Vector2(-19, -4)
	if state in ["rise", "fly"]: arm_swing = -1.35
	elif state == "fall": arm_swing = - 0.85
	arm(canvas, kind, hip + Vector2(-7, -24), - arm_swing - 0.3, shade, foot, scale, false, state == "push")
	leg(canvas, kind, hip + Vector2(-4, 0), far_foot, shade, foot, scale)
	leg(canvas, kind, hip + Vector2(3, 0), near_foot, tint, foot, scale, - 0.2 if state == "rise" else 0)
	var lean = 0.15 + wave * 0.025 if run else 0.02
	if capturing: lean = [0.52, - 0.16, 0.34, 0.28][clampi(kind, 0, 3)] * attack
	if state == "push": lean = 0.36
	if state == "rise": lean = 0.22
	part(canvas, kind, 1, hip + Vector2(3, -16), Vector2(29, 36), lean, tint, foot, scale)
	arm(canvas, kind, hip + Vector2(10, -24), arm_swing, tint, foot, scale, show_prop and kind in [2, 5, 8] and state != "panic", state in ["aim", "push"])
	part(canvas, kind, 0, hip + Vector2(9 + attack * 6, -27 - attack * (9 if kind == 1 else 0)), Vector2(52 * (1 + attack * 0.08), 50 * (1 + sin(time * 12) * 0.012)), lean * 0.3 + sin(time * 5) * 0.025, tint, foot, scale, Vector2(0.5, 0.94))
	canvas.draw_set_transform(Vector2.ZERO)
	facing = 1.0

func passenger(canvas: Node2D, kind: int, centre: Vector2, height: float, time: float, angle: float = 0) -> void :
	kind = clampi(kind, 0, art.rigs.size() - 1);facing = -1;basis_angle = angle
	var scale = height / 80
	var tint = Color(0.92, 0.95, 1, 1)
	var hip = Vector2(0, 16 + sin(time * 10) * 1.5)
	part(canvas, kind, 1, hip, Vector2(28, 28), sin(time * 8) * 0.04, tint, centre, scale)
	arm(canvas, kind, hip + Vector2(-8, -8), -2.4 + sin(time * 15) * 0.35, tint, centre, scale)
	arm(canvas, kind, hip + Vector2(9, -8), -2.0 + cos(time * 17) * 0.35, tint, centre, scale)
	part(canvas, kind, 0, hip + Vector2(3, -15), Vector2(44, 42), sin(time * 12) * 0.045, tint, centre, scale, Vector2(0.5, 1))
	canvas.draw_set_transform(Vector2.ZERO);facing = 1;basis_angle = 0
