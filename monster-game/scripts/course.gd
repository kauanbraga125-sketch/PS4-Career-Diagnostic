class_name HordeCourse
extends RefCounted

static func category(kind: String) -> String:
	if MonsterCatalog.VEHICLES.has(kind): return "vehicle"
	if kind in ["bomb", "air_bomb", "bomb_pair", "bomb_sequence", "air_sequence", "mixed"]: return "explosive"
	if kind in ["gap", "gap_chain", "collapse", "collapse_chain"]: return "gap"
	return kind

static func damp_history(run, weights: Dictionary) -> Dictionary:
	for kind in weights:
		for i in range(run.course_history.size()):
			if run.course_history[i] == kind: weights[kind] *= 0.36 if i == run.course_history.size() - 1 else 0.78
	return weights

static func pattern_weights(run, p: Dictionary) -> Dictionary:
	var t = float(p.progress)
	var weights = {"civilian": lerpf(22, 13, t), "rest": 6.0, "moto": lerpf(17, 7, t), "car": 17.0, "bus": 9.0, "truck": 9.0, "tank": 10.0, "plane": 8.0}
	for kind in MonsterCatalog.VEHICLES:
		var spec = MonsterCatalog.VEHICLES[kind]
		if run.remaining_soul_slots() < int(spec.rescues): weights[kind] = 0.0
		if run.active_count() < int(spec.need) + 2 and not HordeBalance.vehicle_jumpable(spec, maxf(305, run.speed), int(run.levels.get("jump", 0))): weights[kind] = 0.0
		if run.active_count() < int(spec.need) and kind in ["tank", "plane", "truck", "bus"]: weights[kind] *= 0.90
	return damp_history(run, weights)

static func weighted(run, weights: Dictionary) -> String:
	var total = 0.0
	for value in weights.values(): total += maxf(0, float(value))
	var roll = run.course_rng.randf() * total
	for kind in weights:
		roll -= maxf(0, float(weights[kind]))
		if roll <= 0 and float(weights[kind]) > 0: return kind
	return "civilian"

static func developer_pattern(run) -> String:
	var variation = run.developer_iteration
	run.developer_iteration += 1
	match run.developer_kind:
		"bomb": return "bomb_sequence"
		"air_bomb": return "air_sequence"
		"mixed": return "mixed"
		"gap": return "gap_chain"
		"collapse": return "collapse_chain"
		"car": return "traffic_sequence"
		"helicopter": return "helicopter"
		"tank": return "tank"
		"convoy": return "convoy"
		"combined": return "combined"
		"collision": return ["traffic_sequence", "helicopter", "bus", "plane"][variation % 4]
		"powers": return "gap_chain"
		"vehicles": return MonsterCatalog.VEHICLES.keys()[variation % MonsterCatalog.VEHICLES.size()]
	return "rest"

static func draw_pattern(run, _index: int, _advanced: bool) -> String:
	if not run.developer_kind.is_empty(): return developer_pattern(run)
	var p = HordeDirector.profile(run.world_px, run.active_count(), run.pressure, run.recovery_left, run.tunnel_number())
	var planned = maxf(run.world_px + HordeRun.ANCHOR, run.next_pattern_world + HordeRun.ANCHOR)
	# Prevent long droughts of the two large encounters once the horde can flip them.
	for kind in ["tank", "plane"]:
		var wait = (22.0 if kind == "tank" else 30.0) if run.active_count() >= 36 else (26.0 if kind == "tank" else 36.0)
		if run.remaining_soul_slots() >= int(MonsterCatalog.VEHICLES[kind].rescues) and run.active_count() >= int(MonsterCatalog.VEHICLES[kind].need) + 2 and planned - float(run.vehicle_drought.get(kind, 0)) >= maxf(305, run.cruise_speed) * wait:
			run.next_challenge_level = -1;return kind
	if run.active_count() >= 16 and run.remaining_soul_slots() > 0 and planned - run.last_soldier_world >= maxf(305, run.cruise_speed) * 28:
		run.next_challenge_level = 1;return "soldier"
	if run.remaining_soul_slots() > 0 and run.course_rng.randf() < float(p.growth):
		run.next_challenge_level = -1
		return weighted(run, pattern_weights(run, p))
	var weights: Vector3 = p.challenge_weights
	var draw = run.course_rng.randf() * (weights.x + weights.y + weights.z)
	run.next_challenge_level = 0 if draw < weights.x else (1 if draw < weights.x + weights.y else 2)
	var choices = {"bomb": 5.0, "gap": 4.0, "collapse": 1.0, "mobile": 3.0}
	if run.next_challenge_level == 1: choices = {"bomb_sequence": 6.0, "air_sequence": 3.0, "mixed": 3.0, "gap_chain": 3.0, "collapse": 2.0, "mobile": 3.0, "traffic_sequence": 3.0, "combined": 2.0, "collapse_chain": 2.0}
	if run.next_challenge_level == 2: choices = {"bomb_sequence": 5.0, "mixed": 7.0, "air_sequence": 3.0, "gap_chain": 6.0, "collapse": 3.0, "convoy": 3.0, "mobile": 3.0, "traffic_sequence": 4.0, "combined": 6.0, "collapse_chain": 4.0}
	if int(p.phase) == 0:
		choices.erase("mixed");choices.erase("gap_chain");choices.erase("convoy")
	if run.active_count() < 8: choices.erase("convoy")
	if planned < run.next_helicopter_world: choices.erase("convoy")
	# A horde of 36 must actually meet a combined challenge soon, not merely
	# have a tiny chance to roll one among many growth encounters.
	if run.active_count() >= 36 and run.recovery_left <= 0 and planned - run.last_heavy_challenge > maxf(305, run.cruise_speed) * 16:
		return weighted(run, damp_history(run, {"mixed": 4.0, "combined": 5.0, "collapse_chain": 3.0, "traffic_sequence": 3.0, "gap_chain": 4.0, "convoy": 2.0 if planned >= run.next_helicopter_world else 0.0}))
	var kind = weighted(run, damp_history(run, choices))
	if kind == "mobile":
		run.mobile_slots += 1
		var alternatives = {"air_sequence": 3.0, "police": 2.0, "rush": 2.0 if planned >= run.next_rush_world else 0.0}
		if planned >= run.next_helicopter_world: alternatives.helicopter = 3.5
		if int(p.phase) >= 1: alternatives.soldier = 3.0
		kind = weighted(run, alternatives)
		if kind == "helicopter": run.helicopter_draws += 1
	return kind

