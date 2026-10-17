class_name HordeBonusDirector
extends RefCounted

var rng = RandomNumberGenerator.new()
var eligible_at = 0.0
var deadline = 0.0
var next_window = 0.0
var misses = 0
var last_opportunity = 0.0
var opportunities: Array[float] = []

func reset(seed_value: int) -> void:
	rng.seed = seed_value ^ 0x4B1D45
	misses = 0;last_opportunity = 0;opportunities.clear()
	reschedule(0, 305)

func reschedule(at: float, speed: float) -> void:
	var interval = HordeTuning.tunnel_interval(speed)
	eligible_at = at + interval * rng.randf_range(HordeTuning.BONUS_COOLDOWN.x, HordeTuning.BONUS_COOLDOWN.y)
	deadline = at + interval * rng.randf_range(HordeTuning.BONUS_DEADLINE.x, HordeTuning.BONUS_DEADLINE.y)
	next_window = eligible_at - maxf(800, speed * 2.5)
	misses = 0

func active(run) -> bool:
	if run.transform_left > 0 or run.perk_left > 0 or run.boost_left > 0: return true
	for entity in run.entities:
		if not entity.taken and entity.kind in ["crystal", "mask", "shield", "boost"]: return true
	return false

func safe(run, absolute: float) -> bool:
	var speed = maxf(305, run.cruise_speed)
	if not run.safe_world_position(absolute): return false
	if not run.terrain.safe_span(absolute - speed * 0.65, absolute + speed * 0.65, 80): return false
	var ground = run.terrain.floor_at(absolute)
	var lane = Rect2(absolute - speed * 0.50, ground - 145, speed, 145)
	for e in run.entities:
		if e.taken: continue
		var x = run.world_px + float(e.x)
		if e.kind in ["gap", "collapse"] and x < lane.end.x and x + float(e.width) > lane.position.x: return false
		var box = HordeCourse.hazard_rect(run, e)
		if absf(HordeCourse.travel_velocity(e)) > 0: box = box.merge(HordeCourse.hazard_rect(run, e, 5.0))
		if box.size != Vector2.ZERO and box.grow(60).intersects(lane): return false
	return true

func tick(run) -> void:
	var lead_world = run.world_px + HordeRun.ANCHOR
	if lead_world < next_window or active(run): return
	var speed = maxf(305, run.cruise_speed)
	next_window = lead_world + speed * HordeTuning.BONUS_WINDOW_SECONDS
	var desired = maxf(eligible_at, run.spawn_left() + 90)
	var forced = desired + speed * 3.0 >= deadline
	if not forced and rng.randf() >= minf(0.90, HordeTuning.BONUS_INITIAL_CHANCE + misses * HordeTuning.BONUS_CHANCE_STEP):
		misses += 1;return
	for step in range(16):
		var at = desired + step * 90.0
		if at > run.world_px + run.generation_horizon(): break
		if not safe(run, at): continue
		var choices = ["crystal", "boost"]
		if run.shields <= 0: choices.append("shield")
		if 2 in run.power_owned: choices.append("mask")
		var entity = run.add_entity(choices[rng.randi_range(0, choices.size() - 1)], at - run.world_px, run.terrain.floor_at(at) - 65)
		entity.bonus_world = at
		last_opportunity = at;opportunities.append(at)
		if opportunities.size() > 32: opportunities.pop_front()
		reschedule(at, speed)
		return
	misses += 1
	if forced: next_window = lead_world + speed * 0.5

func collected(run) -> void:
	reschedule(run.world_px + HordeRun.ANCHOR, maxf(305, run.cruise_speed))
