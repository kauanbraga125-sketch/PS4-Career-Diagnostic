extends SceneTree

var failures: Array[String] = []
var jump_cases = 0
var flip_cases = 0
var course_counts: Dictionary = {}
var reports: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		if failures.size() < 20: push_error("BALANCE_V86: " + message)

func isolated(count: int, stage: int = 0) -> HordeRun:
	var r = HordeRun.new();r.start({}, 8601)
	r.entities.clear();r.tunnels.clear();r.next_segment = 99999;r.entered_tunnels = stage
	r.speed = HordeDirector.stage_speed(stage);r.cruise_speed = r.speed;r.last_effective_speed = r.speed
	r.terrain.segments.assign([{"start": -1e12, "end": 1e12, "height": 0.0, "state": 0}])
	while r.members.size() < count: r.add_member(0, false)
	for i in range(r.members.size()): r.members[i].x = r.slot_x(i)
	return r

func physics() -> void:
	var short = HordeBalance.jump_profile(0.04)
	var long = HordeBalance.jump_profile()
	check(short.height > 79 and short.height < 85 and short.time < 0.66, "tap changed unexpectedly")
	check(long.time > 1.20 and long.time < 1.36 and long.height > 190 and long.height < 210, "held jump outside modest extension")
	for fps in [30, 60, 120]:
		for stage in [0, 5, 13, 25]:
			for count in [1, 20, 60]:
				var r = isolated(count, stage)
				r.add_entity("gap", HordeRun.ANCHOR + r.speed * 0.20, HordeRun.FLOOR, 0, r.speed * 0.73)
				r.jump();r.jump()
				check(r.members[0].jump_queue.size() == 1, "duplicate launch")
				for frame in range(fps * 3): r.advance(1.0 / fps, frame < fps * HordeBalance.MAX_HOLD)
				check(r.active_count() == count and r.losses == 0, "largest gap / followers " + str([fps, stage, count, r.losses]))
				for m in r.members: check(m.y == HordeRun.FLOOR and m.vy == 0, "did not land")
				jump_cases += 1
				var incoming = isolated(count, stage)
				var car = incoming.spawn_rushing_car(1300, 0)
				car.x = HordeRun.ANCHOR + (incoming.speed - car.vx) * 0.40 + float(car.width) * 0.5 + 18
				incoming.jump()
				for frame in range(fps * 3): incoming.advance(1.0 / fps, frame < fps * HordeBalance.MAX_HOLD)
				check(incoming.active_count() == count and incoming.losses == 0, "incoming car / followers " + str([fps, stage, count, incoming.losses]))
				jump_cases += 1
	for kind in MonsterCatalog.VEHICLES:
		var spec = MonsterCatalog.VEHICLES[kind]
		var r = isolated(int(spec.need) + 2)
		var e = r.add_entity(kind, HordeRun.ANCHOR + float(HordeBalance.vehicle_geometry(spec).width) * 0.5 + 70)
		e.passengers.assign([0] if int(spec.rescues) == 1 else [0, 1, 2, 0])
		for frame in range(240): r.advance(1.0 / 60, false)
		check(e.taken and r.cars == 1 and r.losses == 0, "full-size vehicle cannot be flipped " + kind)
		check(r.rescues == e.passengers.size(), "passenger rescue count " + kind)
		flip_cases += 1
	for kind in ["moto", "car"]:
		var r = isolated(1)
		var e = r.add_entity(kind, HordeRun.ANCHOR + r.speed * 0.62)
		r.jump()
		for frame in range(180): r.advance(1.0 / 60, frame < 63)
		check(r.losses == 0 and e.contacts.is_empty(), "small horde cannot jump " + kind)
	var large = isolated(60)
	check(large.active_count() == 60 and large.slot_x(59) > 100 and large.member_depth(59) <= 16, "large horde framing")
	large.souls = 100;large.spawn_civilians(1200, 3, 100)
	check(large.entities.size() == 3, "old soul quota still suppresses recruits")

func proportions() -> void:
	for kind in MonsterCatalog.VEHICLES:
		var spec = MonsterCatalog.VEHICLES[kind]
		var slow = HordeBalance.vehicle_geometry(spec, 305)
		var fast = HordeBalance.vehicle_geometry(spec, 680)
		check(slow == fast and slow.scale == 0.84, "speed-dependent vehicle size " + kind)
		for i in range(spec.windows.size()):
			var window = HordeBalance.passenger_rect(spec, i)
			check(Rect2(-slow.width / 2, -slow.height / 2, slow.width, slow.height).encloses(window), "passenger outside vehicle " + kind)
	var car = HordeBalance.vehicle_geometry(MonsterCatalog.VEHICLES.car)
	var plane = HordeBalance.vehicle_geometry(MonsterCatalog.VEHICLES.plane)
	check(plane.width > car.width * 2.7 and plane.height > car.height * 2.5, "airplane hierarchy")
	check(HordeBalance.vehicle_geometry(MonsterCatalog.VEHICLES.truck).width > car.width * 1.8, "truck hierarchy")
	var previous = 0.0
	for stage in range(30):
		var speed = HordeDirector.stage_speed(stage)
		check(speed >= previous and speed <= 680, "speed progression/cap")
		if stage <= 6: check(speed < 385, "early tunnels too fast")
		previous = speed
	check(HordeDirector.profile(10000, 60, 1, 0, 0).speed < 310, "large early horde causes a speed spike")

