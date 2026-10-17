extends SceneTree
var failures: Array[String] = []
var reports: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func observe(stage: int, seed_value: int) -> void:
	var r = HordeRun.new();r.start({},seed_value)
	if stage > 0:
		r.tunnels.clear();r.entered_tunnels = stage;r.completed_tunnels = stage
		r.speed = HordeDirector.stage_speed(stage);r.cruise_speed = r.speed;r.last_effective_speed = r.speed
		r.schedule_tunnel(stage+1,HordeTuning.tunnel_interval(r.speed))
	while r.members.size() < 16: r.add_member(0,false)
	var quiet = 0.0;var longest = 0.0;var raised = 0.0;var visible: Dictionary = {}
	for frame in range(240*30):
		# Distribution observer; actual physics is tested without this assistance.
		r.dead = false;r.hit_grace = 1000
		for i in range(r.members.size()):
			var m = r.members[i];m.x = r.slot_x(i);m.y = r.ground_y(m.x);m.vy = 0;m.falling = false;m.jump_queue.clear()
		r.advance(1.0/30,false)
		var content = false
		for e in r.entities:
			if e.taken or e.x < HordeRun.ANCHOR or e.x > 1280: continue
			content = true;visible[str(e.kind)] = int(visible.get(str(e.kind),0))+1
		quiet = 0 if content else quiet+1.0/30;longest = maxf(longest,quiet)
		if r.ground_y(HordeRun.ANCHOR)<HordeRun.FLOOR: raised += 1.0/30
		r.events.clear()
	if r.bonus_director.opportunities.size()<3 or r.bonuses<3: failures.append("bonus drought "+str(stage))
	if longest>8: failures.append("empty corridor "+str([stage,longest]))
	if raised/r.elapsed>0.10: failures.append("elevation "+str(stage))
	var report = {"seed":seed_value,"stage_start":stage,"seconds":r.elapsed,"tunnels":r.completed_tunnels,"visible_frames":visible,"bonus_opportunities":r.bonus_director.opportunities,"bonuses_collected":r.bonuses,"longest_quiet_seconds":longest,"raised_fraction":raised/r.elapsed,"chunks":r.pattern_index}
	reports.append(report);print("RHYTHM_RUN "+JSON.stringify(report))
func run() -> void:
	for stage in [0,8,11]: observe(stage,877000+stage)
	var result = {"failures":failures,"reports":reports}
	FileAccess.open(OS.get_environment("HORDE_RHYTHM_REPORT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("RHYTHM_RESULT "+JSON.stringify({"failures":failures}));quit(0 if failures.is_empty() else 1)