static func placement(run, desired: float, before: float, after: float, speed: float) -> float:
	var margin = maxf(110, speed * 0.25)
	for segment in run.terrain.segments:
		if float(segment.height) != 0: continue
		var at = maxf(desired, float(segment.start) + margin + before)
		var excluded: Array[Vector2] = []
		for tunnel in run.tunnels:
			excluded.append(Vector2(float(tunnel.entry) + HordeRun.ANCHOR - 600, float(tunnel.entry) + HordeRun.ANCHOR + float(tunnel.length) + 900))
		for e in run.entities:
			if not e.taken and e.kind in ["crystal", "mask", "shield", "boost"]:
				excluded.append(Vector2(run.world_px + e.x - speed * 0.70, run.world_px + e.x + speed * 0.70))
		excluded.sort_custom(func(a, b): return a.x < b.x)
		for interval in excluded:
			if at - before < interval.y and at + after > interval.x: at = interval.y + before + margin
		if at + after <= float(segment.end) - margin and run.safe_world_position(at - before) and run.safe_world_position(at + after): return at
	return INF

static func gap_seconds(run, p: Dictionary) -> float:
	var roll = run.course_rng.randf()
	var bounds: Vector2 = HordeTuning.GAP_LARGE_SECONDS if roll < float(p.large_gap) else (HordeTuning.GAP_SMALL_SECONDS if roll < 0.58 else HordeTuning.GAP_MEDIUM_SECONDS)
	return run.course_rng.randf_range(bounds.x, bounds.y)

static func clearance_window(hold: float, height: float, level: int) -> Vector2:
	var window = Vector2(INF, -INF)
	for point in HordeBalance.jump_profile(hold, 1.0 / 120, level).samples:
		if -point.y >= height: window.x = minf(window.x, point.x);window.y = maxf(window.y, point.x)
	return window

static func bomb_launch(centre: float, hold: float, speed: float, level: int, height: float = 88.0) -> float:
	var above = clearance_window(hold, height, level)
	return centre - speed * ((above.x + above.y) * 0.5)

static func cluster_fit(requested: int, speed: float, level: int, height: float) -> Dictionary:
	for count in range(requested, 0, -1):
		for hold in [0.12, 0.25, 0.42, HordeBalance.MAX_HOLD]:
			var window = clearance_window(hold, height, level)
			var needed = (count - 1) * HordeTuning.BOMB_PITCH + HordeTuning.BOMB_WIDTH + 36 + speed * 0.08
			if (window.y - window.x) * speed >= needed: return {"count": count, "hold": hold}
	return {"count": 1, "hold": HordeBalance.MAX_HOLD}

static func cluster_recipe(run, kind: String, p: Dictionary) -> Array:
	if kind == "bomb": return [1]
	if kind == "bomb_pair": return [2]
	var recipes = [[1, 2], [1, 2, 3], [3, 4, 2], [2, 3, 2, 4, 3], [3, 2, 5, 3], [2, 4, 3, 6, 2]]
	var level = int(p.phase)
	var selection = run.developer_iteration - 1 if not run.developer_kind.is_empty() else run.course_rng.randi_range(0, mini(5, level + 1))
	var recipe: Array = recipes[posmod(selection, recipes.size())].duplicate()
	if run.developer_kind.is_empty():
		var max_groups = 2 if level == 0 else (3 if level <= 2 else 5)
		recipe.resize(mini(recipe.size(), max_groups))
		for i in range(recipe.size()): recipe[i] = mini(int(recipe[i]), int(p.cluster))
	return recipe

