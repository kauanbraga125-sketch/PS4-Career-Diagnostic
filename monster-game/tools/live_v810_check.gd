extends SceneTree
var failures: Array[String]=[]
var reports: Array[Dictionary]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);push_error(label)
func trial(kind: String,count: int,variation: int=0) -> void:
	var r=HordeRun.new();r.start_developer(kind,count,3,81091)
	r.next_segment=99999;r.developer_iteration=variation
	HordeCourse.build(r,3500,0)
	var held_until=-1.0;var sent:Dictionary={};var speeds:Dictionary={}
	for e in r.entities:
		if e.rushing:
			check(float(e.vx)<=-165 and not e.get("motion_waiting",false),"car is moving from spawn")
			speeds[e.id]=e.vx
	var finish=float(r.generation_trace[-1].end) if not r.generation_trace.is_empty() else 6000.0
	for frame in range(60*40):
		if r.dead or r.world_px+340>finish+350:break
		var lead=r.leader_index()
		if lead>=0:
			var absolute=r.world_px+float(r.members[lead].x)
			for chunk in r.generation_trace:
				for j in range(chunk.commands.size()):
					if sent.has(j) or absolute<float(chunk.commands[j].x):continue
					r.jump();sent[j]=true;held_until=r.elapsed+float(chunk.commands[j].hold)
		r.advance(1.0/60,r.elapsed<held_until)
		for e in r.entities:
			if speeds.has(e.id):check(is_equal_approx(float(e.vx),float(speeds[e.id])),"no visible proximity acceleration")
		r.events.clear()
	var report={"kind":kind,"horde":count,"variation":variation,"survivors":r.active_count(),"losses":r.losses,"rejections":r.sequence_rejections,"commands":sent.size(),"seconds":r.elapsed}
	reports.append(report);print("LIVE810 "+JSON.stringify(report))
	check(r.sequence_rejections==0,"developer variant must be placed "+kind+str(variation))
	if count==1:check(r.active_count()==1,"single-runner route "+kind+str(variation))
	else:check(r.active_count()>0,"a compact challenge must remain survivable "+kind)
func soldier() -> void:
	var r=HordeRun.new();r.start_developer("soldier",1,3,81092);r.next_segment=99999;r.hit_grace=999
	var e=r.add_entity("soldier",2400);e.vx=0
	var fast=0
	for frame in range(6*60):
		r.advance(1.0/60,false)
		for bullet in r.entities:
			if bullet.kind=="bullet":check(absf(float(bullet.vx))>=330,"faster bullet speed");fast+=1
		r.events.clear()
	check(r.shots>=3,"distant soldier has time for multiple shots")
	var bullet={"kind":"bullet","previous_x":460.0,"previous_y":514.0,"x":240.0,"y":514.0}
	check(HordeBalance.projectile_swept_hit(bullet,{"x":340.0,"y":574.0}),"fast bullet swept collision")
	bullet.y=420;bullet.previous_y=420
	check(not HordeBalance.projectile_swept_hit(bullet,{"x":340.0,"y":574.0}),"high bullet can be avoided on foot")
	reports.append({"kind":"soldier","shots":r.shots,"initial_distance":2400,"bullet_checks":fast})
func run() -> void:
	for kind in ["car","convoy","combined","collapse","gap"]:trial(kind,1,0)
	trial("car",1,6);trial("convoy",1,5);trial("combined",1,1)
	trial("gap",36);trial("collapse",36);trial("convoy",36,4)
	soldier()
	FileAccess.open(OS.get_environment("HORDE_V810_LIVE_REPORT"),FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"reports":reports},"  "))
	print("V810_LIVE_RESULT "+JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
