class_name HordeTraffic
extends RefCounted

# Build in relative coordinates, then map inputs back to the road. Every car
# travels at its full speed from its off-camera creation, not a proximity trigger.
static func plan(run, kind: String, at: float, speed: float, p: Dictionary) -> Dictionary:
	var variation = posmod(run.developer_iteration - 1, 8) if not run.developer_kind.is_empty() else run.course_rng.randi_range(0, 7)
	for attempt in range(4):
		var result = compose(run, kind, at, speed, p, variation, attempt * 0.055)
		if HordeSequenceValidator.validate(run, result.parts, result.validation_commands, result.start, result.validation_end, result.validation_speed): return result
	return compose(run, kind, at, speed, p, variation, 0.25)

static func compose(run, kind: String, at: float, speed: float, p: Dictionary, variation: int, extra_recovery: float) -> Dictionary:
	var velocity = -clampf(speed * (0.52 + (variation % 3) * 0.045), 165, 340)
	var closing = speed - velocity
	var start = at - speed * 1.35
	var ground = run.terrain.floor_at(at)
	var level = int(run.levels.get("jump", 0))
	var count = 1 if kind == "rush" else (2 + variation % 3 if int(p.phase) >= 1 else 2)
	var parts: Array[Dictionary] = []
	var commands: Array[Dictionary] = []
	var cursor = at
	var ready = -INF
	var end = start
	var geometry = HordeBalance.vehicle_geometry(MonsterCatalog.VEHICLES.car)
	for i in range(count):
		var low_heli = kind == "convoy" and variation % 2 == 1 and i % 2 == 1
		var pair = not low_heli and variation % 4 == 2 and i == 1
		var hold = 0.72 if low_heli else (HordeBalance.MAX_HOLD if pair else [0.12, 0.18, 0.25, 0.15][(variation + i) % 4])
		var pair_pitch = float(geometry.width) + 34
		var offset = -90.0 if low_heli else -float(geometry.width) * 0.5 + (pair_pitch * 0.5 if pair else 0)
		var window = HordeCourse.clearance_window(hold, 162 if low_heli else 106, level)
		var launch = cursor + offset - closing * (window.x + window.y) * 0.5
		var shift = maxf(0, ready - launch)
		cursor += shift;launch += shift
		if low_heli:
			parts.append({"kind": "helicopter", "x": cursor, "y": ground - 82, "width": 256.0, "vx": 0.0, "moving_traffic": true})
		else:
			for j in range(2 if pair else 1):
				var part = {"kind": "car", "x": cursor + j * pair_pitch, "y": ground, "vx": 0.0, "rushing": true, "moving_traffic": true}
				part.merge(geometry);parts.append(part)
		commands.append({"x": launch, "hold": hold})
		end = launch + closing * float(HordeBalance.jump_profile(hold, 1.0 / 120, level).time)
		# Roof contact is a real landing. Reserve enough road to descend from
		# the last roof, without fitting the entire horde into that landing.
		var roof_exit = cursor + (114 if low_heli else float(geometry.width) * 0.42 + (pair_pitch if pair else 0))
		end = maxf(end, roof_exit + closing * (0.48 if low_heli else 0.28))
		ready = end + closing * (lerpf(0.12, 0.055, clampf(run.pressure, 0, 1)) + extra_recovery)
		if kind == "convoy" and not low_heli:
			if variation >= 4:
				# A high helicopter overlaps the back of the car: a controlled
				# short jump clears the car; holding too long meets the aircraft.
				var high_x = cursor + 150 + (pair_pitch if pair else 0)
				var height = float(HordeBalance.jump_profile(hold, 1.0 / 120, level).height) + 155
				parts.append({"kind": "helicopter", "x": high_x, "y": ground - height, "width": 256.0, "vx": 0.0, "moving_traffic": true})
				ready = maxf(ready, high_x + 130 + closing * 0.035)
			elif (variation + i) % 2 == 0:
				var high = ready + 121 + closing * 0.035
				parts.append({"kind": "helicopter", "x": high, "y": ground - 285, "width": 256.0, "vx": 0.0, "moving_traffic": true})
				ready = high + 130 + closing * 0.055
				end = ready
		cursor = ready + closing * (window.x + window.y) * 0.5 - offset
	var actual: Array[Dictionary] = []
	for command in commands: actual.append({"x": start + (float(command.x) - start) * speed / closing, "hold": command.hold})
	var finish = start + (maxf(end, ready) - start) * speed / closing + speed * 0.18
	return {"parts": parts, "commands": actual, "start": start, "end": finish, "validation_commands": commands, "validation_end": maxf(end, ready) + closing * 0.18, "validation_speed": closing, "traffic_velocity": velocity, "variation": variation}
