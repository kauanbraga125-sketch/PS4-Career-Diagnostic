extends SceneTree

# A simple touch bot exercises the real simulation: no immunity, teleports or injected recruits.
# Its horde totals describe this input policy, not a promised outcome for a human player.
var reports: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")

func should_jump(r: HordeRun) -> bool:
	var leader = r.leader_index()
	if leader < 0 or r.perk_kind == 3 or r.transform_left > 0: return false
	var m = r.members[leader]
	if m.y < r.ground_y(m.x) - 1 or m.vy < 0 or not m.jump_queue.is_empty(): return false
	for segment in r.terrain.segments:
		var distance = float(segment.start) - r.world_px - float(m.x) - 18
		if float(segment.height) > HordeRun.FLOOR - r.ground_y(m.x) and distance >= -2 and distance / r.speed < 0.38: return true
	for e in r.entities:
		if e.taken: continue
		var dx = float(e.x) - float(m.x)
		if dx < -100 or dx > 1300: continue
		var closing = r.speed - float(e.vx)
		if e.get("rushing", false):
			if not e.get("rush_waiting", false) and (dx - float(e.width) * 0.5 - 18) / closing < 0.40: return true
		elif MonsterCatalog.VEHICLES.has(e.kind):
			if r.active_count() * r.member_force() < int(MonsterCatalog.VEHICLES[e.kind].need) and dx / closing < 0.62: return true
		elif e.kind == "gap":
			if dx >= -4 and dx / r.speed < 0.20: return true
		elif e.kind in ["bomb", "crate", "spikes", "hump"]:
			if dx >= -40 and dx / closing < 0.60: return true
		elif e.kind == "helicopter" and e.y > HordeRun.FLOOR - 180:
			if dx > 60 and (dx - 121 - 18) / closing < 0.40: return true
		elif e.kind == "air_bomb" and e.y > HordeRun.FLOOR - 180:
			if dx >= -40 and dx / closing < 0.65: return true
		elif e.kind == "bullet":
			if dx > 0 and dx / closing < 0.40: return true
	return false

func observe(seed_value: int) -> Dictionary:
	var r = HordeRun.new();r.start({}, seed_value)
	var held = 0.0
	var milestones: Dictionary = {}
	var previous_tunnel = 0
	var seconds_elevated = 0.0
	var max_speed_first_six = 0.0
	var started = Time.get_ticks_msec()
	for frame in range(450 * 30):
		if r.dead or r.entered_tunnels >= 6: break
		if held <= 0 and should_jump(r): r.jump();held = HordeBalance.MAX_HOLD
		r.advance(1.0 / 30, held > 0);held = maxf(0, held - 1.0 / 30)
		max_speed_first_six = maxf(max_speed_first_six, r.cruise_speed / (1.18 if r.boost_left > 0 else 1.0))
		if r.ground_y(HordeRun.ANCHOR) < HordeRun.FLOOR: seconds_elevated += 1.0 / 30
		if r.entered_tunnels != previous_tunnel:
			previous_tunnel = r.entered_tunnels
			milestones[str(previous_tunnel)] = {"seconds": snappedf(r.elapsed, 0.1), "horde": r.active_count(), "souls": r.souls, "losses": r.losses, "speed": snappedf(r.cruise_speed, 0.1)}
		r.events.clear()
	return {"seed": seed_value, "dead": r.dead, "seconds": snappedf(r.elapsed, 0.1), "milestones": milestones, "horde": r.active_count(), "souls": r.souls, "losses": r.losses, "vehicles_flipped": r.cars, "raised_fraction": seconds_elevated / maxf(1, r.elapsed), "max_unboosted_speed_first_six": max_speed_first_six, "test_seconds": (Time.get_ticks_msec() - started) / 1000.0}

func run() -> void:
	for seed_value in [8611, 8612, 8613, 8614, 8615, 8616]:
		var report = observe(seed_value);reports.append(report);print("PROGRESSION_V86_RUN: " + JSON.stringify(report))
	var result = {"policy": "real simulation with touch-only bot; no invincibility or injected population", "reports": reports}
	var path = OS.get_environment("HORDE_PROGRESSION_REPORT")
	if not path.is_empty(): FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(result, "  "))
	print("PROGRESSION_V86_DONE")
	quit()
