class_name HordeBalance
extends RefCounted

# All distances are world pixels, times are seconds; negative y points upward.
const GRAVITY = 1500.0
const JUMP_IMPULSE = 580.0
const JUMP_UPGRADE = 24.0
const HOLD_GRAVITY = 850.0
const HOLD_FALL_GRAVITY = 850.0
const MAX_HOLD = 1.25
const RELEASE_GRAVITY = 3000.0
const RELEASE_BLEND = 0.10
const COIN_DIAMETER = 45.0 * 1.20
const COIN_SPACING = 76.0
const COIN_CLEARANCE = 42.0 # includes the five-pixel visual bob
const COIN_PATH_RADIUS = 45.0 # base pickup radius 46, minus bob and tolerance
const GROUP_SECONDS = Vector2(1.8, 3.5)
const PLATFORM_HEIGHT = 80.0
const VEHICLE_SCALE = 0.84
const STEP_REACTION = 0.85
const SPEECH_GAP = Vector2(2.5, 4.5)
const SPEECH_DURATION = 2.5
static var profile_cache: Dictionary = {}

static func launch(member: Dictionary, level: int = 0) -> void:
	member.vy = -JUMP_IMPULSE - level * JUMP_UPGRADE
	member.air_time = 0.0
	member.hold_open = true
	member.release_left = 0.0

static func integrate(member: Dictionary, dt: float, held: bool) -> void:
	if not held and bool(member.get("hold_open", false)):
		member.hold_open = false
		if float(member.vy) < 0: member.release_left = RELEASE_BLEND
	var remaining = dt
	while remaining > 0.000001:
		var step = minf(remaining, 1.0 / 120.0)
		var gravity = GRAVITY
		var sustaining = held and bool(member.get("hold_open", false)) and float(member.air_time) < MAX_HOLD - 0.000001
		if sustaining:
			gravity = HOLD_GRAVITY if float(member.vy) < 0 else HOLD_FALL_GRAVITY
			step = minf(step, MAX_HOLD - float(member.air_time))
		if float(member.vy) < 0:
			if not sustaining and float(member.get("release_left", 0)) > 0:
				gravity = RELEASE_GRAVITY
				step = minf(step, float(member.release_left))
			step = minf(step, -float(member.vy) / gravity)
		if step < 0.000001: step = minf(remaining, 0.000001)
		member.y += float(member.vy) * step + 0.5 * gravity * step * step
		member.vy += gravity * step
		member.air_time += step
		member.release_left = maxf(0, float(member.get("release_left", 0)) - step)
		remaining -= step

static func jump_profile(hold: float = MAX_HOLD, dt: float = 1.0 / 120, level: int = 0) -> Dictionary:
	var key = str(hold) + ":" + str(dt) + ":" + str(level)
	if profile_cache.has(key): return profile_cache[key]
	var m = {"y": 0.0, "vy": 0.0, "air_time": 0.0}
	launch(m, level)
	var samples: Array[Vector2] = [Vector2.ZERO]
	var height = 0.0
	while float(m.air_time) < 3:
		var before = Vector2(float(m.air_time), float(m.y))
		var step = minf(dt, hold - float(m.air_time)) if hold - float(m.air_time) > 0.000001 else dt
		integrate(m, step, float(m.air_time) < hold - 0.000001)
		height = maxf(height, -float(m.y))
		if m.y >= 0 and m.vy > 0:
			var fraction = -before.y / maxf(0.000001, float(m.y) - before.y)
			samples.append(Vector2(lerpf(before.x, float(m.air_time), fraction), 0))
			break
		samples.append(Vector2(float(m.air_time), float(m.y)))
	profile_cache[key] = {"height": height, "time": samples[-1].x, "samples": samples}
	return profile_cache[key]

static func vehicle_geometry(spec: Dictionary, _speed: float = 305.0) -> Dictionary:
	# A common art scale preserves the car/truck/airplane hierarchy at every speed.
	return {"width": float(spec.width) * VEHICLE_SCALE, "height": float(spec.height) * VEHICLE_SCALE,
		"collision": float(spec.collision) * VEHICLE_SCALE, "roof": float(spec.get("roof", spec.collision)) * VEHICLE_SCALE, "scale": VEHICLE_SCALE}

