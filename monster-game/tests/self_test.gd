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
	game.runner.add_entity("spikes",HordeRun.ANCHOR+4,HordeRun.FLOOR,0,95)
	game.runner.advance(1.0/60)
	game.consume_run_events()
	check(game.runner.members.size()==during,"Strong perk destroys a physical hazard")
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
	check(flight.members[0].y<hover-100,"Holding flight control rises without a double-jump purchase")
	var high=flight.members[0].y
	for i in range(60): flight.advance(1.0/60,false)
	check(flight.members[0].y>high+60 and flight.members[0].y<=HordeRun.FLOOR-71,"Releasing flight descends to a safe hover")
	for i in range(100): flight.advance(1.0/60,true)
	check(flight.members[0].y>=HordeRun.FLOOR-300,"Flying cannot leave the playable screen")
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
	for i in range(60): frenzy.advance(1.0/60)
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
	check(stress.members.size()<=12,"Horde remains within mobile rendering budget")
	if failures.is_empty():
		print("HORDE_TEST_OK: articulated animation, parallax, flight control, four-member car flips, frenzy, skin shop, renewing missions, effects bounds, save migration and gameplay regression")
		get_tree().quit(0)
	else: get_tree().quit(1)
