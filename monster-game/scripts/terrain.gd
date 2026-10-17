class_name HordeTerrain
extends RefCounted

enum State { NORMAL, ELEVATED, RETURN }
var state = State.NORMAL
var generated_to = 0.0
var segments: Array[Dictionary] = []

func reset() -> void:
	state = State.NORMAL;generated_to = 14500.0
	segments.assign([{"start": -100000.0, "end": generated_to, "height": 0.0, "state": State.NORMAL}])

func reserve(run, through: float, speed: float) -> void:
	run.ensure_tunnels(through + 3000)
	while generated_to < through:
		if state == State.RETURN: state = State.NORMAL
		var length: float
		var height = 0.0
		if state == State.ELEVATED:
			# A full ground section, rather than many small fences around possible steps.
			state = State.RETURN
			length = maxf(13000, speed * run.course_rng.randf_range(45.0, 65.0))
		else:
			length = maxf(1100, speed * run.course_rng.randf_range(3.0, 3.8))
			var clear = run.safe_world_position(generated_to - 900) and run.safe_world_position(generated_to + length + 1200)
			for t in run.tunnels:
				if generated_to < float(t.entry) + HordeRun.ANCHOR + float(t.length) + 1800 and generated_to + length > float(t.entry) + HordeRun.ANCHOR - 1600: clear = false
			if clear:
				state = State.ELEVATED;height = HordeBalance.PLATFORM_HEIGHT
			else:
				length = maxf(1200, speed * 4.0)
		if not segments.is_empty() and float(segments[-1].height) == height:
			segments[-1].end = generated_to + length
		else:
			segments.append({"start": generated_to, "end": generated_to + length, "height": height, "state": state})
		generated_to += length
	while segments.size() > 3 and float(segments[1].end) < run.world_px - 2200: segments.pop_front()

func height_at(absolute: float) -> float:
	for s in segments:
		if absolute >= float(s.start) and absolute < float(s.end): return float(s.height)
	return 0.0

func floor_at(absolute: float) -> float:
	return HordeRun.FLOOR - height_at(absolute)

func safe_span(left: float, right: float, edge_margin: float = 0.0) -> bool:
	for s in segments:
		if left >= float(s.start) + edge_margin and right <= float(s.end) - edge_margin: return true
	return false

func near_edge(absolute: float, margin: float) -> bool:
	for i in range(1, segments.size()):
		if float(segments[i].height) != float(segments[i - 1].height) and absf(absolute - float(segments[i].start)) < margin: return true
	return false
