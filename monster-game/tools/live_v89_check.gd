extends SceneTree
var failures: Array[String] = []
var reports: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func observe(kind: String, count: int, stage: int, fps: int, guided: bool, variation: int = 0) -> void:
	var r = HordeRun.new();r.start_developer(kind,count,stage,89034 + stage)
	r.next_segment = 99999;r.developer_iteration = variation
	HordeCourse.build(r,3500,0)
	var held_until = -1.0;var done: Dictionary = {};var saw_hostile = 0
	var total_us = 0;var worst_us = 0
	var collisions: Dictionary = {}
	for frame in range(fps * 80):
		if r.dead or (not r.generation_trace.is_empty() and r.world_px + 50 > float(r.generation_trace[-1].end)): break
		var lead = r.leader_index()
		if guided and lead >= 0:
			var absolute = r.world_px + float(r.members[lead].x)
			for chunk in r.generation_trace:
				for j in range(chunk.commands.size()):
					var command = chunk.commands[j];var key = str(chunk.chunk) + ":" + str(j)
					if done.has(key) or absolute < float(command.x): continue
					var before = r.jump_sequence;r.jump()
					if r.jump_sequence > before: held_until = r.elapsed + float(command.hold);done[key] = true
		var before = Time.get_ticks_usec();r.advance(1.0 / fps,r.elapsed < held_until)
		var used = Time.get_ticks_usec() - before;total_us += used;worst_us = maxi(worst_us,used)
		for event in r.drain_events():
			if event.type == "hit": collisions[str(event.cause)] = int(collisions.get(str(event.cause),0)) + 1
	for e in r.entities:
		if e.kind == "car" and e.rushing:
			saw_hostile += 1
			if not e.passengers.is_empty(): failures.append("traffic passenger regression")
	var report = {"kind":kind,"horde":count,"stage":stage,"fps":fps,"guided":guided,"losses":r.losses,"horde_end":r.active_count(),"seconds":snappedf(r.elapsed,.01),"rejections":r.sequence_rejections,"commands":done.size(),"traffic_cars":saw_hostile,"collisions":collisions,"mean_step_ms":snappedf(total_us/maxf(1,r.elapsed*fps)/1000,.001),"max_step_ms":snappedf(worst_us/1000.0,.01)}
	reports.append(report);print("LIVE "+JSON.stringify(report))
	if guided and r.active_count() < maxi(1,count/2): failures.append("guided course too punishing "+kind+" "+str(fps))
	if guided and r.sequence_rejections > 0: failures.append("rejected developer encounter "+kind)
	if not guided and kind == "gap" and r.losses == 0: failures.append("idle horde not threatened")
func run() -> void:
	for fps in [30,60]:
		for kind in ["car","convoy","combined","gap","mixed"]: observe(kind,36,3,fps,true)
	observe("convoy",36,3,30,true,1)
	observe("convoy",88,8,60,true,1)
	observe("gap",88,8,30,false)
	observe("combined",88,8,30,false)
	FileAccess.open(OS.get_environment("HORDE_V89_LIVE_REPORT"),FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"reports":reports},"  "))
	print("V89_LIVE_RESULT "+JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
