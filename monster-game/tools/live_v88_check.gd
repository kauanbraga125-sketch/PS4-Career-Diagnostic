extends SceneTree
var reports: Array[Dictionary] = []
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func observe(count: int, stage: int, seed_value: int, guided: bool) -> void:
	var r = HordeRun.new();r.start({},seed_value);r.entities.clear();r.tunnels.clear();r.terrain.reset()
	r.entered_tunnels=stage;r.completed_tunnels=stage
	r.speed=HordeDirector.stage_speed(stage);r.cruise_speed=r.speed;r.last_effective_speed=r.speed
	r.schedule_tunnel(stage+1,HordeTuning.tunnel_interval(r.speed))
	while r.members.size()<count:r.add_member(0,false)
	var held_until=-1.0;var done: Dictionary={};var seen: Dictionary={};var spawn_checks=0
	var total_us=0;var slowest_us=0;var mixed_seen=0
	for frame in range(120*30):
		if r.dead:break
		var lead=r.leader_index()
		if guided and lead>=0:
			var body=r.members[lead];var absolute=r.world_px+float(body.x)
			for chunk in r.generation_trace:
				for j in range(chunk.commands.size()):
					var command=chunk.commands[j];var key=str(chunk.chunk)+":"+str(j)
					if done.has(key) or absolute+r.speed/30*.20<float(command.x):continue
					if absolute-float(command.x)>r.speed*.50:done[key]=true;continue
					var previous=r.jump_sequence;r.jump()
					if r.jump_sequence>previous:held_until=r.elapsed+float(command.hold);done[key]=true
			if absf(body.vy)<.1 and absf(body.y-float(r.member_floor(body).y))<.2:
				for e in r.entities:
					if e.taken:continue
					var incoming=e.get("rushing",false) or (e.kind=="helicopter" and e.course_kind!="convoy" and e.y>HordeRun.FLOOR-180) or e.kind=="bullet"
					if MonsterCatalog.VEHICLES.has(e.kind) and not e.get("rushing",false) and r.active_count()<int(MonsterCatalog.VEHICLES[e.kind].need):incoming=true
					if not incoming:continue
					var edge=float(e.x)-(float(e.width)*.5 if MonsterCatalog.VEHICLES.has(e.kind) else (90 if e.kind=="helicopter" else 0))
					var seconds=(edge-float(body.x))/maxf(1,r.speed-float(e.vx))
					if seconds>0 and seconds<.37:r.jump();held_until=r.elapsed+1.05;break
				for i in range(1,r.terrain.segments.size()):
					var seg=r.terrain.segments[i]
					if seg.height<=r.terrain.segments[i-1].height:continue
					var ahead=float(seg.start)-absolute-18
					if ahead>0 and ahead<r.speed*.27:r.jump();held_until=r.elapsed+1.05
		var first=r.next_entity_id;var began=Time.get_ticks_usec()
		r.advance(1.0/30,r.elapsed<held_until)
		var used=Time.get_ticks_usec()-began;total_us+=used;slowest_us=maxi(slowest_us,used)
		for e in r.entities:
			if e.id>=first and e.kind!="bullet":
				spawn_checks+=1
				var half=float(e.width)*.5 if MonsterCatalog.VEHICLES.has(e.kind) else 40
				if float(e.created_x)-half<=float(e.created_right):failures.append("visible live spawn "+str(e.kind))
			if not e.taken and e.x>HordeRun.ANCHOR and e.x<1100 and not seen.has(e.id):
				seen[e.id]=true
				if e.get("course_kind","")=="mixed":mixed_seen+=1
		r.events.clear()
	var report={"horde_start":count,"stage_start":stage,"seed":seed_value,"guided":guided,"seconds":snappedf(r.elapsed,.1),"dead":r.dead,"horde_end":r.active_count(),"losses":r.losses,"recruits":r.recruits,"tunnels":r.tunnel_number(),"mixed_bombs_seen":mixed_seen,"off_camera_spawn_checks":spawn_checks,"mean_step_ms":snappedf(total_us/maxf(1,r.elapsed*30)/1000,.01),"slowest_step_ms":snappedf(slowest_us/1000.0,.01)}
	reports.append(report);print("LIVE_V88 "+JSON.stringify(report))
	if not guided and r.losses<6:failures.append("large horde remains unthreatened")
func run() -> void:
	for seed_value in [88801,88802]:
		observe(36,3,seed_value,false);observe(36,3,seed_value,true)
		observe(88,8,seed_value,false);observe(88,8,seed_value,true)
	FileAccess.open(OS.get_environment("HORDE_LIVE_V88_REPORT"),FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"reports":reports},"  "))
	print("LIVE_V88_RESULT "+JSON.stringify({"failures":failures}));quit(0 if failures.is_empty() else 1)
