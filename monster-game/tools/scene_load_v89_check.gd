extends SceneTree
var failures: Array[String] = []
var reports: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func observe(count: int, stage: int) -> void:
	var r = HordeRun.new();r.start({},89090 + stage);r.entities.clear();r.physics_surfaces.clear();r.tunnels.clear()
	r.entered_tunnels = stage;r.completed_tunnels = stage;r.schedule_tunnel(stage+1,HordeTuning.tunnel_interval(HordeDirector.stage_speed(stage)))
	r.souls = 30 if stage == 3 else 60
	while r.members.size() < count: r.add_member(0,false)
	r.speed = HordeDirector.stage_speed(stage);r.cruise_speed = r.speed;r.last_effective_speed = r.speed
	var seen: Dictionary = {};var counts: Dictionary = {};var spawn_checks = 0
	var total_us = 0;var worst_us = 0;var generation_us = 0;var generation_count = 0
	for frame in range(90*60):
		r.hit_grace = 999;r.dead = false
		while r.members.size() > count: r.members.pop_back()
		for i in range(r.members.size()):
			var m = r.members[i];m.x = r.slot_x(i);m.falling = false;m.y = r.ground_y(m.x);m.vy = 0;m.jump_queue.clear();m.arrival = 0
		r.cached_active = -1
		while r.members.size() < count: r.add_member(0,false)
		var serial = r.next_entity_id;var chunk = r.pattern_index;var began = Time.get_ticks_usec()
		r.advance(1.0/60,false)
		var used = Time.get_ticks_usec() - began;total_us += used;worst_us = maxi(worst_us,used)
		if chunk != r.pattern_index: generation_us += used;generation_count += 1
		for e in r.entities:
			if e.id >= serial and e.kind != "bullet":
				spawn_checks += 1
				var half = float(e.width)*.5 if MonsterCatalog.VEHICLES.has(e.kind) or e.kind == "coin" else 42
				if e.kind in ["gap","collapse"]:half = 0
				if float(e.created_x) - half <= float(e.created_right): failures.append("visible spawn "+str(e.kind))
			if not seen.has(e.id):
				seen[e.id] = true
				var kind = "hostile_car" if e.rushing else str(e.kind)
				counts[kind] = int(counts.get(kind,0)) + 1
		r.events.clear()
	if r.souls > r.early_soul_limit(): failures.append("soul cap exceeded")
	var report = {"horde":count,"horde_end":r.active_count(),"stage_start":stage,"seconds":r.elapsed,"souls":r.souls,"soul_limit":r.early_soul_limit(),"spawn_checks":spawn_checks,"counts":counts,"sequence_rejections":r.sequence_rejections,"unplaced":r.course_unplaced,"mean_physics_ms":snappedf(total_us/(90.0*60)/1000,.001),"max_physics_ms":snappedf(worst_us/1000.0,.01),"mean_generation_ms":snappedf(generation_us/maxf(1,generation_count)/1000,.01),"generation_count":generation_count}
	reports.append(report);print("LOAD "+JSON.stringify(report))
func run() -> void:
	observe(36,3);observe(88,8)
	FileAccess.open(OS.get_environment("HORDE_V89_LOAD_REPORT"),FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"reports":reports},"  "))
	print("V89_LOAD_RESULT "+JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