static func sequence_plan(run, kind: String, at: float, speed: float, p: Dictionary) -> Dictionary:
	if kind in ["traffic_sequence", "convoy", "rush"]: return HordeTraffic.plan(run, kind, at, speed, p)
	if kind == "combined": return HordeCombinations.plan(run, at, speed, p)
	var parts: Array[Dictionary] = []
	var commands: Array[Dictionary] = []
	var ground = run.terrain.floor_at(at)
	var level = int(run.levels.get("jump", 0))
	var cursor = at
	var ready = -INF
	var end = at
	var recovery = lerpf(0.16, 0.08, clampf(run.pressure, 0, 1))
	if kind in ["gap", "gap_chain", "collapse", "collapse_chain"]:
		var maximum = maxi(int(p.gap_chain), 3 if run.active_count() >= 36 else 1)
		if run.active_count() >= 51: maximum = maxi(maximum, 4)
		if not run.developer_kind.is_empty(): maximum = 4
		var count = run.course_rng.randi_range(2, maxi(2, maximum)) if kind in ["gap_chain", "collapse_chain"] else 1
		var narrow_chain = kind in ["gap_chain", "collapse_chain"] and (run.active_count() >= 36 or int(p.stage) >= 4)
		for i in range(count):
			var seconds = gap_seconds(run, p)
			var hold = HordeBalance.MAX_HOLD
			for choice in [0.04, 0.18, 0.36, HordeBalance.MAX_HOLD]:
				if seconds > 0.72: break
				if float(HordeBalance.jump_profile(choice, 1.0 / 120, level).time) >= seconds + 0.30: hold = choice;break
			if narrow_chain:
				hold = ([0.85, 0.42, 0.72, 0.55][posmod(i + run.developer_iteration, 4)] if kind == "collapse_chain" else (0.65 if i % 2 == 0 else 0.80))
				seconds = float(HordeBalance.jump_profile(hold, 1.0 / 120, level).time) - (0.18 if i == 0 else 0.08) - 0.08
			var approach = (0.18 if i == 0 else 0.08) if narrow_chain else 0.20
			cursor = maxf(cursor, ready + speed * approach)
			parts.append({"kind": "collapse" if kind in ["collapse", "collapse_chain"] else "gap", "x": cursor, "y": ground, "width": speed * seconds, "vx": 0.0})
			var launch = cursor - speed * approach
			commands.append({"x": launch, "hold": hold})
			end = launch + speed * float(HordeBalance.jump_profile(hold, 1.0 / 120, level).time)
			ready = end + speed * (0.075 if narrow_chain else recovery);cursor = ready

	else:
		var recipe = cluster_recipe(run, kind, p)
		for i in range(recipe.size()):
			var aerial_low = kind == "air_sequence" and i % 2 == 0
			var aerial_high = kind == "air_sequence" and not aerial_low
			var fit = cluster_fit(int(recipe[i]), speed, level, 162.0 if aerial_low else 88.0)
			var count = int(recipe[i]) if aerial_high else int(fit.count)
			var hold = float(fit.hold)
			var span = (count - 1) * HordeTuning.BOMB_PITCH
			var launch = bomb_launch(cursor + span * 0.5, hold, speed, level, 162.0 if aerial_low else 88.0)
			if aerial_high:
				cursor = maxf(cursor, ready + speed * 0.16)
			else:
				var shift = maxf(0, ready - launch)
				cursor += shift;launch += shift
			for j in range(count):
				var aerial = kind == "air_sequence"
				parts.append({"kind": "air_bomb" if aerial else "bomb", "x": cursor + j * HordeTuning.BOMB_PITCH, "y": ground - (105 if aerial_low else 265) if aerial else ground, "width": HordeTuning.BOMB_WIDTH, "vx": 0.0, "cluster_first": j == 0})
			if aerial_high:
				end = cursor + span + speed * 0.22
			else:
				commands.append({"x": launch, "hold": hold})
				end = launch + speed * float(HordeBalance.jump_profile(hold, 1.0 / 120, level).time)
			if kind == "mixed":
				# Short jumps fit below a matching upper row. Longer clusters get
				# their upper row in the landing lane, requiring jump/run/jump.
				var upper_x = cursor if hold <= 0.25 else end + speed * 0.18
				var upper_count = mini(4, count + (i % 2))
				var upper_height = maxf(285, float(HordeBalance.jump_profile(hold, 1.0 / 120, level).height) + 147) if hold <= 0.25 else 285.0
				for j in range(upper_count): parts.append({"kind": "air_bomb", "x": upper_x + j * HordeTuning.BOMB_PITCH, "y": ground - upper_height, "width": HordeTuning.BOMB_WIDTH, "vx": 0.0, "cluster_first": j == 0})
				end = maxf(end, upper_x + (upper_count - 1) * HordeTuning.BOMB_PITCH + speed * 0.24)
			ready = end + speed * recovery
			cursor = maxf(cursor + span + HordeTuning.BOMB_PITCH, ready)
	var start = at - speed * 1.5
	if not commands.is_empty(): start = minf(start, float(commands[0].x) - speed * 0.2)
	return {"parts": parts, "commands": commands, "start": start, "end": end + speed * 0.14}

