class_name HordeDirector
extends RefCounted

static func stage_speed(stage: int) -> float:
	# Increase the existing tunnel increments by 10%, keeping the initial speed.
	return 305 + 1.10 * (mini(stage, 5) * 11 + clampi(stage - 5, 0, 5) * 17 + 235 * (1.0 - exp(-maxi(0, stage - 10) / 14.0)))

static func profile(_world_px: float, count: int, pressure: float, recovery: float, stage: int = 0) -> Dictionary:
	var progress = clampf(float(stage) / 14.0, 0, 1)
	var size_pressure = clampf(float(count - 16) / 20.0, 0, 1)
	var target_pressure = size_pressure * lerpf(0.70, 1.0, clampf(stage / 3.0, 0, 1))
	if recovery > 0 or count <= 3: target_pressure = 0
	var difficulty = clampf(stage * 0.055 + maxi(0, stage - 4) * 0.04 + pressure * 0.25, 0, 1)
	var phase = HordeTuning.phase(stage)
	# A large early horde gets combinations immediately, rather than waiting for T8.
	if count >= 36 and recovery <= 0: phase = maxi(phase, 2)
	if count >= 51 and recovery <= 0: phase = maxi(phase, 3)
	var weights: Vector3 = HordeTuning.CHALLENGE_WEIGHTS[phase]
	weights += Vector3(-0.22, 0.06, 0.16) * pressure
	var growth = maxf(0.18, float(HordeTuning.GROWTH_CHANCE[HordeTuning.phase(stage)]) - pressure * 0.23)
	var recruit_chance = lerpf(0.11, 0.05, progress)
	if recovery > 0 or count <= 3:
		weights = Vector3(0.80, 0.18, 0.02);growth = minf(0.84, growth + 0.18)
		recruit_chance += 0.12;difficulty *= 0.8
	var pace = pressure * 0.42
	return {"stage": stage, "phase": phase, "challenge_weights": weights, "growth": growth * HordeTuning.POSITIVE_CONTENT_MULTIPLIER,
		"progress": progress, "pressure_target": target_pressure, "difficulty": difficulty,
		"recruit_chance": recruit_chance * HordeTuning.POSITIVE_CONTENT_MULTIPLIER, "occupancy": 1.0,
		"speed": stage_speed(stage) + pressure * lerpf(4, 14, progress),
		"bullet_period": clampf(1.35 * 305.0 / stage_speed(stage) - pressure * 0.16, 0.62, 1.35),
		"pace_min": (lerpf(2.8, 1.75, difficulty) - pace) * 0.92, "pace_max": (lerpf(3.8, 2.45, difficulty) - pace) * 0.92,
		"low_helicopter": lerpf(0.35, 0.65, progress), "large_gap": lerpf(0.24, 0.56, difficulty),
		"cluster": HordeTuning.MAX_BOMBS[phase], "gap_chain": HordeTuning.MAX_GAPS[phase],
		"gap": 150, "extra_hazard": clampf(stage * 0.025 + pressure * 0.12, 0, 0.35),
		"spacing": stage_speed(stage) * 1.8, "pattern_pause": stage_speed(stage) * 2.0,
		"max_gap_interval": 5000, "double_chance": 0.0}
