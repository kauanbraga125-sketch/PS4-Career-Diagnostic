extends Node

var failures: Array[String]=[]

func check(value: bool,message: String) -> void:
	if value: return
	failures.append(message)
	push_error("HORDE_TEST_FAIL: "+message)

func run(game) -> void:
	game.sound.set_enabled(false)
	check(game.art.creatures.size()==4 and game.art.items.size()==12,"Four animated creatures and twelve real item sprites")
	for kind in range(4):
		check(game.art.creatures[kind].size()==6,"Idle, four running poses and jump pose: "+str(kind))
		check(game.art.rigs[kind].size()==9,"Nine separate articulated parts for each creature")
	check(game.art.layers.size()==3,"Three real transparent parallax scenery layers")
	check(MonsterCatalog.defaults().owned==[0],"Only the zombie visual is unlocked initially")
	for i in range(100):
		var a=HordeActor.stride_foot(float(i)/100)
		var joint=HordeActor.knee(Vector2(-2,-37),a)
		check(absf(joint.distance_to(Vector2(-2,-37))-24)<.1 and absf(joint.distance_to(a)-22)<.1,"Run leg stays connected throughout its stride")
	check(game.sound.clips.moon_menu.get_length()>20 and game.sound.clips.midnight_run.get_length()>20,"Two original offline music tracks")
	check(game.sound.clips.jump.get_length()>.1 and game.sound.clips.perk.get_length()>.3,"Jump and transformation effects bundled")
	game.data=MonsterCatalog.defaults()
	var wallet=game.data.wallet
	check(game.buy_upgrade(0),"Can purchase a permanent improvement")
	check(game.data.wallet==wallet-50 and game.data.levels.horde==1,"Purchase charges exact price and changes level")
	game.data.wallet=0
	check(not game.buy_upgrade(0) and game.data.wallet==0,"Cannot buy without enough currency")
	game.data.wallet=5000
	for i in range(5): game.buy_upgrade(0)
	check(game.data.levels.horde==3,"Shop respects upgrade level limit")
	var max_wallet=game.data.wallet
	check(not game.buy_upgrade(0) and game.data.wallet==max_wallet,"Maxed improvement cannot charge twice")
	game.start_run()
	game.capture_freeze=true
	check(game.runner.members.size()==4,"Purchased initial horde changes real next run")
	game.runner.entities.clear()
	game.runner.next_segment=99999
	game.runner.add_entity("coin",HordeRun.ANCHOR+4,HordeRun.FLOOR-48)
	var prior=game.data.wallet
	game.runner.advance(1.0/60)
	game.consume_run_events()
	check(game.runner.coins==1 and game.data.wallet==prior+1,"Physical coin pickup deposits currency")
	var count=game.runner.members.size()
	game.runner.add_entity("recruit",HordeRun.ANCHOR+4,HordeRun.FLOOR,1)
	game.runner.advance(1.0/60)
	game.consume_run_events()
	check(game.runner.members.size()==count+1 and game.runner.members[-1].kind==1,"Collectable skeleton joins mixed horde")
	game.runner.jump()
	for i in range(12): game.runner.advance(1.0/60,true)
	check(game.runner.members[0].y<HordeRun.FLOOR-65,"Tap and hold produces an actual airborne jump")
	var flight_velocity=game.runner.members[0].vy
	game.runner.jump()
	check(game.runner.members[0].jump_delay<0 and game.runner.members[0].vy==flight_velocity,"A second air tap requires the double-jump upgrade")
	for i in range(95): game.runner.advance(1.0/60)
	check(absf(game.runner.members[0].y-HordeRun.FLOOR)<.1,"Jump lands safely on floor")
	game.runner.add_entity("crystal",HordeRun.ANCHOR+4,HordeRun.FLOOR-48)
	game.runner.advance(1.0/60)
	game.consume_run_events()
	check(game.runner.perk_kind==3 and game.runner.perk_left>6,"Distinctive crystal activates mutant-fly transformation")
	var during=game.runner.members.size()
	for i in range(60): game.runner.advance(1.0/60,false)
	game.runner.add_entity("spikes",HordeRun.ANCHOR+4,HordeRun.FLOOR,0,95)
	game.runner.advance(1.0/60)
	game.consume_run_events()
	check(game.runner.members.size()==during,"Automatic flight safely avoids a ground hazard")
	game.runner.entities.clear()
	game.runner.add_entity("gap",HordeRun.ANCHOR-80,HordeRun.FLOOR,0,500)
	for i in range(80): game.runner.advance(1.0/60)
	check(game.runner.members.size()==during and game.runner.members[0].y<HordeRun.FLOOR,"Fly wings safely cross a pit")
	game.runner.entities.clear()
	for i in range(430): game.runner.advance(1.0/60)
	check(game.runner.perk_kind==-1 and game.runner.members[-1].kind==1,"Perk expires and restores original mixed creatures")
	game.runner.grant_perk(2)
	game.runner.add_entity("car",HordeRun.ANCHOR+4,HordeRun.FLOOR,0,155)
	game.runner.advance(1.0/60);game.consume_run_events()
	check(game.runner.members.size()==during+1 and game.runner.cars==1,"Masked transformation flips a car and frees a recruit")
	var car_test=HordeRun.new()
	car_test.start({"horde":2,"jump":0,"magnet":0,"perk":0},42)
	car_test.entities.clear();car_test.next_segment=99999
	var blocked=car_test.add_entity("car",HordeRun.ANCHOR+4,HordeRun.FLOOR,0,155)
	car_test.advance(1.0/60)
	check(not blocked.taken and car_test.cars==0,"Three grounded members cannot flip a car")
	car_test.start({"horde":3,"jump":0,"magnet":0,"perk":0},42)
	car_test.entities.clear();car_test.next_segment=99999
	car_test.add_entity("car",HordeRun.ANCHOR+4,HordeRun.FLOOR,0,155)
	car_test.advance(1.0/60)
	check(car_test.cars==1 and car_test.members.size()==5 and car_test.coins==8,"Exactly four grounded creatures flip a car and earn its rewards")
	var flight=HordeRun.new()
	flight.start({"horde":0,"jump":0,"magnet":0,"perk":0},11)
	flight.entities.clear();flight.next_segment=99999
	flight.grant_perk(3)
	for i in range(45): flight.advance(1.0/60,false)
	var hover=flight.members[0].y
	flight.jump()
	for i in range(60): flight.advance(1.0/60,true)
	check(flight.members[0].y>hover+100,"Holding flight control dives toward the ground")
	var high=flight.members[0].y
	for i in range(60): flight.advance(1.0/60,false)
	check(flight.members[0].y<high-100 and flight.members[0].y>=HordeRun.FLOOR-210,"Releasing flight automatically rises to a safe hover")
	for i in range(100): flight.advance(1.0/60,true)
	check(flight.members[0].y>=HordeRun.FLOOR-210,"Flying cannot leave the playable screen")
	flight.perk_left=.001
	for i in range(120): flight.advance(1.0/60,false)
	check(flight.perk_kind==-1 and absf(flight.members[0].y-HordeRun.FLOOR)<.1,"Fly expiration lands and restores normal jump control")
	flight.jump();flight.advance(1.0/60,true)
	check(flight.members[0].vy<0,"Jump is usable again after flight ends")
	var frenzy=HordeRun.new()
	frenzy.start({"horde":0,"jump":0,"magnet":0,"perk":0},12)
	frenzy.entities.clear();frenzy.next_segment=99999
	frenzy.add_entity("boost",HordeRun.ANCHOR+4,HordeRun.FLOOR-48)
	frenzy.advance(1.0/60)
	for i in range(90): frenzy.advance(1.0/60)
	frenzy.add_entity("coin",HordeRun.ANCHOR+4,HordeRun.FLOOR-48)
	frenzy.advance(1.0/60)
	check(frenzy.speed>320 and frenzy.coins==2 and frenzy.boost_px>0,"Frenzy really accelerates and doubles coin pickup")
	var pit_test=HordeRun.new()
	pit_test.start({"horde":3,"jump":0,"magnet":0,"perk":0},42)
	pit_test.entities.clear();pit_test.next_segment=99999
	pit_test.add_entity("gap",HordeRun.ANCHOR+50,HordeRun.FLOOR,0,145)
	pit_test.jump()
	for i in range(160): pit_test.advance(1.0/60,i<12)
	check(pit_test.members.size()==4 and not pit_test.dead,"Followers reproduce the leader's jump and cross a pit without unavoidable losses")
	# Losing the last creature must finish once, while collected money remains.
	game.data.levels=MonsterCatalog.defaults().levels
	game.start_run();game.capture_freeze=true
	game.runner.next_segment=99999;game.runner.entities.clear()
	var coins_before=game.data.wallet
	game.runner.add_entity("coin",HordeRun.ANCHOR+4,HordeRun.FLOOR-48)
	game.runner.advance(1.0/60);game.consume_run_events()
	game.runner.add_entity("crate",HordeRun.ANCHOR+4,HordeRun.FLOOR,0,72)
	game.runner.advance(1.0/60);game.consume_run_events()
	check(game.runner.dead and game.runner.members.is_empty(),"Last casualty ends the run")
	check(game.data.wallet==coins_before+1,"Currency is retained after losing")
	var runs=game.data.runs
	game.runner.finish();game.consume_run_events()
	check(game.data.runs==runs,"Finish cannot count or bank a run twice")
	game.end_delay=-1;game.start_run();game.capture_freeze=true
	check(not game.runner.dead and game.runner.members.size()==1,"Retry starts a clean playable run")
	game.runner.world_px=15000;game.runner.coins=25;game.runner.recruits=5
	var reward_start=game.data.wallet
	game.check_challenges();game.check_challenges()
	check(game.data.wallet==reward_start+165 and game.data.missions_completed==3 and game.data.mission_tier==1,"Three missions pay exactly once and unlock the next trio")
	game.data.wallet=240
	check(game.buy_skin(1) and game.data.wallet==0 and game.data.skin==1,"Buying a visual charges once and equips it")
	check(game.buy_skin(1) and game.data.wallet==0,"Equipping an owned visual never charges again")
	check(not game.buy_skin(3) and 3 not in game.data.owned,"Locked expensive skins require enough earned coins")
	game.perform_action("pause")
	var frozen=game.runner.world_px
	game._physics_process(.5)
	check(game.runner.world_px==frozen and game.screen=="pause","Pause stops progression")
	game.perform_action("home")
	check(game.screen=="home" and game.data.best>=500,"Ending a paused run preserves record")
	# Real file round trip, fallback to backup, malformed data bounds.
	var path="user://horde-regression.json"
	game.data.wallet=431
	check(game.save_game(path),"Atomic save succeeds")
	game.data.wallet=532
	check(game.save_game(path),"Second save creates recovery backup")
	check(game.read_save(path).wallet==532,"Disk round-trip retains wallet and improvements")
	check(game.read_save(path).owned==[0,1] and game.read_save(path).skin==1,"Owned skins and equipped leader survive disk round-trip")
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string("null");file.close()
	check(game.read_save(path).wallet==431,"Backup recovers an invalid primary save")
	var bounded=game.validate_save({"version":1,"wallet":-9,"levels":{"horde":999},"claimed":["unrecognised"]})
	check(bounded.wallet==0 and bounded.levels.horde==3 and bounded.claimed.is_empty(),"Invalid data cannot create negative wallet or impossible levels")
	var legacy=game.validate_save({"version":1,"wallet":654,"best":700,"levels":{"horde":2},"claimed":["recruits","coins","distance"]})
	check(legacy.wallet==654 and legacy.best==700 and legacy.levels.horde==2 and legacy.mission_tier==1,"Updating from alpha 0.1 preserves money, record, upgrades and claimed rewards")
	var invalid_skin=game.validate_save({"version":2,"owned":[0,1,1,99],"skin":3})
	check(invalid_skin.owned==[0,1] and invalid_skin.skin==0,"A save cannot equip an unowned visual or duplicate ownership")
	game.effects.clear()
	for i in range(400): game.effects.spark(Vector2(100,100),Color.WHITE,1)
	check(game.effects.particles.size()<=240,"Dense animated effects stay within the particle budget")
	game.effects.update(3,285)
	check(game.effects.particles.is_empty(),"Transient effects clean themselves after expiring")
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(path+suffix)
	check(not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"),"Touch cannot duplicate purchases through a synthetic mouse click")
	# Check course generation stays bounded across long sessions.
	var stress=HordeRun.new()
	stress.start({"horde":3,"jump":3,"magnet":3,"perk":3},42)
	for i in range(18000):
		if stress.dead: stress.start({"horde":3,"jump":3,"magnet":3,"perk":3},42+i)
		if i%23==0: stress.jump()
		stress.advance(1.0/60,true);stress.drain_events()
		if stress.entities.size()>110: check(false,"Endless course cleans expired entities"); break
	check(stress.members.size()<=24,"Horde remains within mobile rendering budget")
	regressions_v3(game)
	if failures.is_empty():
		print("HORDE_TEST_OK: permanent pit death, survivor continuity, game over/retry, adaptive difficulty/recovery, four districts/tunnels, six vehicle thresholds, bombs/helicopters/soldier bullets, balloon flight, character deaths/audio, progression/save v1-v3 and bounded long-run simulation")
		get_tree().quit(0)
	else: get_tree().quit(1)

func isolated(count: int=1,kind: int=0) -> HordeRun:
	var run=HordeRun.new()
	run.start(MonsterCatalog.defaults().levels,123,kind)
	run.entities.clear();run.events.clear();run.next_segment=99999
	for i in range(count-1): run.add_member(kind,false)
	return run

func ticks(run: HordeRun,count: int,held: bool=false) -> void:
	for i in range(count): run.advance(1.0/60,held)

func regressions_v3(game) -> void:
	check(game.art.rigs.size()==6 and game.art.world_layers.size()==4,"Four monster rigs, civilian, soldier and four painted worlds")
	check(game.art.vehicles.size()==6 and game.art.props.size()==6,"Six new vehicle images and six characteristic props")
	for name in ["voice_zombie","voice_skeleton","voice_masked","voice_fly","death_zombie","death_skeleton","death_masked","death_fly","city_scream","city_ambience","gunshot","explosion","tunnel"]:
		check(game.sound.clips.has(name) and game.sound.clips[name].get_length()>.1,"Real offline audio bundled: "+name)
	check(MonsterCatalog.defaults().areas==[0,1],"Cemetery and city unlocked initially")
	# A below-floor member remains dead even when solid floor returns before removal.
	for kind in range(4):
		var pit=isolated(1,kind)
		pit.add_entity("gap",HordeRun.ANCHOR-10,HordeRun.FLOOR,0,130)
		ticks(pit,11)
		check(pit.active_count()==0 and pit.members[0].falling,"Pit locks falling state for visual "+str(kind))
		var falling_y=pit.members[0].y
		pit.entities.clear()
		pit.add_entity("recruit",pit.members[0].x,HordeRun.FLOOR,1)
		pit.grant_perk(3);pit.jump();pit.add_member(1)
		ticks(pit,4,true)
		check(pit.members.size()==1 and pit.members[0].y>falling_y and pit.perk_kind==-1,"No floor, jump, perk or pickup can resurrect a falling member")
		ticks(pit,40)
		var ends=0
		for event in pit.drain_events():
			if event.type=="finish": ends+=1
		check(pit.dead and pit.members.is_empty() and ends==1,"Last pit death permanently finishes exactly once")
	var masked_pit=isolated(4)
	masked_pit.grant_perk(2);masked_pit.shields=1
	masked_pit.add_entity("gap",HordeRun.ANCHOR-200,HordeRun.FLOOR,0,550)
	ticks(masked_pit,90)
	check(masked_pit.dead and masked_pit.losses==4,"Mask and shield never protect against falling into a pit")
	var partial=isolated(4)
	var survivor_id=partial.members[1].id
	var survivor_x=partial.members[1].x
	partial.members[0].y=HordeRun.FLOOR+160;partial.members[0].vy=400;partial.members[0].falling=true
	ticks(partial,2)
	check(not partial.dead and partial.members.size()==3 and partial.members[0].id==survivor_id,"Partial loss preserves real surviving members")
	check(partial.members[0].x-survivor_x<3,"New leader closes spacing gradually instead of respawning at the front")
	# Every vehicle has its own real grounded strength threshold and reward.
	for name in MonsterCatalog.VEHICLES:
		var spec=MonsterCatalog.VEHICLES[name]
		var weak=isolated(int(spec.need)-1)
		var obstacle=weak.add_entity(name,HordeRun.ANCHOR+4)
		weak.advance(1.0/60)
		check(not obstacle.taken and weak.cars==0 and weak.losses==1,"One short cannot flip "+name)
		var strong=isolated(int(spec.need))
		strong.add_entity(name,HordeRun.ANCHOR+4);strong.advance(1.0/60)
		check(strong.cars==1 and strong.coins==int(spec.reward) and strong.active_count()==int(spec.need)+int(spec.rescues),"Exact threshold flips and rescues: "+name)
		var flip_found=false
		for event in strong.events:
			if event.type=="smash" and event.object==name: flip_found=true
		check(flip_found,"Specific animated flip event for "+name)
	var maximum_gap=isolated(24)
	maximum_gap.world_px=54000;maximum_gap.speed=500;maximum_gap.pressure=1
	maximum_gap.add_entity("gap",HordeRun.ANCHOR+35,HordeRun.FLOOR,0,325)
	maximum_gap.jump();ticks(maximum_gap,160,false)
	check(maximum_gap.active_count()==24 and not maximum_gap.dead,"Largest generated pit is crossable by every follower with an ordinary timed jump")
	var cap=isolated(24)
	cap.add_member(0)
	check(cap.active_count()==24 and cap.coins==2,"Horde cap admits the sixteen-member airplane challenge")
	# Consumable threats eliminate one member and cannot hit the whole group at once.
	for hazard in ["bomb","bullet","helicopter"]:
		var run=isolated(4)
		var y=HordeRun.FLOOR-54 if hazard in ["bullet","helicopter"] else HordeRun.FLOOR
		var threat=run.add_entity(hazard,HordeRun.ANCHOR+4,y)
		ticks(run,35)
		check(run.losses==1 and run.active_count()==3 and threat.taken,"Single casualty and threat consumed: "+hazard)
	var dodge=isolated()
	dodge.add_entity("bullet",HordeRun.ANCHOR+110,HordeRun.FLOOR-64)
	dodge.jump();ticks(dodge,50,true)
	check(not dodge.dead and dodge.losses==0,"Jump avoids an approaching army bullet")
	var army=isolated(4)
	var soldier=army.add_entity("soldier",1100);soldier.timer=.01
	army.advance(1.0/60)
	var fired=false
	for e in army.entities:
		if e.kind=="bullet": fired=true
	check(army.shots==1 and fired and soldier.flash>0,"Distant soldier actually fires a visible moving bullet")
	var vulnerable=isolated(4)
	vulnerable.grant_perk(3);ticks(vulnerable,60,true)
	vulnerable.add_entity("bomb",HordeRun.ANCHOR+4)
	vulnerable.advance(1.0/60,true)
	check(vulnerable.losses==1,"Diving fly remains vulnerable to ground hazards")
	# Smooth scaling depends on tunnel and crew; recovery changes future spawns only.
	var easy=HordeDirector.profile(0,2,0,0)
	var large=HordeDirector.profile(30000,22,1,0)
	var recovery=HordeDirector.profile(30000,2,0,7)
	check(large.speed>easy.speed and large.gap>easy.gap and large.recruit_chance<easy.recruit_chance,"Speed, pit size and fewer recruits scale with progress and a large horde")
	check(large.pressure_target>.9 and recovery.pressure_target==0 and recovery.recruit_chance>.95 and recovery.gap<=180,"Tunnel five escalates large crews; severe losses stabilize the profile")
	var regroup=isolated(10)
	regroup.world_px=30000;regroup.speed=430;regroup.pressure=.8
	var existing=regroup.add_entity("bomb",1000)
	for i in range(3): regroup.remove_member(0,"test")
	var x=existing.x
	regroup.advance(1.0/60)
	var rescues=0
	for e in regroup.entities:
		if e.kind=="recruit": rescues+=1
	check(regroup.recovery_left>6 and rescues>=2 and absf(existing.x-(x-regroup.speed/60))<.01,"Loss recovery adds recruits without teleporting an existing hazard")
	var hard_spawns=isolated(22);hard_spawns.world_px=30000;hard_spawns.pressure=1
	var soft_spawns=isolated(2);soft_spawns.world_px=30000;soft_spawns.recovery_left=7
	for i in range(80): hard_spawns.spawn_segment(20+i);soft_spawns.spawn_segment(20+i)
	var hard_recruits=0;var soft_recruits=0
	for e in hard_spawns.entities:
		if e.kind=="recruit": hard_recruits+=1
	for e in soft_spawns.entities:
		if e.kind=="recruit": soft_recruits+=1
	check(soft_recruits>hard_recruits*2,"Adaptive profile actually generates more recruits after heavy losses")
	var route=isolated()
	route.world_px=HordeRun.ZONE_LENGTH-HordeRun.ANCHOR-100
	check(route.area()==0 and route.inside_tunnel(),"Styled tunnel begins before the district boundary")
	route.world_px+=150
	check(route.area()==1 and route.tunnel_number()==1,"First tunnel leads from cemetery to free city")
	route.start(MonsterCatalog.defaults().levels,123,0,[3,3,2,99])
	check(route.route==[0,1,3,2],"Only purchased unique districts enter the route")
	for i in range(1,7):
		route.world_px=i*HordeRun.ZONE_LENGTH-HordeRun.ANCHOR
		check(route.area()==route.route[i%4],"District route repeats correctly at tunnel "+str(i))
	var civilian_x=game.scenery.civilians[0].x
	route.world_px=7000;game.scenery.reset();game.scenery.update(3,route)
	check(game.scenery.civilians[0].x!=civilian_x and "background_scream" in game.scenery.events,"City people move and scream on their own schedule")
	game.scenery.update(4,route)
	check("background_crash" in game.scenery.events,"Background helicopter crash triggers its own sound")
	game.data=MonsterCatalog.defaults();game.data.wallet=1900
	check(game.buy_area(2) and game.data.wallet==1200 and game.data.areas==[0,1,2],"Industrial district purchase uses earned coins")
	check(game.buy_area(2) and game.data.wallet==1200,"Unlocked district never charges twice")
	check(game.buy_area(3) and game.data.wallet==0 and game.data.areas==[0,1,2,3],"Airport purchase unlocks the fourth district")
	game.start_run();game.capture_freeze=true
	check(game.runner.route==[0,1,2,3],"Purchased worlds appear in the next actual run")
	# The game UI must reach game-over from an actual full-horde pit loss.
	game.runner.entities.clear();game.runner.next_segment=99999
	game.runner.add_entity("coin",HordeRun.ANCHOR+4,HordeRun.FLOOR-48)
	game.runner.advance(1.0/60);game.consume_run_events()
	var banked=game.data.wallet
	game.runner.add_entity("gap",HordeRun.ANCHOR-20,HordeRun.FLOOR,0,160)
	ticks(game.runner,70);game.consume_run_events()
	check(game.runner.dead and game.end_delay>0 and not game.effects.deaths.is_empty(),"Last pit death creates characteristic animation and queues game over")
	game.capture_freeze=false;game._process(1.01);game.capture_freeze=true
	check(game.screen=="results" and game.data.wallet==banked,"Styled game over is reached and earned coins remain")
	game.perform_action("play");game.capture_freeze=true
	check(game.screen=="run" and not game.runner.dead and game.runner.active_count()==1,"Retry from the game-over action starts a fresh run")
	var migrated=game.validate_save({"version":2,"wallet":876,"best":654,"owned":[0,1],"skin":1,"levels":{"jump":2}})
	check(migrated.version==3 and migrated.wallet==876 and migrated.best==654 and migrated.areas==[0,1] and migrated.skin==1,"Alpha 0.2 migrates to 0.3 with two free worlds and all purchases intact")
	var sanitized=game.validate_save({"version":3,"areas":[3,3,99,-1],"mission_progress":{},"claimed":["0:coins"]})
	check(sanitized.areas==[0,1,3] and sanitized.mission_progress.coins==25,"District ownership and already claimed mission bars sanitize correctly")
	game.data.areas=[0,1,2,3]
	var save_path="user://horde-v3-regression.json"
	game.save_game(save_path)
	check(game.read_save(save_path).areas==[0,1,2,3] and game.read_save(save_path).version==3,"All four worlds survive version-three disk round-trip")
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(save_path+suffix)
	game.effects.clear()
	for kind in range(4): game.effects.death(kind,Vector2(340,HordeRun.FLOOR-30))
	var debris=[]
	for part in game.effects.particles: debris.append(part.kind)
	check(game.effects.deaths.size()==4 and "bone" in debris and "mask" in debris and "fly" in debris and "wing" in debris,"Four different short death animations exist")
	for i in range(40): game.effects.death(1,Vector2(340,544))
	check(game.effects.deaths.size()<=24 and game.effects.particles.size()<=240,"Death fragments also respect mobile effect budgets")
	game.effects.update(2,0)
	check(game.effects.deaths.is_empty() and game.effects.particles.is_empty(),"Deaths never respawn a creature and clean up quickly")