static func fill_breathing(run, start: float, finish: float, speed: float, index: int) -> void:
	if not run.developer_kind.is_empty(): return
	var at = maxf(start, maxf(run.spawn_left() + 60, run.last_coin_group + speed * 3.2))
	while at + 400 < finish:
		run.fund_coins(at + 400, speed)
		# Planned content only: no repair spawns inside the visible camera.
		if run.reward_rng.randf() < HordeTuning.COIN_CHANCE and run.safe_reward_position(at): create_formation(run, at, speed, index)
		at += speed * 3.25

static func maintain_rhythm(_run) -> void:
	# The course cursor now fills the road off camera. Never inject visible coins.
	pass

static func build(run, absolute: float, index: int) -> float:
	var p = HordeDirector.profile(run.world_px, run.active_count(), run.pressure, run.recovery_left, run.tunnel_number())
	var speed = maxf(305, float(p.speed))
	var reaction = maxf(run.speed, speed)
	run.terrain.reserve(run, absolute + maxf(45000, reaction * 75), reaction)
	var pattern = draw_pattern(run, index, int(p.stage) >= 1)
	var sequence = pattern in ["bomb", "bomb_pair", "bomb_sequence", "air_sequence", "mixed", "gap", "gap_chain", "collapse", "convoy", "traffic_sequence", "combined", "rush", "collapse_chain"]
	var half = 130.0
	if MonsterCatalog.VEHICLES.has(pattern): half = float(HordeBalance.vehicle_geometry(MonsterCatalog.VEHICLES[pattern], speed).width) * 0.5
	absolute = maxf(absolute, run.spawn_left() + half + 30)
	if pattern == "soldier": absolute = maxf(absolute, run.spawn_left() + reaction * 0.85)
	var before = half + reaction * 0.45
	var after = half + reaction * 0.75
	var plan: Dictionary = {}
	if sequence:
		plan = sequence_plan(run, pattern, absolute, speed, p)
		before = absolute - float(plan.start) + reaction * 0.25
		after = maxf(float(plan.end), float(plan.get("validation_end", plan.end))) - absolute
	if pattern == "rush": before = maxf(850, reaction * 3.0)
	var desired = maxf(absolute, run.last_course_obstacle + reaction * 3.5) if pattern == "rush" else absolute
	if sequence and not plan.commands.is_empty():
		var launch_lead = absolute - float(plan.commands[0].x)
		desired = maxf(desired, run.last_course_obstacle + launch_lead + reaction * 0.12)
	var at = placement(run, desired, before, after, reaction)
	if plan.has("traffic_velocity") and not is_inf(at):
		# Reserve the whole off-camera sweep. Cars are already moving when
		# they enter the camera; their encounter coordinates remain unchanged.
		for attempt in range(4):
			var pre_time = maxf(0, (float(plan.start) + at - absolute - HordeRun.ANCHOR - run.world_px) / speed)
			var swept_after = after + absf(float(plan.traffic_velocity)) * pre_time
			var placed = placement(run, at, before, swept_after, reaction)
			if is_inf(placed) or absf(placed - at) < 0.01: at = placed;break
			at = placed
	if is_inf(at):
		run.course_unplaced += 1
		fill_breathing(run, absolute, absolute + reaction * 2.5, reaction, index)
		return absolute + reaction * 2.5
	if at > absolute + reaction * HordeTuning.MAX_QUIET_SECONDS: fill_breathing(run, absolute, at - before, reaction, index)
	var ground = run.terrain.floor_at(at)
	var finish = at + half + speed * 0.50
	var commands: Array[Dictionary] = []
	if sequence:
		var delta = at - absolute
		for part in plan.parts: part.x += delta;part.y += ground - run.terrain.floor_at(absolute)
		for command in plan.commands: command.x += delta
		plan.start += delta;plan.end += delta
		if plan.has("validation_commands"):
			for command in plan.validation_commands: command.x += delta
			plan.validation_end += delta
		if not HordeSequenceValidator.validate(run, plan.parts, plan.get("validation_commands", plan.commands), plan.start, float(plan.get("validation_end", plan.end)), float(plan.get("validation_speed", speed))):
			run.sequence_rejections += 1
			if run.developer_kind.is_empty(): create_formation(run, at, speed, index, 0)
			run.record_chunk("recovery", at, at + reaction * 1.8)
			return at + reaction * 1.8
		commands.assign(plan.commands)
		for part in plan.parts:
			var spawn_x = float(part.x) - run.world_px
			if part.get("moving_traffic", false):
				var pre_time = maxf(0, (float(plan.start) - HordeRun.ANCHOR - run.world_px) / speed)
				spawn_x -= float(plan.traffic_velocity) * pre_time
			var e = run.add_entity(part.kind, spawn_x, part.y, -89 if part.get("rushing", false) else 0, float(part.get("width", 70)))
			e.vx = 0;e.path_checked = true;e.path_mode = "sequence";e.plan_speed = speed;e.planned_world = part.x;e.course_kind = pattern;e.group = index
			e.cluster_first = part.get("cluster_first", true)
			if part.get("moving_traffic", false):
				e.motion_speed = plan.traffic_velocity;e.motion_waiting = false;e.vx = plan.traffic_velocity
				if e.kind == "car": e.rushing = true;e.rush_speed = plan.traffic_velocity;e.passengers.clear()
			if part.kind == "collapse": e.fracture_variant = posmod(index, 3)
			if part.kind in ["gap", "collapse"]: e.long_jump = float(part.width) / speed > 0.6;e.double_jump = false;run.last_gap_world = part.x
		finish = plan.end
	elif pattern in ["civilian", "rest"]:
		if pattern == "civilian": run.spawn_civilians(at - run.world_px, 1 if run.course_rng.randf() < 0.55 else run.course_rng.randi_range(2, 3), index + 400000)
		else:
			run.fund_coins(finish + speed * 0.65, speed)
			create_formation(run, at, speed, index)
	else:
		var entity: Dictionary
		if pattern == "rush": entity = run.spawn_rushing_car(at - run.world_px, index, true)
		else:
			var y = ground
			if pattern == "helicopter": y -= 100 if run.course_rng.randf() < float(p.low_helicopter) else 285
			entity = run.add_entity(pattern, at - run.world_px, y);entity.group = index
			if MonsterCatalog.VEHICLES.has(pattern): run.configure_vehicle(entity)
			if pattern == "helicopter" and run.last_course_obstacle > run.world_px + HordeRun.ANCHOR:
				entity.motion_speed = entity.vx;entity.vx = 0.0;entity.motion_waiting = true
				entity.motion_start_world = run.last_course_obstacle - HordeRun.ANCHOR + reaction * 0.45
		entity.plan_speed = speed;entity.course_kind = pattern;entity.planned_world = at
		if not reserve_hazard_path(run, entity, at, speed, ground): entity.taken = true;run.course_unplaced += 1
		if not entity.taken and MonsterCatalog.VEHICLES.has(pattern): run.vehicle_drought[pattern] = at
		if not entity.taken and pattern == "soldier": run.last_soldier_world = at
	if pattern in ["helicopter", "convoy"]: run.next_helicopter_world = at + reaction * float(HordeTuning.HELICOPTER_COOLDOWN_SECONDS[int(p.phase)])
	if pattern in ["mixed", "gap_chain", "convoy", "traffic_sequence", "combined", "collapse_chain"]: run.last_heavy_challenge = at
	if pattern not in ["civilian", "rest"]: run.last_course_obstacle = finish
	run.last_course_pattern = pattern
	run.record_chunk(pattern, at, finish, commands)
	if run.developer_kind.is_empty():
		run.fund_coins(finish + speed * 0.65, speed)
		for command in commands:
			if float(command.x) - run.last_coin_group < reaction * HordeBalance.GROUP_SECONDS.x: continue
			if run.coin_credit < 3: break
			if run.coin_credit >= 10 or run.reward_rng.randf() < 0.80: create_jump_trail(run, command, speed, index)
		var bases: Array[float] = [at - half - 540, finish + speed * 0.15]
		var scan = at + speed * 0.8
		while scan < finish and bases.size() < 12:
			bases.append(scan);scan += speed * 1.8
		for base in bases:
			if run.coin_credit < 3: break
			if base - run.last_coin_group < reaction * HordeBalance.GROUP_SECONDS.x: continue
			create_formation(run, base, speed, index)
	if run.developer_kind.is_empty() and run.course_rng.randf() < float(p.recruit_chance) and run.safe_world_position(finish + 220): run.spawn_civilians(finish + 220 - run.world_px, 1, index + 100000)
	run.invalidate_coins()
	var pace = run.course_rng.randf_range(float(p.pace_min), float(p.pace_max))
	return maxf(finish + reaction * (0.23 if run.pressure >= 0.5 else 0.45), at + reaction * pace)

