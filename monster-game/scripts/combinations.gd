class_name HordeCombinations
extends RefCounted

static func plan(run, at: float, speed: float, p: Dictionary) -> Dictionary:
	var recipes = [["bomb", "collapse", "bomb"], ["collapse", "car"], ["gap", "bomb_pair", "collapse"], ["collapse", "bomb", "collapse"], ["collapse_chain"], ["bomb", "collapse_chain"], ["collapse_chain", "bomb_pair"]]
	var variation = run.developer_iteration - 1 if not run.developer_kind.is_empty() else run.course_rng.randi_range(0, recipes.size() - 1)
	var recipe: Array = recipes[posmod(variation, recipes.size())]
	var parts: Array[Dictionary] = []
	var commands: Array[Dictionary] = []
	var cursor = at
	var end = -INF
	for kind in recipe:
		if kind == "car":
			var x = end + speed * 0.40 + 110
			var part = {"kind": "car", "x": x, "y": run.terrain.floor_at(x), "vx": 0.0}
			part.merge(HordeBalance.vehicle_geometry(MonsterCatalog.VEHICLES.car));parts.append(part)
			end = x + float(part.width) * 0.5 + speed * 0.65
			if run.active_count() < int(MonsterCatalog.VEHICLES.car.need):
				var hold = 0.60
				var launch = HordeCourse.bomb_launch(x - float(part.width) * 0.5, hold, speed, int(run.levels.get("jump", 0)), 110)
				var shift = maxf(0, float(commands[-1].x) + speed * float(HordeBalance.jump_profile(float(commands[-1].hold), 1.0 / 120, int(run.levels.get("jump", 0))).time) + speed * 0.16 - launch)
				part.x += shift;launch += shift;end += shift
				commands.append({"x": launch, "hold": hold})
				end = maxf(end, launch + speed * float(HordeBalance.jump_profile(hold, 1.0 / 120, int(run.levels.get("jump", 0))).time))
		else:
			var child = HordeCourse.sequence_plan(run, kind, cursor, speed, p)
			var shift = maxf(0, end + speed * 0.035 - float(child.commands[0].x))
			for part in child.parts: part.x += shift;parts.append(part)
			for command in child.commands: command.x += shift;commands.append(command)
			end = float(child.end) + shift
		cursor = end + speed * 0.12
	var start = minf(at - speed * 1.5, float(commands[0].x) - speed * 0.25)
	return {"parts": parts, "commands": commands, "start": start, "end": end}
