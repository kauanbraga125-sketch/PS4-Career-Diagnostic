extends Node
var checks=0
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error("HORDE_V7_FAIL: "+message)
func isolated(count: int=1) -> HordeRun:
	var r=HordeRun.new();r.start(MonsterCatalog.defaults().levels,7015)
	r.entities.clear();r.events.clear();r.tunnels.clear();r.next_segment=99999
	for i in range(count-1):r.add_member(0,false)
	return r
func run(g) -> void:
	# Spatial launch is independent of frame rate and rear members' landing state.
	for fps in [30,60,120]:
		var r=isolated(8);var target=float(r.members[0].x);r.jump();var launched={};var launch_time={}
		for frame in range(fps*3):
			var before=r.world_px;r.advance(1.0/fps,true)
			for m in r.members:
				if m.air_jumps==1 and not launched.has(m.id):
					launched[m.id]=r.world_px+float(m.x);launch_time[m.id]=r.elapsed
			if launched.size()==8:break
		check(launched.size()==8,"All followers launch at "+str(fps)+" fps")
		for point in launched.values():check(absf(float(point)-target)<r.speed/float(fps)+3,"Wave uses the same world launch point")
		check(float(launch_time[7])>float(launch_time[0])+.4,"Rear visibly launches later")
	var wave=isolated(8);wave.jump()
	for i in range(30):wave.advance(1.0/60,true)
	wave.release_jump()
	var follower_id=int(wave.members[7].id);var follower_apex=0.0;var second=false
	for i in range(150):
		wave.advance(1.0/60,false)
		for m in wave.members:
			if m.id==follower_id:follower_apex=maxf(follower_apex,HordeRun.FLOOR-float(m.y))
		if not second and wave.members[0].y==HordeRun.FLOOR and wave.members[7].y<HordeRun.FLOOR:
			wave.jump();second=wave.jump_sequence==2
	check(second,"Leader can start a new wave while rear is airborne")
	check(follower_apex<120 and follower_apex>80,"A follower launching after release keeps a normal short impulse, without floating")
	for i in range(100):wave.advance(1.0/60,false)
	check(wave.members[7].wave_id==2,"New input is queued for airborne rear members")
	var rapid=isolated(3);rapid.jump();rapid.advance(.016,true);rapid.jump()
	check(rapid.jump_sequence==1,"Ordinary airborne taps cannot create unintended extra jumps")
	var release=isolated();release.jump()
	for i in range(18):release.advance(1.0/60,true)
	release.release_jump();var vy=release.members[0].vy;release.advance(1.0/60,false)
	check(absf(release.members[0].vy-vy-25)<.01,"Release restores normal gravity immediately")
	for kind in ["car","truck"]:
		var r=isolated(2);var spec=MonsterCatalog.VEHICLES[kind]
		var e=r.add_entity(kind,HordeRun.ANCHOR+float(spec.width)*.5+10)
		r.members[0].y=HordeRun.FLOOR-50;r.members[0].vy=-30
		for i in range(220):r.advance(1.0/60,false)
		check(not e.taken and r.cars==0 and r.dead,"A partial jump cannot phase through a solid "+kind+"; camera eliminates the blocked horde")
	var voices=isolated();var speakers=0
	for i in range(150):
		var npc=voices.add_entity("civilian",800+i*150)
		if npc.speaker:speakers+=1
	check(speakers==10,"Exactly one in 15 generated NPCs gets a balloon")
	var budgets={}
	for seed_value in range(58):
		var r=isolated();r.rng.seed=seed_value;r.entered_tunnels=2;budgets[r.early_soul_limit()]=true
	check(budgets.has(30) and budgets.has(34) and budgets.size()==2,"Early soul ceiling is normally 30, rarely 34")
	var capped=isolated();capped.entered_tunnels=2
	for i in range(50):capped.add_entity("civilian",1000+i*100)
	check(capped.entities.size()==30,"Visible early NPCs reserve soul slots before conversion")
	var recovering=isolated(4);recovering.entered_tunnels=7;recovering.world_px=200000;recovering.recovery_left=4;recovering.speed=305
	for i in range(30):
		recovering.entities.clear();recovering.last_gap_world=0;HordeCourse.build(recovering,202000+i*3000,40+i)
		for entity in recovering.entities:
			if entity.kind=="gap":check(entity.width<=305*.88+.1,"Recovery gaps remain reachable at the current reduced speed")
	var upcoming=HordeRun.new();upcoming.start(MonsterCatalog.defaults().levels,44)
	upcoming.entities.clear();upcoming.world_px=8499;upcoming.advance(.02)
	var found=false
	for e in upcoming.entities:found=found or (e.kind=="car" and e.rushing)
	check(found,"An oncoming car can appear before the first tunnel")
	check(g.art.passenger_frames.size()==12,"Four car escape, four bus panic and four unique rider poses exist")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/v7/manifest.json"))
	check(manifest.files.size()==60,"All 60 originals have independently processed copies")
	for entry in manifest.files:check(g.sound.clips.has(str(entry.output).trim_suffix(".ogg")),"Prepared clip loads: "+str(entry.output))
	var a=g.sound.choose_variant("MOV_02");var b=g.sound.choose_variant("MOV_02")
	check(a!=b,"Repeated events alternate variants instead of stacking them")
	g.sound.set_enabled(true);g.sound.celebrate();var guitar=0;var crowd=0
	for player in g.sound.players:
		if player.playing and player.stream in [g.sound.clips[g.sound.variants.VIT_01[0]]]:guitar+=1
		if player.playing and player.bus=="HordeVoices":crowd+=1
	check(guitar==1 and crowd==1,"Celebration combines one guitar with one crowd layer")
	g.sound.set_enabled(false)
	g.market.open(2);g.market.max_scroll=500;g.market.scroll_by(130)
	check(g.market.scroll==130 and g.market.page==0,"Store scrolls continuously without changing pages")
	var board=HordeProgress.board(1,19,3)
	check(board.level==2 and board.progress==2,"Soul jar display carries excess into the next level")
	print("HORDE_V7_CHECKS: ",checks)