static func travel_velocity(e: Dictionary) -> float:
	if e.get("rushing", false): return float(e.get("rush_speed", e.vx))
	return float(e.motion_speed) if e.get("motion_waiting", false) else float(e.vx)

static func hazard_rect(run, e: Dictionary, time: float = 0.0) -> Rect2:
	var x = run.world_px + float(e.x) + travel_velocity(e) * time
	var y = float(e.y) + (float(e.get("vy", 0)) * time if e.kind == "bullet" else 0.0)
	if MonsterCatalog.VEHICLES.has(e.kind): return Rect2(x - float(e.width) * 0.5, y - float(e.height), float(e.width), float(e.height))
	match str(e.kind):
		"bomb": return Rect2(x - 33, y - HordeTuning.BOMB_HEIGHT - 12, 66, HordeTuning.BOMB_HEIGHT + 12)
		"crate": return Rect2(x - 38, y - 74, 76, 74)
		"spikes": return Rect2(x - 40, y - 50, 80, 50)
		"hump": return Rect2(x - 62, y - 70, 124, 70)
		"air_bomb": return Rect2(x - 34, y - 43, 68, 86)
		"helicopter": return Rect2(x - 128, y - 105, 256, 200)
		"bullet": return Rect2(x - 20, y - 9, 40, 18)
	return Rect2()

