extends SceneTree

var failures: Array[String] = []
var metrics: Array[Dictionary] = []
var chunks = 0
var coin_count = 0
var platform_count = 0
var modes: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		if failures.size() < 15: push_error("BALANCE_V85: " + message)

func isolated(count: int, speed: float) -> HordeRun:
	var r = HordeRun.new();r.start({}, 82)
	r.entities.clear();r.tunnels.clear();r.next_segment = 99999;r.next_rush_world = 1e12
	r.world_px = maxf(0, (speed - 305) * 230);r.speed = speed;r.cruise_speed = speed;r.last_effective_speed = speed
	r.terrain.segments.assign([{"start": -1e12, "end": 1e12, "height": 0.0, "state": 0}])
	while r.members.size() < count: r.add_member(0, false)
	return r

func jump_measure(fps: int, count: int, speed: float, hold: float) -> Dictionary:
	var r = isolated(count, speed)
	var start = r.world_px
	r.jump();r.jump() # Two same-frame presses must not enqueue two launches.
	check(r.members[0].jump_queue.size() == 1, "duplicate touch jump")
	var time = 0.0;var peak = 0.0;var landed = false;var flight = 0.0;var distance = 0.0
	while time < 4.0:
		var dt = minf(1.0 / fps, hold - time) if time < hold - 0.000001 else 1.0 / fps
		r.advance(dt, time < hold - 0.000001);time += dt
		peak = maxf(peak, HordeRun.FLOOR - float(r.members[0].y))
		if not landed and time > 0.15 and r.members[0].vy == 0:
			landed = true;flight = time;distance = r.world_px - start
		if time > 2.6: break
	check(landed and r.active_count() == count, "jump/landing count " + str([fps, count, speed, hold]))
	for m in r.members: check(absf(m.y - HordeRun.FLOOR) < 0.01 and m.vy == 0 and m.air_jumps == 0, "follower landing")
	return {"fps": fps, "horde": count, "speed": speed, "hold": hold, "height": snappedf(peak, 0.01), "flight": snappedf(flight, 0.001), "distance": snappedf(distance, 0.01)}

func platform_check(fps: int, count: int, speed: float) -> void:
	var r = isolated(count, speed)
	var rise = r.world_px + HordeRun.ANCHOR + speed * 0.32
	var end = rise + maxf(1300, speed * 2.2)
	r.terrain.segments.assign([{"start": -1e12, "end": rise, "height": 0.0, "state": 0}, {"start": rise, "end": end, "height": 80.0, "state": 1}, {"start": end, "end": 1e12, "height": 0.0, "state": 2}])
	r.jump();var top: Dictionary = {};var time = 0.0
	while time < 7.5 and not r.dead:
		r.advance(1.0 / fps, time < 0.5);time += 1.0 / fps
		for m in r.members:
			if absf(m.y - (HordeRun.FLOOR - 80)) < 0.1 and m.vy == 0: top[m.id] = true
	check(r.active_count() == count and top.size() == count, "platform landing " + str([fps, count, speed, r.active_count(), top.size()]))
	for m in r.members: check(absf(m.y - HordeRun.FLOOR) < 0.1, "platform return " + str([fps, speed, m.y]))

func hazard_physics() -> void:
	for speed in [305.0, 500.0, 780.0]:
		for count in [1, 5, 20]:
			for kind in MonsterCatalog.VEHICLES:
				var r = isolated(count, speed)
				var geometry = HordeBalance.vehicle_geometry(MonsterCatalog.VEHICLES[kind], speed)
				var above: Array[float] = []
				for point in HordeBalance.jump_profile().samples:
					if -point.y >= float(geometry.height) + 8: above.append(point.x)
				var at = HordeRun.ANCHOR + speed * (above[0] + above[-1]) * 0.5
				var e = r.add_entity(kind, at)
				r.jump()
				for frame in range(160): r.advance(1.0 / 60, frame < 30)
				check(r.active_count() == count and r.losses == 0 and e.contacts.is_empty(), "actual vehicle jump " + str([kind, speed, count]))
			var gap_run = isolated(count, speed)
			gap_run.add_entity("gap", HordeRun.ANCHOR + speed * 0.15, HordeRun.FLOOR, 0, speed * 0.77)
			gap_run.jump()
			for frame in range(190): gap_run.advance(1.0 / 60, frame < 30)
			check(gap_run.active_count() == count and gap_run.losses == 0, "actual long gap " + str([speed, count]))
	# Newly spawned and moving objects must invalidate intersecting coins at once.
	var dynamic = isolated(1, 500)
	var coin = dynamic.add_entity("coin", 1000, HordeRun.FLOOR - 48)
	dynamic.add_entity("bomb", 1000)
	check(coin.taken, "new obstacle did not reserve coin space")
	var airborne = dynamic.add_entity("coin", 1450, HordeRun.FLOOR - 140)
	dynamic.add_entity("bullet", 1700, HordeRun.FLOOR - 140)
	check(airborne.taken, "moving projectile corridor did not reserve coins")

