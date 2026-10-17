extends SceneTree
var failures: Array[String] = []
var reports: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label);push_error(label)
func flat(count: int = 1) -> HordeRun:
	var r=HordeRun.new();r.start_developer("gap",count,3,81001)
	r.entities.clear();r.physics_surfaces.clear();r.physics_gaps.clear();r.events.clear();r.next_segment=99999
	for m in r.members:m.arrival=0
	return r
func input_checks() -> void:
	var r=flat(3)
	for m in r.members:m.y=450.0;m.vy=80.0;m.coyote=0.0
	r.members[1].y=574;r.members[1].vy=0;r.members[1].landed_at=1.0
	r.members[1].jump_queue=[{"due":10.0,"expires":11.0,"id":-1,"double":false}]
	r.jump()
	check(r.jump_sequence==1 and r.members[1].vy<0 and r.members[0].vy>0,"any landed member jumps immediately, despite older queue")
	r=flat(3)
	for m in r.members:m.y=450.0;m.vy=0.0;m.coyote=0.0
	r.members[2].y=571;r.members[2].vy=280.0
	r.jump();check(r.jump_sequence==0 and r.jump_buffer_until>0,"pre-landing input buffered")
	for i in range(3):r.advance(1.0/60,false)
	check(r.jump_sequence==1 and r.members[2].vy<0 and r.members[0].y<500,"first actual landing consumes buffer without index-zero dependency")
	r=flat(88);r.jump()
	check(is_equal_approx(float(r.members[35].jump_queue[0].extra_delay),.280) and is_equal_approx(float(r.members[87].jump_queue[0].extra_delay),.696),"cumulative 8ms without 120ms cap")
	var peak_front=574.0;var peak_back=574.0
	for i in range(180):
		r.advance(1.0/120,i<30)
		peak_front=minf(peak_front,r.members[0].y);peak_back=minf(peak_back,r.members[50].y)
	check(peak_back>peak_front+8,"release shortens a late follower's jump rather than replaying full hold")
	reports.append({"case":"release response","front_height":574-peak_front,"late_height":574-peak_back})
	var m=r.members[0];m.jump_queue=[{"due":0.0,"expires":.1,"id":999,"double":false}]
	HordeJump.step(r,m,false);check(m.jump_queue.is_empty(),"expired commands cannot jump on a later island")
func crowd_trial(count: int, blueprint: Dictionary) -> void:
	var r=flat(count);r.pressure=1.0
	for part in blueprint.parts:
		var e=r.add_entity(part.kind,part.x,part.y,0,part.width);e.vx=0
	var sent: Dictionary={};var hold_until=-1.0
	for frame in range(40*60):
		if r.dead or r.world_px+HordeRun.ANCHOR>float(blueprint.end)+400:break
		var lead=r.leader_index()
		if lead>=0:
			var absolute=r.world_px+float(r.members[lead].x)
			for i in range(blueprint.commands.size()):
				if sent.has(i) or absolute<float(blueprint.commands[i].x):continue
				r.jump();sent[i]=true;hold_until=r.elapsed+float(blueprint.commands[i].hold)
		r.advance(1.0/60,r.elapsed<hold_until);r.events.clear()
	reports.append({"case":"same narrow islands","horde_start":count,"horde_end":r.active_count(),"losses":r.losses,"first_survives":not r.member_by_id(0).is_empty()})
	check(count>1 or r.active_count()==1,"single runner has a viable narrow-island route")
	if count>=36:check(r.losses>0 and r.active_count()>0,"large horde disperses but route remains survivable "+str(count))
func vehicle_checks() -> void:
	var r=flat(36);r.developer_kind="";r.pressure=1;r.next_pattern_world=0
	var heavy=0
	for i in range(70):
		r.entities.clear();r.physics_surfaces.clear()
		var e=r.add_entity("car",3000+i*300);r.configure_vehicle(e)
		if e.required_count>36:heavy+=1
	check(heavy>=10 and heavy<=45,"probability of unflippable armored vehicles")
	var e=r.add_entity("car",440);e.required_count=44;e.reinforced=true
	for m in r.members:m.x=337;m.y=574
	r.update_vehicle(e,1.0/60);check(not e.taken,"vehicle uses per-instance force requirement")
	reports.append({"case":"armored vehicles","draws":70,"insufficient":heavy})
func plans() -> void:
	var r=flat(36);var p=HordeDirector.profile(0,36,r.pressure,0,3)
	for kind in ["traffic_sequence","convoy","collapse_chain","combined"]:
		var valid=0
		for v in range(8):
			r.developer_iteration=v+1
			var a=HordeCourse.sequence_plan(r,kind,3500,r.speed,p)
			if HordeSequenceValidator.validate(r,a.parts,a.get("validation_commands",a.commands),a.start,a.get("validation_end",a.end),a.get("validation_speed",r.speed)):valid+=1
			if kind=="collapse_chain":check(a.parts.size()>=2,"collapse chain has multiple collapsing spans")
		reports.append({"case":"planner","kind":kind,"valid":valid,"variants":8})
		check(valid==8,"valid compact variants "+kind+" "+str(valid))
func run() -> void:
	input_checks();vehicle_checks();plans()
	var r=flat(36);r.developer_iteration=1;r.pressure=1
	var p=HordeDirector.profile(0,36,1,0,3)
	var a=HordeCourse.sequence_plan(r,"gap_chain",3000,float(p.speed),p)
	for count in [1,36,88]:crowd_trial(count,a)
	print("V810_CHECK "+JSON.stringify({"failures":failures,"reports":reports}))
	FileAccess.open(OS.get_environment("HORDE_V810_REPORT"),FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"reports":reports},"  "))
	quit(0 if failures.is_empty() else 1)