static func vehicle_jumpable(spec: Dictionary, speed: float, level: int = 0) -> bool:
	var geometry = vehicle_geometry(spec)
	# Landing on a roof is a valid way past wide vehicles.
	return float(jump_profile(MAX_HOLD, 1.0 / 120, level).height) > float(geometry.roof) + 12 and speed >= 280

static func passenger_rect(spec: Dictionary, index: int) -> Rect2:
	var size = Vector2(spec.width, spec.height) * VEHICLE_SCALE
	var centre = Vector2(spec.windows[index]) * size
	return Rect2(centre - Vector2(spec.window_size) * size * 0.5, Vector2(spec.window_size) * size)

static func surface(e: Dictionary, dx: float = 0.0) -> Rect2:
	if e.kind == "helicopter": return Rect2(float(e.x) + dx - 113, float(e.y) - 64, 227, 111)
	if not MonsterCatalog.VEHICLES.has(e.kind): return Rect2()
	var inset = 0.16 if e.kind == "plane" else (0.035 if e.kind == "bus" else 0.08)
	var height = float(e.get("roof", e.collision))
	return Rect2(float(e.x) + dx - float(e.width) * (0.5 - inset), float(e.y) - height, float(e.width) * (1.0 - 2.0 * inset), height)

static func resolve_ceiling(m: Dictionary, previous_y: float, surfaces: Array[Dictionary]) -> bool:
	if float(m.vy) >= 0: return false
	for e in surfaces:
		if e.kind != "helicopter" or e.get("taken", false): continue
		var body = surface(e)
		if float(m.x) + 16 < body.position.x or float(m.x) - 16 > body.end.x: continue
		if previous_y - 101 >= body.end.y - 2 and float(m.y) - 101 <= body.end.y:
			m.y = body.end.y + 101;m.vy = 0.0;m.hold_open = false;m.release_left = 0.0
			return true
	return false

static func hazard_hits(e: Dictionary, m: Dictionary, dx: float = 0.0, dy: float = 0.0) -> bool:
	var ex = float(e.x) + dx
	var ey = float(e.y) + dy
	# The planner and live collisions use the same body, including the helicopter's nose.
	if MonsterCatalog.VEHICLES.has(e.kind):
		if e.get("rushing", false):
			return m.y > ey - float(e.get("roof", e.collision)) + 3 and m.y <= ey + 4 and absf(m.x - (float(ex) - float(e.width) * 0.5)) <= 30
		return m.y > ey - float(e.get("roof", e.collision)) + 3 and m.y <= ey + 2 and m.x >= ex - float(e.width) * 0.5 - 16 and m.x <= ex + float(e.width) * 0.5 - 4
	if e.kind == "helicopter":
		var head = float(m.y) - 101
		return m.x + 18 > ex - 121 and m.x - 18 < ex - 61 and head < ey + 47 and m.y - 6 > ey - 64
	if e.kind in ["bullet", "air_bomb"]:
		var radius = Vector2(16, 5) if e.kind == "bullet" else Vector2(float(e.width) * 0.5, 26.4)
		return absf(m.x - ex) < radius.x + 18 and m.y - 101 < ey + radius.y and m.y - 6 > ey - radius.y
	if e.kind in ["crate", "spikes", "hump", "bomb"]:
		var height = 40.0 if e.kind == "spikes" else (64.0 if e.kind == "hump" else (HordeTuning.BOMB_HEIGHT if e.kind == "bomb" else 70.0))
		return absf(m.x - ex) < e.width * 0.5 + 14 and m.y > ey - height + 10 and m.y < ey + 4
	return false

static func projectile_swept_hit(e: Dictionary, m: Dictionary) -> bool:
	var start = Vector2(e.get("previous_x", e.x), e.get("previous_y", e.y))
	var finish = Vector2(e.x, e.y)
	var box = Rect2(float(m.x) - 34, float(m.y) - 106, 68, 105)
	var direction = finish - start
	var enter = 0.0;var leave = 1.0
	for axis in range(2):
		if absf(direction[axis]) < 0.000001:
			if start[axis] < box.position[axis] or start[axis] > box.end[axis]: return false
			continue
		var a = (box.position[axis] - start[axis]) / direction[axis]
		var b = (box.end[axis] - start[axis]) / direction[axis]
		enter = maxf(enter, minf(a, b));leave = minf(leave, maxf(a, b))
		if enter > leave: return false
	return true