static func reserve_hazard_path(run, entity: Dictionary, absolute: float, speed: float, ground: float) -> bool:
	var box = hazard_rect(run, entity)
	if box.size == Vector2.ZERO: return true
	if MonsterCatalog.VEHICLES.has(entity.kind) and not entity.get("rushing", false):
		if run.active_count() >= int(entity.get("required_count", MonsterCatalog.VEHICLES[entity.kind].need)):
			entity.path_checked = true;entity.path_mode = "flip"
			return true
		if HordeBalance.vehicle_jumpable(MonsterCatalog.VEHICLES[entity.kind], speed, int(run.levels.get("jump", 0))):
			entity.path_checked = true;entity.path_mode = "roof";return true
	var start = absolute - box.size.x * 0.5 - speed * 0.80
	var finish = absolute + box.size.x * 0.5 + speed * 0.80
	var duration = (finish - start) / speed
	# A complete encounter includes the approach and the recovery after landing.
	for hold in [-1.0, 0.04, HordeBalance.MAX_HOLD]:
		var profile = HordeBalance.jump_profile(maxf(0, hold), 1.0 / 120, int(run.levels.get("jump", 0)))
		for offset in ([0.0] if hold < 0 else [-0.22, -0.11, 0.0, 0.11, 0.22]):
			var launch_time = maxf(0, (absolute - start) / speed - float(profile.time) * 0.52 + offset)
			var points: Array[Vector2] = []
			for tick in range(ceili(duration * 120) + 1):
				var time = minf(duration, tick / 120.0)
				var y = 0.0
				if hold >= 0 and time >= launch_time and time - launch_time < float(profile.time):
					var index = clampi(roundi((time - launch_time) * 120), 0, profile.samples.size() - 1)
					y = profile.samples[index].y
				points.append(Vector2(time, y))
			if path_clear(run, points, start, speed, ground):
				entity.path_checked = true;entity.path_mode = "run" if hold < 0 else "jump"
				entity.path_hold = hold;entity.path_offset = offset
				return true
	return false

static func coin_clear(run, point: Vector2, other_coins: bool = true) -> bool:
	var radius = HordeBalance.COIN_CLEARANCE
	# The actual visual radius, bob, terrain and exclusion margins share world coordinates.
	for x in [point.x - radius, point.x, point.x + radius]:
		if point.y + radius >= run.terrain.floor_at(x) - 3: return false
	if run.terrain.near_edge(point.x, radius + 10): return false
	for e in run.entities:
		if e.taken: continue
		var x = run.world_px + float(e.x)
		if e.kind in ["gap", "collapse"] and point.x + radius > x and point.x - radius < x + float(e.width) and point.y + radius > run.terrain.floor_at(point.x) - 50: return false
		if e.kind == "coin":
			if other_coins and point.distance_to(Vector2(x, e.y)) < HordeBalance.COIN_DIAMETER * 1.35: return false
			continue
		var box = hazard_rect(run, e)
		if box.size == Vector2.ZERO: continue
		# Moving hazards reserve the corridor they will sweep, including future projectile motion.
		if absf(travel_velocity(e)) > 0: box = box.merge(hazard_rect(run, e, 6.0))
		if box.grow(radius + 8).has_point(point): return false
	return true

