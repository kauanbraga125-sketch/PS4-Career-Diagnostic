class_name HordeJump
extends RefCounted

# Inputs travel through the logical queue in seconds. They are never replayed
# at the leader's old road position, and releasing the touch affects the crowd.
static func grounded(run, m: Dictionary) -> bool:
	if m.falling: return false
	var support = run.member_floor(m)
	return float(m.coyote) > 0 or (support.solid and absf(float(m.y) - float(support.y)) <= 2 and float(m.vy) >= 0)

static func available(run, first_touchdown: bool = false) -> int:
	var selected = -1
	var first_landing = INF
	for i in range(run.members.size()):
		var m: Dictionary = run.members[i]
		if not grounded(run, m): continue
		var landing = float(m.get("landed_at", -1))
		if selected < 0: selected = i
		if first_touchdown:
			if landing >= 0 and landing < first_landing: selected = i;first_landing = landing
		elif float(m.x) > float(run.members[selected].x): selected = i
	return selected

static func launch(run, m: Dictionary, wave: int) -> void:
	m.wave_id = wave;m.air_time = 0.0;m.last_jump_at = run.elapsed
	HordeBalance.launch(m, int(run.levels.get("jump", 0)))
	m.air_jumps += 1;m.coyote = 0.0;m.jump_at = -1.0
	m.jump_delay = -1.0 if m.jump_queue.is_empty() else maxf(0, float(m.jump_queue[0].due) - run.elapsed)

static func request(run) -> void:
	if run.dead or run.transform_left > 0: return
	var lead = run.leader_index()
	if lead < 0: return
	if run.perk_kind == 3 and run.perk_left > 0:
		run.events.append({"type": "wing", "x": run.members[lead].x, "y": run.members[lead].y - 50});return
	var index = available(run)
	var double = false
	if index < 0 and int(run.levels.get("jump", 0)) >= 2:
		for i in range(run.members.size()):
			var m: Dictionary = run.members[i]
			if not m.falling and int(m.air_jumps) < 2 and float(m.y) < float(run.member_floor(m).y): index = i;double = true;break
	if index < 0:
		run.jump_buffer_until = run.elapsed + HordeTuning.INPUT_BUFFER_SECONDS
		return
	begin_wave(run, index, double)

static func begin_wave(run, index: int, double: bool = false) -> void:
	run.jump_buffer_until = -1.0;run.jump_sequence += 1
	var wave = run.jump_sequence
	run.wave_started[wave] = run.elapsed;run.wave_holds[wave] = true
	for old in run.wave_started.keys():
		if int(old) < wave - 8: run.wave_started.erase(old);run.wave_holds.erase(old);run.wave_durations.erase(old)
	var origin: Dictionary = run.members[index]
	origin.jump_queue.clear()
	launch(run, origin, wave)
	var closing = maxf(1, run.speed)
	for e in run.entities:
		if e.taken or float(e.x) <= float(origin.x): continue
		if e.get("rushing", false) or (e.kind == "helicopter" and float(e.y) > run.ground_y(origin.x) - 180):
			var relative = run.speed - float(e.vx)
			if float(e.x) - float(origin.x) < relative * 1.5: closing = maxf(closing, relative)
	# Small groups retain some anticipation for their physical distance.
	# Coordination weakens as the crowd grows, so it cannot copy one trajectory.
	var coordination = lerpf(0.85, 0.35, clampf((run.active_count() - 12) / 76.0, 0, 1))
	var rank = 1
	for i in range(run.members.size()):
		var m: Dictionary = run.members[i]
		if m.falling or i == index: continue
		var extra_delay = run.follower_delay(rank)
		var due = run.elapsed + extra_delay + maxf(0, float(origin.x) - float(m.x)) / closing * coordination
		rank += 1
		while m.jump_queue.size() >= 3: m.jump_queue.pop_front()
		m.jump_queue.append({"due": due, "extra_delay": extra_delay, "expires": due + HordeTuning.FOLLOWER_INPUT_WINDOW, "id": wave, "double": double})
		m.jump_delay = maxf(0, float(m.jump_queue[0].due) - run.elapsed)
		m.jump_at = -1.0
	run.jumped = true;run.clean_air = true
	run.events.append({"type": "jump", "x": origin.x, "y": origin.y, "member": origin.id})

static func step(run, m: Dictionary, was_grounded: bool) -> void:
	if m.falling: return
	while not m.jump_queue.is_empty() and float(m.jump_queue[0].expires) < run.elapsed: m.jump_queue.pop_front()
	if m.jump_queue.is_empty(): m.jump_delay = -1.0;return
	var command: Dictionary = m.jump_queue[0]
	m.jump_delay = maxf(0, float(command.due) - run.elapsed)
	if run.elapsed + 0.00001 < float(command.due): return
	var double = bool(command.double) and int(m.air_jumps) < 2 and int(run.levels.get("jump", 0)) >= 2
	if was_grounded or float(m.coyote) > 0 or double:
		m.jump_queue.pop_front();launch(run, m, int(command.id))

static func resolve_buffer(run) -> void:
	if run.jump_buffer_until < run.elapsed: run.jump_buffer_until = -1.0;return
	var index = available(run, true)
	if index >= 0: begin_wave(run, index)