func speech_check() -> void:
	var r = isolated(1, 305)
	for i in range(27): r.add_entity("civilian", 750 + i * 350, HordeRun.FLOOR, i % 3)
	var phrases: Array[String] = []
	var last_text = ""
	for frame in range(2100):
		r.advance(1.0 / 60, false)
		var simultaneous = 0
		for e in r.entities:
			if not e.taken and e.state == "normal" and float(e.speech_left) > 0: simultaneous += 1
		check(simultaneous <= 1, "overlapping NPC comments")
		if r.speech_left > 2.48 and r.speech_text != last_text:
			check(r.speech_text not in phrases.slice(maxi(0, phrases.size() - 3)), "repeated recent NPC phrase")
			phrases.append(r.speech_text);last_text = r.speech_text
	check(phrases.size() >= 3, "NPC comments too rare")

func sweep() -> void:
	for seed_value in range(12):
		var r = HordeRun.new();r.start({}, 1801 + seed_value)
		r.entities.clear();r.tunnels.clear()
		var absolute = 2400.0
		var previous_world = 0.0
		var seen_end = 2600.0
		var last_height = 0.0
		for i in range(70):
			var speed = [305.0, 500.0, 780.0][seed_value % 3]
			r.world_px = maxf(0, absolute - HordeRun.ANCHOR - 1500)
			var moved = r.world_px - previous_world
			for e in r.entities: e.x -= moved
			previous_world = r.world_px
			for j in range(r.entities.size() - 1, -1, -1):
				if r.entities[j].x < -1800: r.entities.remove_at(j)
			r.speed = speed;r.cruise_speed = speed;r.entered_tunnels = int(i / 10)
			var next = HordeCourse.build(r, absolute, i)
			check(next > absolute + speed * 1.7, "reaction spacing")
			for segment in r.terrain.segments:
				if float(segment.end) <= seen_end: continue
				check(not (last_height > 0 and float(segment.height) > last_height), "second rise before descent")
				if float(segment.height) > last_height: platform_count += 1
				last_height = float(segment.height);seen_end = float(segment.end)
			for e in r.entities:
				if e.taken: continue
				if e.kind == "coin":
					check(HordeCourse.coin_clear(r, Vector2(r.world_px + e.x, e.y), false), "coin geometry " + str([seed_value, i, e.x, e.y]))
					coin_count += 1;modes[e.get("formation", -1)] = true
				elif MonsterCatalog.VEHICLES.has(e.kind):
					check(bool(e.get("path_checked", false)), "no full encounter trajectory")
					var sample = HordeBalance.jump_profile().samples
					var above: Array[float] = []
					for point in sample:
						if -point.y >= float(e.height) + 8: above.append(point.x)
					var at_speed = float(e.get("plan_speed", speed))
					check(above.size() > 1 and (above[-1] - above[0]) * at_speed * 0.96 >= float(e.width) + 38, "vehicle not jumpable")
			for group in r.coin_groups:
				for point in group.points:
					var best = INF
					for sample in group.witness: best = minf(best, point.distance_to(sample))
					check(best <= HordeBalance.COIN_PATH_RADIUS, "no collectable witness")
			absolute = next;chunks += 1
	check(coin_count > 300 and platform_count >= 40 and platform_count <= 180, "sweep coverage")

func run() -> void:
	for fps in [30, 60, 120]:
		for speed in [305.0, 500.0, 780.0]:
			for count in [1, 5, 20]:
				var short = jump_measure(fps, count, speed, 0.04)
				var long = jump_measure(fps, count, speed, 0.50)
				check(long.height > short.height * 1.6 and long.flight > short.flight * 1.3 and long.distance > short.distance * 1.3, "variable jump difference")
				metrics.append(short);metrics.append(long)
				platform_check(fps, count, speed)
	# A step cannot be walked onto; it must be jumped.
	var wall = isolated(1, 305)
	var edge = wall.world_px + HordeRun.ANCHOR + 70
	wall.terrain.segments.assign([{"start": -1e12, "end": edge, "height": 0.0, "state": 0}, {"start": edge, "end": 1e12, "height": 80.0, "state": 1}])
	for i in range(20): wall.advance(1.0 / 60, false)
	check(wall.members[0].y == HordeRun.FLOOR and wall.world_px + wall.members[0].x + 18 <= edge + 0.01, "step was climbed without jumping")
	wall.jump()
	for i in range(90): wall.advance(1.0 / 60, i < 30)
	check(wall.active_count() == 1 and wall.members[0].y == HordeRun.FLOOR - 80, "jump from wall blocked")
	speech_check()
	hazard_physics()
	sweep()
	var report = {"failures": failures, "chunks": chunks, "coin_checks": coin_count, "platforms": platform_count, "modes": modes.keys(), "jump_metrics": metrics}
	var path = OS.get_environment("HORDE_BALANCE_REPORT")
	if not path.is_empty(): FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("BALANCE_V85_RESULT: " + JSON.stringify({"failures": failures.size(), "chunks": chunks, "coin_checks": coin_count, "platforms": platform_count, "modes": modes.keys(), "sample": metrics.slice(0, 2)}))
	quit(0 if failures.is_empty() else 1)