static func path_clear(run, samples: Array[Vector2], launch: float, speed: float, ground: float) -> bool:
	if samples.is_empty(): return false
	var duration = samples[-1].x
	var min_y = ground;var max_y = ground
	for sample in samples:
		min_y = minf(min_y, ground + sample.y);max_y = maxf(max_y, ground + sample.y)
	var body_bounds = Rect2(launch - 20, min_y - 108, duration * speed + 40, max_y - min_y + 116)
	var hazards: Array[Dictionary] = []
	var gaps: Array[Dictionary] = []
	for e in run.entities:
		if e.taken: continue
		if e.kind in ["gap", "collapse"]:
			if run.world_px + e.x < body_bounds.end.x and run.world_px + e.x + e.width > body_bounds.position.x: gaps.append(e)
			continue
		var box = hazard_rect(run, e)
		if box.size == Vector2.ZERO: continue
		if absf(travel_velocity(e)) > 0: box = box.merge(hazard_rect(run, e, duration))
		if box.grow(24).intersects(body_bounds): hazards.append(e)
	var previous = Vector2.ZERO
	for sample in samples:
		var x = launch + sample.x * speed
		var foot = ground + sample.y
		if foot > run.terrain.floor_at(x) + 0.1: return false
		if absf(foot - run.terrain.floor_at(x)) < 0.2:
			for gap in gaps:
				if x > run.world_px + gap.x and x < run.world_px + gap.x + gap.width: return false
		var vy = (sample.y - previous.y) / maxf(0.000001, sample.x - previous.x)
		var member = {"x": x, "y": foot, "vy": vy};previous = sample
		for e in hazards:
			var velocity = travel_velocity(e)
			for bob in ([-6.0, 0.0, 6.0] if e.kind in ["air_bomb", "helicopter"] else [0.0]):
				if HordeBalance.hazard_hits(e, member, run.world_px + velocity * sample.x, bob + (float(e.get("vy", 0)) * sample.x if e.kind == "bullet" else 0.0)): return false
	return true

static func create_jump_trail(run, command: Dictionary, speed: float, index: int) -> bool:
	var launch = float(command.x)
	var profile = HordeBalance.jump_profile(float(command.hold), 1.0 / 120, int(run.levels.get("jump", 0)))
	var ground = run.terrain.floor_at(launch)
	if not path_clear(run, profile.samples, launch, speed, ground): return false
	var points: Array[Vector2] = []
	var witness: Array[Vector2] = []
	var last = Vector2(-100000, 0)
	for sample in profile.samples:
		var point = Vector2(launch + sample.x * speed, ground + sample.y - 48)
		witness.append(point)
		if sample.x < 0.13 or sample.x > float(profile.time) - 0.12: continue
		if point.distance_to(last) < HordeBalance.COIN_SPACING: continue
		if not coin_clear(run, point): continue
		points.append(point);last = point
	if points.size() < 3 or not run.can_fund_coins(points.size()): return false
	if run.generation_started:
		for point in points:
			if point.x - HordeBalance.COIN_CLEARANCE <= run.spawn_left(): return false
	for point in points:
		var e = run.add_entity("coin", point.x - run.world_px, point.y)
		e.formation = 7;e.group = index
	run.coin_groups.append({"start": launch, "speed": speed, "mode": 7, "points": points, "witness": witness})
	while run.coin_groups.size() > 24: run.coin_groups.pop_front()
	run.last_coin_group = launch
	return true