func chances() -> void:
	var frequencies: Array[Dictionary] = []
	var signatures: Dictionary = {}
	for stage in [0, 14]:
		var total: Dictionary = {}
		for seed_value in range(16):
			var r = isolated(40, stage);r.rng.seed = seed_value + 8600
			var signature = ""
			for i in range(500):
				var kind = HordeCourse.draw_pattern(r, i, true)
				total[kind] = int(total.get(kind, 0)) + 1
				r.course_category_streak = r.course_category_streak + 1 if HordeCourse.category(kind) == HordeCourse.category(r.last_course_pattern) else 1
				r.last_course_pattern = kind
				if i < 16: signature += kind + ","
			signatures[signature] = true
		frequencies.append(total)
	var early_good = 0;var late_good = 0
	for kind in ["civilian", "rest", "moto", "car", "bus", "truck", "tank", "plane"]:
		early_good += int(frequencies[0].get(kind, 0));late_good += int(frequencies[1].get(kind, 0))
	check(float(early_good) / 8000 > 0.64 and early_good > late_good + 1200, "reward chances do not decrease gradually")
	check(signatures.size() == 32, "runs share a fixed opening sequence")
	for kind in ["rush", "helicopter", "air_bomb", "tank", "plane"]:
		check(int(frequencies[0].get(kind, 0)) > 10 and int(frequencies[1].get(kind, 0)) > int(frequencies[0].get(kind, 0)), "late variety " + kind)
	reports.append({"draws_per_stage": 8000, "early": frequencies[0], "late": frequencies[1], "early_good_fraction": early_good / 8000.0, "late_good_fraction": late_good / 8000.0})

func course_sweep() -> void:
	var low = 0;var high = 0;var gaps: Dictionary = {};var coins = 0
	var raised = 0.0;var total_length = 0.0;var previous_counts: Dictionary = {}
	for seed_value in range(8):
		var r = isolated(40);r.rng.seed = 8660 + seed_value;r.terrain.reset()
		var absolute = 2600.0
		var counts: Dictionary = {}
		for i in range(100):
			var old_world = r.world_px;r.world_px = absolute - HordeRun.ANCHOR - 1500
			for e in r.entities: e.x -= r.world_px - old_world
			for j in range(r.entities.size() - 1, -1, -1):
				if r.entities[j].x < -1800: r.entities.remove_at(j)
			r.entered_tunnels = int(i / 7);r.speed = HordeDirector.stage_speed(r.entered_tunnels);r.cruise_speed = r.speed
			var first_id = r.next_entity_id
			var next = HordeCourse.build(r, absolute, i)
			check(next > absolute + r.speed * 1.7, "reaction/recovery spacing")
			for e in r.entities:
				if e.taken: continue
				if e.kind == "coin":
					check(HordeCourse.coin_clear(r, Vector2(r.world_px + e.x, e.y), false), "coin in obstacle/ground")
					coins += 1;continue
				if e.id < first_id: continue
				var kind = "rush" if e.get("rushing", false) else str(e.kind)
				counts[kind] = int(counts.get(kind, 0)) + 1
				course_counts[kind] = int(course_counts.get(kind, 0)) + 1
				if kind == "helicopter":
					if e.y > HordeRun.FLOOR - 180: low += 1
					else: high += 1
				if kind == "gap":
					var ratio = float(e.width) / float(e.plan_speed)
					check(ratio >= 0.25 and ratio <= 0.731, "gap exceeds requested shortening")
					gaps["small" if ratio < 0.4 else ("medium" if ratio < 0.6 else "large")] = true
				elif MonsterCatalog.VEHICLES.has(kind): check(e.get("path_checked", false), "vehicle with no viable route " + kind)
			for segment in r.terrain.segments:
				if float(segment.get("counted_to", segment.start)) >= minf(float(segment.end), next): continue
				var length = minf(float(segment.end), next) - maxf(0, float(segment.get("counted_to", segment.start)))
				if length > 0:
					total_length += length
					if float(segment.height) > 0: raised += length
				segment.counted_to = minf(float(segment.end), next)
			absolute = next
		previous_counts[JSON.stringify(counts)] = true
	check(low >= 8 and high >= 8, "low/flying helicopter variants disappeared")
	check(gaps.size() == 3, "gap sizes missing")
	check(raised / total_length < 0.09, "elevated terrain still too common")
	check(previous_counts.size() == 8, "fixed encounter quotas remain")
	for kind in ["moto", "car", "bus", "truck", "tank", "plane", "bomb", "air_bomb", "helicopter", "gap", "rush", "soldier"]: check(int(course_counts.get(kind, 0)) > 2, "course kind missing " + kind)
	reports.append({"course_events": 800, "counts": course_counts, "low_helicopters": low, "high_helicopters": high, "raised_fraction": raised / total_length, "coin_checks": coins, "gap_sizes": gaps.keys()})

func run() -> void:
	proportions();physics();chances();course_sweep()
	var result = {"failures": failures, "jump_and_rush_cases": jump_cases, "flip_cases": flip_cases, "tap": {"height": HordeBalance.jump_profile(0.04).height, "time": HordeBalance.jump_profile(0.04).time}, "held": {"height": HordeBalance.jump_profile().height, "time": HordeBalance.jump_profile().time}, "reports": reports}
	var path = OS.get_environment("HORDE_BALANCE_REPORT")
	if not path.is_empty(): FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(result, "  "))
	print("BALANCE_V86_RESULT: " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
