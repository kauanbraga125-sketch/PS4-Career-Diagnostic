class_name HordeSequenceValidator
extends RefCounted

const STEP = 1.0 / 60.0

# Replay the same surfaces, ceiling contacts, hold physics and follower delay
# used by the live run. A sorted sweep bounds the work per encounter.
static func validate(run, parts: Array[Dictionary], commands: Array[Dictionary], start: float, finish: float, speed: float) -> bool:
	if parts.is_empty() or speed < 1 or not run.terrain.safe_span(start - 40, finish + 40, 40): return false
	var ground = run.terrain.floor_at(start)
	var bounds: Array[Dictionary] = []
	var solids: Array[Dictionary] = []
	for part in parts:
		if MonsterCatalog.VEHICLES.has(part.kind) or part.kind == "helicopter": solids.append(part)
		if MonsterCatalog.VEHICLES.has(part.kind) and not part.get("rushing", false) and run.active_count() >= int(part.get("required_count", MonsterCatalog.VEHICLES[part.kind].need)): continue
		var left = float(part.x) - float(part.get("width", 70)) * 0.5 - 20
		var right = float(part.x) + float(part.get("width", 70)) * 0.5 + 20
		if part.kind in ["gap", "collapse"]: left = part.x;right = part.x + part.width
		bounds.append({"left": left, "right": right, "part": part})
	bounds.sort_custom(func(a, b): return a.left < b.left)
	# Prove a playable route for the responding runner. Fitting the entire
	# tail here would silently widen every challenge and erase crowd risk.
	var cases = [{"offset": 0.0, "delay": 0.0}]
	for test in cases:
		var m = {"x": start - float(test.offset), "y": ground, "vy": 0.0, "air_time": 0.0, "hold_open": false, "release_left": 0.0}
		var next_command = 0;var next_bound = 0
		var active: Array[Dictionary] = []
		var hold_until = -1.0
		var coyote = 0.1
		var duration = (finish - start + float(test.offset)) / speed
		for frame in range(ceili(duration / STEP) + 1):
			var time = frame * STEP
			m.x = start + time * speed - float(test.offset)
			while next_bound < bounds.size() and float(bounds[next_bound].left) <= float(m.x):
				active.append(bounds[next_bound]);next_bound += 1
			var floor_here = true
			for i in range(active.size() - 1, -1, -1):
				if float(active[i].right) < float(m.x): active.remove_at(i);continue
				var part: Dictionary = active[i].part
				if part.kind in ["gap", "collapse"] and float(m.x) > float(part.x) and float(m.x) < float(part.x) + float(part.width): floor_here = false
			var floor_y = ground
			for part in solids:
				var body = HordeBalance.surface(part)
				if float(m.x) >= body.position.x and float(m.x) <= body.end.x and float(m.y) <= body.position.y + 2 and body.position.y < floor_y:
					floor_y = body.position.y;floor_here = true
			var grounded = floor_here and absf(float(m.y) - floor_y) < 2 and float(m.vy) >= 0
			coyote = 0.1 if grounded else maxf(0, coyote - STEP)
			if next_command < commands.size() and float(m.x) >= float(commands[next_command].x) + speed * float(test.delay):
				if not grounded and coyote <= 0: return false
				HordeBalance.launch(m, int(run.levels.get("jump", 0)));coyote = 0
				hold_until = time + float(commands[next_command].hold);next_command += 1
			var previous_y = float(m.y)
			HordeBalance.integrate(m, STEP, time < hold_until)
			if floor_here and previous_y <= floor_y + 0.01 and float(m.y) >= floor_y and float(m.vy) >= 0: m.y = floor_y;m.vy = 0.0
			HordeBalance.resolve_ceiling(m, previous_y, solids)
			if float(m.y) > ground + 12: return false
			for bound in active:
				var part: Dictionary = bound.part
				if part.kind in ["gap", "collapse"]: continue
				for bob in ([-6.0, 6.0] if part.kind in ["air_bomb", "helicopter"] else [0.0]):
					if HordeBalance.hazard_hits(part, m, 0, bob): return false
	return true