static func create_formation(run, launch: float, speed: float, index: int, forced_mode: int = -1) -> bool:
	var profile = HordeBalance.jump_profile()
	var samples: Array[Vector2] = profile.samples
	var ground = run.terrain.floor_at(launch)
	var reach = float(profile.time) * speed
	if not run.terrain.safe_span(launch - 50, launch + reach + 65, 65): return false
	if not run.safe_reward_position(launch) or not run.safe_reward_position(launch + reach): return false
	var mode = forced_mode if forced_mode >= 0 else run.course_rng.randi_range(0, 9)
	if forced_mode < 0 and not run.coin_groups.is_empty() and mode == int(run.coin_groups[-1].mode): mode = run.course_rng.randi_range(0, 9)
	if mode >= 7: return create_reachable_grid(run, launch, speed, index, mode)
	for attempt in range(2):
		var points: Array[Vector2] = []
		var witness: Array[Vector2] = []
		var count = 4
		var formation_rng = run.course_rng if forced_mode < 0 else run.reward_rng
		if mode == 0 or mode == 6:
			count = formation_rng.randi_range(3, 7)
			for i in range(count): points.append(Vector2(launch + i * HordeBalance.COIN_SPACING, ground - 48))
			for i in range(count * 12): witness.append(Vector2(launch + i * HordeBalance.COIN_SPACING / 12.0, ground - 48))
		else:
			if not path_clear(run, samples, launch, speed, ground): mode = 0;continue
			for sample in samples: witness.append(Vector2(launch + sample.x * speed, ground + sample.y - 48))
			count = clampi(int(reach * (0.65 if mode == 4 else 0.45) / HordeBalance.COIN_SPACING), 3, 7 if mode == 4 else 5)
			var start_x = launch + (reach - (count - 1) * HordeBalance.COIN_SPACING) * 0.5
			if mode == 2: start_x = launch + reach * 0.12
			if mode == 3: start_x = launch + reach * 0.52
			for i in range(count):
				var x = start_x + i * HordeBalance.COIN_SPACING
				var nearest = witness[0]
				for point in witness:
					if absf(point.x - x) < absf(nearest.x - x): nearest = point
				var y = nearest.y
				if mode == 1: y = ground - float(profile.height) - 28
				points.append(Vector2(x, y))
			if mode == 5:
				points.clear()
				var columns = 3 if speed >= 550 else 2
				var grid_y = ground - float(profile.height) - 45
				for col in range(columns):
					for row in range(2): points.append(Vector2(launch + reach * 0.53 + (col - (columns - 1) * 0.5) * HordeBalance.COIN_SPACING, grid_y + (row - 0.5) * HordeBalance.COIN_SPACING))
		var valid = true
		for point in points:
			var distance = INF
			for sample in witness: distance = minf(distance, point.distance_to(sample))
			if distance > HordeBalance.COIN_PATH_RADIUS or not coin_clear(run, point): valid = false;break
		if valid and mode in [0, 6]:
			# A running witness must also be clear, not merely its individual coin positions.
			var running: Array[Vector2] = []
			for point in witness: running.append(Vector2((point.x - launch) / speed, 0))
			valid = path_clear(run, running, launch, speed, ground)
			for point in witness:
				for e in run.entities:
					var box = hazard_rect(run, e, (point.x - launch) / speed)
					if not e.taken and box.size != Vector2.ZERO and Rect2(point.x - 18, point.y - 53, 36, 99).intersects(box.grow(5)): valid = false
		if valid and not run.can_fund_coins(points.size()): valid = false
		if valid and run.generation_started:
			for point in points:
				if point.x - HordeBalance.COIN_CLEARANCE <= run.spawn_left(): valid = false;break
		if valid:
			for point in points:
				var coin = run.add_entity("coin", point.x - run.world_px, point.y)
				coin.formation = mode;coin.group = index
			run.coin_groups.append({"start": launch, "speed": speed, "mode": mode, "points": points, "witness": witness})
			while run.coin_groups.size() > 24: run.coin_groups.pop_front()
			run.last_coin_group = launch
			return true
		mode = 0
	return false

static func create_reachable_grid(run, launch: float, speed: float, index: int, mode: int) -> bool:
	var ground = run.terrain.floor_at(launch)
	var points: Array[Vector2] = []
	var witness: Array[Vector2] = []
	var centre = launch + speed * 0.65
	if mode == 7:
		for col in range(3):
			for row in range(3): points.append(Vector2(centre + (col - 1) * HordeBalance.COIN_SPACING, ground - 48 - row * HordeBalance.COIN_SPACING))
	elif mode == 8:
		for col in range(2):
			for row in range(4): points.append(Vector2(centre + (col - 0.5) * HordeBalance.COIN_SPACING, ground - 48 - row * HordeBalance.COIN_SPACING))
	else:
		for offset in [Vector2(-2, 0), Vector2(-1, -1), Vector2(0, -2), Vector2(1, -1), Vector2(2, 0)]: points.append(Vector2(centre, ground - 48) + offset * HordeBalance.COIN_SPACING)
	for point in points:
		if run.generation_started and point.x - HordeBalance.COIN_CLEARANCE <= run.spawn_left(): return false
		if not coin_clear(run, point): return false
		var reached = false
		for hold in [0.04, 0.18, 0.42, HordeBalance.MAX_HOLD]:
			var profile = HordeBalance.jump_profile(hold, 1.0 / 120, int(run.levels.get("jump", 0)))
			for fraction in [0.25, 0.40, 0.55, 0.70, 0.85]:
				var start = point.x - speed * float(profile.time) * fraction
				if not run.terrain.safe_span(start - 30, start + speed * float(profile.time) + 30, 35): continue
				var nearest = INF
				for sample in profile.samples: nearest = minf(nearest, Vector2(start + sample.x * speed, ground + sample.y - 48).distance_to(point))
				if nearest > HordeBalance.COIN_PATH_RADIUS or not path_clear(run, profile.samples, start, speed, ground): continue
				for sample in profile.samples: witness.append(Vector2(start + sample.x * speed, ground + sample.y - 48))
				reached = true;break
			if reached: break
		if not reached: return false
	if not run.can_fund_coins(points.size()): return false
	for point in points:
		var coin = run.add_entity("coin", point.x - run.world_px, point.y);coin.formation = mode;coin.group = index
	run.coin_groups.append({"start": launch, "speed": speed, "mode": mode, "points": points, "witness": witness})
	while run.coin_groups.size() > 24: run.coin_groups.pop_front()
	run.last_coin_group = launch
	return true
