extends Node

var failures: Array[String]=[]
var checks=0

func check(value: bool,message: String) -> void:
	checks+=1
	if value: return
	failures.append(message);push_error("HORDE_TEST_FAIL: "+message)

func isolated(count: int=1,kind: int=0) -> HordeRun:
	var r=HordeRun.new();r.start(MonsterCatalog.defaults().levels,4014,kind)
	r.entities.clear();r.events.clear();r.next_segment=99999
	r.members[0].kind=kind
	for i in range(count-1): r.add_member(kind,false)
	return r

func ticks(r: HordeRun,count: int,held: bool=false) -> void:
	for i in range(count): r.advance(1.0/60,held)

func run(game) -> void:
	game.sound.set_enabled(false);game.capture_freeze=true
	check(game.art.rigs.size()==9,"Four monsters, three humans, soldier and police rigs")
	check(game.art.tunnel_mouths.size()==2 and game.art.vfx.size()==6 and game.art.ritual.size()==4,"Real tunnel, fuse frames, soul capture frames and ritual assets")
	for name in ["voice_masked","soul_capture","level_up","ritual_fill","city_scream","death_skeleton"]: check(game.sound.clips.has(name) and game.sound.clips[name].get_length()>.1,"Bundled sound: "+name)
	check(game.sound.clips.voice_masked.get_length()>2.5,"Characteristic three-second masked whisper replaces old synthesized cue")
	for i in range(100):
		var foot=HordeActor.stride_foot(i/100.0);var joint=HordeActor.knee(Vector2(-2,-37),foot)
		check(absf(joint.distance_to(Vector2(-2,-37))-24)<.1 and absf(joint.distance_to(foot)-22)<.1,"Running joints remain connected")
	# Capturing is delayed, visible and available to each monster type.
	for kind in range(4):
		var r=isolated(1,kind)
		var npc=r.add_entity("civilian",HordeRun.ANCHOR+3,HordeRun.FLOOR,kind%3)
		npc.vx=0;npc.pose="run"
		r.advance(1.0/60)
		check(npc.state=="capture" and r.souls==0 and r.active_count()==1 and r.members[0].attack_left>0,"Physical capture starts a unique monster animation: "+str(kind))
		ticks(r,20)
		check(r.souls==0 and not npc.taken,"Human stays visible during capture, before conversion")
		ticks(r,25)
		check(r.souls==1 and r.recruits==1 and r.active_count()==2 and npc.taken,"One human becomes one soul and one monster only after capture")
		ticks(r,80)
		check(r.souls==1,"Converted human cannot be collected twice")
	var follower=isolated(3)
	follower.members[0].y=HordeRun.FLOOR-170;follower.members[0].vy=0
	var npc=follower.add_entity("civilian",follower.members[1].x,HordeRun.FLOOR,1);npc.pose="run";npc.vx=0
	follower.advance(1.0/60)
	check(npc.state=="capture" and npc.capturer==follower.members[1].id,"Followers also capture humans rather than leader-only pickups")
	var army=isolated(3)
	var soldier=army.add_entity("soldier",1100);soldier.timer=.01
	army.advance(1.0/60)
	check(army.shots==1 and soldier.flash>0,"Soldier fires real bullets from a distance")
	army.entities.clear();soldier=army.add_entity("soldier",HordeRun.ANCHOR+4)
	ticks(army,50)
	check(army.soldiers==1 and army.souls==1 and army.losses==0 and army.active_count()==4,"Touching a soldier captures and randomly converts him")
	# No creature can resurrect after crossing the floor from below.
	for kind in range(4):
		var pit=isolated(1,kind)
		pit.add_entity("gap",HordeRun.ANCHOR-10,HordeRun.FLOOR,0,130);ticks(pit,11)
		check(pit.active_count()==0 and pit.members[0].falling,"Pit locks irreversible falling state: "+str(kind))
		pit.entities.clear();pit.add_entity("civilian",pit.members[0].x);pit.jump();pit.grant_perk(3);pit.add_member(1)
		ticks(pit,40)
		check(pit.dead and pit.members.is_empty() and pit.souls==0,"Floor, jump, perk and NPC cannot revive the fallen horde")
	var failed_capture=isolated()
	var doomed=failed_capture.add_entity("civilian",HordeRun.ANCHOR);doomed.pose="run";doomed.vx=0
	failed_capture.advance(1.0/60);failed_capture.members[0].falling=true
	ticks(failed_capture,70)
	check(failed_capture.dead and failed_capture.souls==0,"Pending capture cannot revive a dead capturer")
	var shield_pit=isolated(4);shield_pit.grant_perk(2);shield_pit.shields=1
	shield_pit.add_entity("gap",HordeRun.ANCHOR-230,HordeRun.FLOOR,0,650);ticks(shield_pit,90)
	check(shield_pit.dead and shield_pit.losses==4,"Mask and shield never protect against pit loss")
	var jumpers=isolated(24);jumpers.world_px=120000;jumpers.speed=500;jumpers.pressure=1
	jumpers.add_entity("gap",HordeRun.ANCHOR+35,HordeRun.FLOOR,0,325);jumpers.jump();ticks(jumpers,160,true)
	check(jumpers.active_count()==24,"Full horde can cross the largest generated gap with a timed jump")
	# Vehicles count actual unique contacts and lean before a complete flip.
	for name in MonsterCatalog.VEHICLES:
		var spec=MonsterCatalog.VEHICLES[name]
		var r=isolated(int(spec.need))
		var vehicle=r.add_entity(name,HordeRun.ANCHOR+float(spec.width)*.5+12)
		r.advance(1.0/60)
		check(vehicle.contacts.size()==1 and r.cars==0 and not vehicle.taken,"First real contact is 1/"+str(spec.need)+": "+name)
		check(vehicle.tilt>0,"Intermediate leaning frame begins before flipping: "+name)
		var first_id=vehicle.contacts.keys()[0];r.advance(1.0/60)
		check(vehicle.contacts[first_id]==1 and vehicle.contacts.size()<=r.members.size(),"One member cannot add effort twice: "+name)
		for i in range(100):
			if vehicle.taken: break
			r.advance(1.0/60)
		check(vehicle.taken and r.cars==1 and vehicle.contacts.size()>=int(spec.need),"Only the complete contact count flips: "+name)
		var humans=0
		for e in r.entities:
			if e.kind=="civilian" and e.rescued: humans+=1
		check(humans==int(spec.rescues) and r.souls==0 and r.active_count()==int(spec.need),"Passengers leave as animated humans; no automatic recruit: "+name)
		ticks(r,170)
		check(r.souls>=1 and r.rescues>=1,"Escaped passengers can be physically captured: "+name)
		var weak=isolated(int(spec.need)-1)
		var obstacle=weak.add_entity(name,HordeRun.ANCHOR+float(spec.width)*.5+12)
		ticks(weak,120)
		check(weak.cars==0 and not obstacle.taken and weak.losses>0,"Insufficient crew stays blocked and loses members to the camera: "+name)
	check(MonsterCatalog.VEHICLES.plane.width>MonsterCatalog.VEHICLES.car.width*2.5 and MonsterCatalog.VEHICLES.bus.height>MonsterCatalog.VEHICLES.car.height*1.8,"Vehicle sizes preserve clearly different real-world proportions")
	var capture_cap=isolated(24)
	var human=capture_cap.add_entity("civilian",HordeRun.ANCHOR);human.pose="run";human.vx=0;ticks(capture_cap,50)
	check(capture_cap.active_count()==24 and capture_cap.souls==1,"Souls still count when the horde is full")
	# Balloon flight: ascent by default, held touch dives, no immortality.
	var fly=isolated(4);fly.grant_perk(3);ticks(fly,169);ticks(fly,60)
	var hover=fly.members[0].y;ticks(fly,70,true)
	check(fly.members[0].y>hover+100,"Held flight dives to ground")
	ticks(fly,65);check(fly.members[0].y<HordeRun.FLOOR-150,"Release rises automatically")
	fly.entities.clear();fly.add_entity("gap",HordeRun.ANCHOR-80,HordeRun.FLOOR,0,600);ticks(fly,90)
	check(fly.active_count()==4,"Auto flight clears a pit")
	for hazard in ["bomb","air_bomb","helicopter","bullet"]:
		var danger=isolated(4)
		var y=HordeRun.FLOOR if hazard=="bomb" else (HordeRun.FLOOR-64 if hazard=="bullet" else HordeRun.FLOOR-95)
		var e=danger.add_entity(hazard,HordeRun.ANCHOR+4,y);ticks(danger,35)
		check(danger.losses==1 and e.taken,"Consumable hazard costs exactly one member: "+hazard)
	var under=isolated(4);under.add_entity("helicopter",HordeRun.ANCHOR+160,HordeRun.FLOOR-280);ticks(under,90)
	check(under.losses==0,"High helicopter is safely passed underneath")
	var over=isolated(4);over.add_entity("helicopter",HordeRun.ANCHOR+260,HordeRun.FLOOR-95);over.jump();ticks(over,100,true)
	check(over.losses==0,"A timed held jump clears the low helicopter fuselage")
	var dodge=isolated();dodge.add_entity("bullet",HordeRun.ANCHOR+160,HordeRun.FLOOR-64);dodge.jump();ticks(dodge,80,true)
	check(not dodge.dead,"Timed jump dodges a real moving bullet")
	# Tunnel is an actual traversed interval, changes district only on exit.
	var route=isolated(4)
	check(float(route.tunnels[0].entry)==18000 and route.area()==0,"First tunnel begins at exactly 600 metres")
	route.world_px=17990;route.advance(.01)
	check(not route.inside_tunnel() and route.area()==0,"Approach is still outside")
	route.world_px=18001;route.advance(.01)
	check(route.inside_tunnel() and route.tunnel_number()==1 and route.area()==0,"Entering tunnel retains the old district")
	var exit=float(route.tunnels[0].entry)+float(route.tunnels[0].length)
	route.world_px=exit-10;route.advance(.01);check(route.area()==0 and route.inside_tunnel(),"Tunnel has a full interior length before exit")
	route.speed=420;route.world_px=exit+1;route.advance(.01)
	check(route.area()==1 and not route.inside_tunnel() and route.completed_tunnels==1,"Only exiting switches cemetery to city")
	check(absf(float(route.tunnels[1].entry)-exit-18000*maxf(1,route.speed/305))<1,"Faster runner gets a speed-matched interval before the next tunnel")
	check(not route.safe_world_position(18000+HordeRun.ANCHOR),"Hazards cannot be generated inside the tunnel")
	var hard=HordeDirector.profile(80000,22,1,0,6)
	var soft=HordeDirector.profile(80000,2,0,7,6)
	check(int(hard.cluster)>=3 and int(soft.cluster)<=2 and soft.recruit_chance>hard.recruit_chance,"Tunnel number increases obstacle groups and losses soften them")
	var generated=isolated(20);generated.entered_tunnels=6;generated.completed_tunnels=6;generated.pressure=1
	for i in range(30):generated.spawn_segment(50+i)
	var group_sizes={}
	for e in generated.entities:
		if e.kind in ["bomb","air_bomb","soldier","helicopter","gap","crate","spikes"]: group_sizes[e.group]=int(group_sizes.get(e.group,0))+1
	var found=false
	for n in group_sizes.values():
		if int(n)>=3:found=true
	check(found,"The actual generated course contains clusters of three or more threats")
	var recovery=isolated(10);recovery.pressure=.8;recovery.speed=430
	var bomb=recovery.add_entity("bomb",1000)
	for i in range(3):recovery.remove_member(0,"test")
	var x=bomb.x;recovery.advance(1.0/60)
	check(recovery.recovery_left>6 and absf(bomb.x-(x-recovery.speed/60))<.1,"Recovery never teleports an existing hazard")
	# Souls, level reward overflow and mission ritual pay only once.
	var data=MonsterCatalog.defaults();var rng=RandomNumberGenerator.new();rng.seed=440
	var report=HordeProgress.settle(data,65,rng)
	check(data.player_level==3 and data.level_souls==9 and data.best_souls==65 and data.total_souls==65,"Souls fill level one, then harder level two, retaining overflow")
	check(report.levels==2 and report.coins>=300 and data.wallet==120+int(report.coins),"Completed soul boards award randomized coins")
	check(HordeProgress.level_target(3)>HordeProgress.level_target(2) and HordeProgress.level_target(2)>HordeProgress.level_target(1),"Each player level requires more souls")
	data.ritual_progress=90
	var mission=MonsterCatalog.active_missions(0)[0]
	HordeProgress.queue_mission(data,mission);HordeProgress.queue_mission(data,mission)
	check(data.ritual_pending.size()==1,"One completed mission cannot queue twice")
	data.ritual_ready=false
	var wallet=data.wallet;var ritual=HordeProgress.ritual(data,rng)
	check(data.wallet==wallet and data.ritual_pending.size()==1,"Mission rewards wait until the run ends")
	data.ritual_ready=true;ritual=HordeProgress.ritual(data,rng)
	check(data.ritual_progress==12 and ritual.bonuses==1 and ritual.coins>=270 and data.wallet==wallet+int(ritual.coins),"Menu ritual fills, pays lucky bonus and retains overflow")
	wallet=data.wallet;HordeProgress.ritual(data,rng)
	check(data.wallet==wallet and data.ritual_pending.is_empty(),"Returning to menu cannot pay ritual twice")
	# Actual UI flow, banking, purchases and migration.
	game.data=MonsterCatalog.defaults();game.data.wallet=8000
	wallet=game.data.wallet;check(game.buy_upgrade(0) and game.data.wallet==wallet-350,"New balanced initial upgrade price")
	check(MonsterCatalog.upgrade_cost(MonsterCatalog.UPGRADES[0],1)==1400,"Improvement cost grows rather than allowing the entire shop in one run")
	game.data.levels.horde=0;game.start_run();game.capture_freeze=true
	game.runner.entities.clear();game.runner.next_segment=99999
	game.runner.add_entity("civilian",HordeRun.ANCHOR).pose="run";ticks(game.runner,50);game.consume_run_events()
	check(game.runner.souls==1 and game.data.active_souls==1,"Capture records a bankable soul through actual game events")
	game.runner.souls=8;game.runner.coins=40;game.runner.world_px=13500
	wallet=game.data.wallet;game.check_challenges();game.check_challenges()
	check(game.data.ritual_pending.size()==3 and game.data.wallet==wallet and game.data.mission_tier==1,"Three real missions queue ritual points and renew without immediate coin payout")
	game.runner.entities.clear();game.runner.add_entity("gap",HordeRun.ANCHOR-200,HordeRun.FLOOR,0,600);ticks(game.runner,90);game.consume_run_events()
	check(game.runner.dead and game.run_settled and game.data.best_souls==8,"Pit game over banks souls and a separate soul record")
	var total=game.data.total_souls;var runs=game.data.runs;game.finish_run()
	check(game.data.total_souls==total and game.data.runs==runs,"Finishing twice cannot duplicate experience or a run")
	game.end_delay=-1;game.change_screen("results");game.perform_action("home")
	check(game.data.ritual_pending.is_empty() and int(game.ritual_view.points)==66,"Menu starts the animated ritual with completed missions")
	game.data.wallet=9000;wallet=game.data.wallet
	check(game.buy_area(2) and game.data.wallet==wallet-2200 and game.buy_area(2) and game.data.wallet==wallet-2200,"Scene ownership charges once at updated price")
	wallet=game.data.wallet;check(game.buy_skin(1) and game.data.wallet==wallet-1000 and game.buy_skin(1) and game.data.wallet==wallet-1000,"Updated skin purchase charges once")
	game.start_run();game.capture_freeze=true;game.perform_action("pause")
	var frozen=game.runner.world_px;game._physics_process(.5)
	check(game.runner.world_px==frozen and game.screen=="pause","Mission pause truly freezes gameplay")
	game.perform_action("retry");game.capture_freeze=true
	check(game.screen=="run" and not game.runner.dead and game.runner.souls==0,"Pause restart starts a clean run")
	var legacy=game.validate_save({"version":3,"wallet":777,"best":1200,"levels":{"horde":3},"owned":[0,1,2],"skin":2,"areas":[0,1,2]})
	check(legacy.version==6 and legacy.wallet==777 and legacy.best==1200 and legacy.levels.horde==3 and legacy.owned==[0,1] and 2 in legacy.power_owned and legacy.areas==[0,1,2] and legacy.player_level==1,"Old purchases migrate into normal roster and power ownership without losing money or areas")
	var malformed=game.validate_save({"version":4,"player_level":0,"level_souls":9999,"ritual_progress":200,"ritual_pending":[{"key":"0:x","points":500},{"key":"0:x","points":1}]})
	check(malformed.player_level==1 and malformed.level_souls==19 and malformed.ritual_progress==99 and malformed.ritual_pending.size()==1 and malformed.ritual_pending[0].points==40,"Progression save bounds and queued missions sanitize")
	var path="user://horde-v5-test.json"
	game.data.level_souls=12;game.data.player_level=2;game.data.ritual_progress=45;game.data.best_souls=31
	check(game.save_game(path),"Atomic version-five save succeeds")
	var loaded=game.read_save(path)
	check(loaded.version==6 and loaded.level_souls==12 and loaded.player_level==2 and loaded.ritual_progress==45 and loaded.best_souls==31,"Levels, souls and ritual survive a disk round trip")
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(path+suffix)
	# Version five ownership: normal recruitment is separate from temporary powers.
	var fresh=isolated(4)
	var only_zombies=true
	for i in range(200):only_zombies=only_zombies and fresh.recruit_kind()==0
	check(only_zombies,"New players can only recruit zombies")
	fresh.owned=[0,1]
	var skeletons=0
	for i in range(1000):skeletons+=fresh.recruit_kind()
	check(skeletons>200 and skeletons<400,"Buying skeleton adds a mixed 30-percent conversion chance")
	game.data=MonsterCatalog.defaults();game.data.wallet=15000
	check(not game.buy_skin(2) and not game.buy_skin(3) and game.data.owned==[0],"Temporary powers cannot be purchased as normal monsters")
	check(not game.buy_power_upgrade(1),"Locked mask cannot receive upgrades")
	wallet=game.data.wallet
	check(game.buy_power(2) and game.buy_power(2) and game.data.wallet==wallet-2800,"Mask unlock is charged exactly once")
	for i in range(MonsterCatalog.POWER_UPGRADES.size()):check(game.buy_power_upgrade(i),"Independent power upgrade can be purchased: "+str(i))
	check(game.data.power_levels.mask_size==1 and game.data.power_levels.mask_revive==1 and not game.buy_power_upgrade(5),"Single-purchase power upgrades stop at their cap")
	game.buy_skin(1);game.start_run();game.capture_freeze=true
	check(game.runner.members[0].kind==0 and game.data.owned==[0,1],"Purchased skeleton never replaces the starting zombie")
	var locked=isolated();locked.grant_perk(2)
	check(locked.transform_left==0 and locked.perk_kind==-1,"A locked mask cannot activate")
	var morph=isolated(4);morph.power_levels={"fly_time":2};morph.add_entity("bomb",800)
	var before=morph.entities[0].x;morph.grant_perk(3);morph.jump();ticks(morph,120,true)
	check(morph.world_px>0 and morph.entities[0].x<before and morph.perk_left==0 and morph.members[0].y==HordeRun.FLOOR,"Transformation slows the moving course and protects the horde before starting its timer")
	ticks(morph,49)
	check(morph.transform_left==0 and morph.perk_kind==3 and morph.perk_left>13.9,"Fly duration upgrades start after the 2.8-second transformation")
	check(morph.recruit_kind() in [0,1],"Temporary transformations never permanently add power monsters to recruitment")
	var strong=isolated(2);strong.power_owned=[3,2];strong.power_levels={"mask_force":1,"mask_size":1,"mask_time":2,"mask_shield":1};strong.activate_perk(2)
	check(strong.member_force()==4 and strong.perk_left==14 and strong.shields==3,"Mask time, force, size and three-hit shield have separate effects")
	var heavy=strong.add_entity("bus",HordeRun.ANCHOR+float(MonsterCatalog.VEHICLES.bus.width)*.5+12)
	strong.advance(1.0/60)
	check(heavy.contacts.size()==1 and not heavy.taken and heavy.contacts.values()[0]==4,"Upgraded strength still waits for physical contact")
	ticks(strong,80);check(heavy.taken and strong.cars==1,"Two actually touching upgraded members can overturn a bus")
	for i in range(3):strong.hit_grace=0;strong.damage(0,"bullet")
	check(strong.shields==0 and strong.losses==0,"Purchased mask shield absorbs exactly three hits")
	strong.hit_grace=0;strong.damage(0,"bullet");check(strong.losses==1,"Mask is vulnerable after its shield is spent")
	var rescue=isolated(4);rescue.power_owned=[3,2];rescue.power_levels={"mask_revive":1,"mask_time":3};rescue.activate_perk(2)
	rescue.add_entity("gap",HordeRun.ANCHOR-250,HordeRun.FLOOR,0,850);ticks(rescue,45)
	check(not rescue.dead and rescue.active_count()==4 and rescue.revive_charges==0 and rescue.losses==0,"Purchased rescue restores the whole horde once without a forward teleport")
	rescue.entities.clear();rescue.add_entity("gap",HordeRun.ANCHOR-250,HordeRun.FLOOR,0,1800);ticks(rescue,210)
	check(rescue.dead and rescue.losses==4,"A second pit remains fatal after consuming the rescue charge")
	var constable=isolated(3);var police=constable.add_entity("police",HordeRun.ANCHOR+90);police.voice_wait=0;police.speaker=true
	constable.advance(1.0/60)
	var police_voice=false
	for e in constable.events:if e.type=="npc_voice" and e.npc=="police":police_voice=true
	check(police.vx<0 and police.pose=="police_run" and police_voice,"Running police emits its own STOP voice and carries its own rig")
	ticks(constable,100);check(police.taken and constable.soldiers==1 and constable.souls==1,"Police can be captured as one soul and an unlocked normal monster")
	var chopper=isolated();var rotor=chopper.add_entity("helicopter",HordeRun.ANCHOR+90,HordeRun.FLOOR-95)
	var body=chopper.members[0]
	body.y=rotor.y+106;check(not chopper.helicopter_front_hit(rotor,body),"Helicopter underside is safe")
	body.y=HordeRun.FLOOR;check(chopper.helicopter_front_hit(rotor,body),"Helicopter nose has a harmful frontal collision")
	body.x=rotor.x+70;check(not chopper.helicopter_front_hit(rotor,body),"Helicopter tail has no harmful collision")
	for name in ["smash_moto","smash_car","smash_bus","smash_truck","smash_tank","smash_plane","civil_male","civil_female","police_stop","army_command","helicopter_loop","engine_loop","fire_loop","transform_fly","revive"]:
		check(game.sound.clips.has(name) and game.sound.clips[name].get_length()>.1,"Version five sound is bundled: "+name)
	check(game.art.soul_frames.size()==6 and game.art.power_frames.size()==6 and game.art.fire_frames.size()==6 and game.art.damaged_vehicles.size()==6 and game.art.wreck_vehicles.size()==6,"New animation sheets have complete fixed-cell or measured atlases")
	check(game.art.soul(0)!=game.art.soul(.13) and game.art.power(3,0)!=game.art.power(3,.22),"Soul and cocoon animation advance across distinct frames")
	var slow=isolated();slow.world_px=240000;slow.speed=780;var phase=slow.members[0].run_phase;slow.advance(.1)
	check(slow.members[0].run_phase-phase<=.266,"Run cycle is capped below three cycles per second at maximum speed")
	var late=isolated(24);late.tunnels.clear();late.entered_tunnels=7;late.completed_tunnels=7;late.pressure=1;late.world_px=210000;late.speed=780
	var cursor=late.world_px+1000;var furthest_gap=cursor;var late_gaps=0;var max_gap_free=0.0;var illegal_double=false
	for i in range(100):
		late.entities.clear();late.world_px=cursor-1000
		cursor=HordeCourse.build(late,cursor,100+i)
		for e in late.entities:
			if e.kind=="gap":
				max_gap_free=maxf(max_gap_free,late.world_px+e.x-furthest_gap);furthest_gap=late.world_px+e.x+e.width;late_gaps+=1;illegal_double=illegal_double or e.double_jump
	print("HORDE_LATE_COURSE: holes=",late_gaps," longest_road_px=",max_gap_free," locked_double=",illegal_double)
	check(late_gaps>100 and max_gap_free<6500 and not illegal_double,"Late course keeps chained holes beyond 7000m; spaced threat clusters preserve opportunities to land between holes, without demanding an unowned double jump")
	late.levels.jump=2;late.entities.clear();late.world_px=210000;late.last_gap_world=0
	HordeCourse.build(late,late.world_px+HordeRun.ANCHOR+35,101)
	var gaps: Array=[]
	for e in late.entities:if e.kind=="gap":gaps.append(e)
	var landing_safe=true
	for i in range(1,gaps.size()):landing_safe=landing_safe and gaps[i].x-(gaps[i-1].x+gaps[i-1].width)>=285
	check(gaps.size()==3 and landing_safe,"Late chained holes leave visible, usable landing islands")
	var double_run=isolated(12);double_run.levels.jump=2;double_run.world_px=210000;double_run.speed=780;double_run.tunnels.clear();double_run.entered_tunnels=7
	double_run.add_entity("gap",HordeRun.ANCHOR+35,HordeRun.FLOOR,0,860);double_run.jump();ticks(double_run,27,true);double_run.jump();ticks(double_run,140,true)
	check(double_run.active_count()==12,"A timed double jump carries the entire horde over the longest allowed hole")
	var islands=isolated(24);islands.world_px=210000;islands.speed=780;islands.tunnels.clear();islands.entered_tunnels=7;islands.pressure=1
	for i in range(3):islands.add_entity("gap",HordeRun.ANCHOR+35+i*(410+500),HordeRun.FLOOR,0,410)
	var inputs=0
	for i in range(300):
		for e in islands.entities:
			if e.kind=="gap" and not e.get("input_used",false) and e.x<=HordeRun.ANCHOR+35:
				e.input_used=true;islands.jump();inputs+=1
		islands.advance(1.0/60,true)
	check(inputs==3 and islands.active_count()==24,"Three consecutive late holes can be crossed by a full horde with a landing and new jump on each island")
	game.data=MonsterCatalog.defaults();game.start_run();game.capture_freeze=true
	game.runner.grant_perk(3);game.consume_run_events();game.perform_action("pause")
	var morph_left=game.runner.transform_left;game._physics_process(.5)
	check(game.runner.transform_left==morph_left,"Pause freezes the transformation as well as the course")
	game.perform_action("resume");ticks(game.runner,169)
	check(game.runner.perk_kind==3,"Resuming continues and completes the transformation")
	var migration=game.validate_save({"version":4,"owned":[0,1,2,3],"levels":{"perk":2}})
	check(migration.owned==[0,1] and migration.power_owned.has(2) and migration.power_levels.fly_time==3 and migration.power_levels.mask_time==2 and migration.power_levels.mask_shield==0 and migration.power_levels.mask_revive==0,"Legacy paid powers and duration migrate without gifting shield or revive")
	game.effects.clear();game.effects.smash(Vector2(800,500),"car");game.effects.update(3,0)
	check(game.effects.wrecks.size()==1 and game.effects.wrecks[0].age==3 and absf(game.effects.wrecks[0].pos.y-(HordeRun.FLOOR-MonsterCatalog.VEHICLES.car.height*.44))<.1,"Burning wreck settles and persists past the old disappearance timer")
	game.effects.update(8,305);check(game.effects.wrecks.is_empty(),"Wreck is removed only after scrolling completely off camera")
	game.effects.clear()
	for i in range(350):game.effects.capture(Vector2(340,520),i%4);game.effects.soul(Vector2(340,520),Vector2(411,70))
	check(game.effects.particles.size()<=240,"Capture and soul effects respect the particle budget")
	game.effects.update(4,0);check(game.effects.particles.is_empty(),"Transient soul/capture effects clean themselves")
	var stress=HordeRun.new();stress.start({"horde":3,"jump":3,"magnet":3,"perk":3},42)
	for i in range(18000):
		if stress.dead:stress.start({"horde":3,"jump":3,"magnet":3,"perk":3},42+i)
		if i%29==0:stress.jump()
		stress.advance(1.0/60,true);stress.drain_events()
		if stress.entities.size()>160:check(false,"Long runner session cleans entities");break
	check(stress.members.size()<=24,"Long simulation respects the mobile horde cap")
	var rig_suite=load("res://tests/zombie_rig_test.gd").new();add_child(rig_suite);rig_suite.run(game);checks+=rig_suite.checks;failures.append_array(rig_suite.failures)
	var v7=load("res://tests/update_v7_test.gd").new();add_child(v7);v7.run(game);checks+=v7.checks;failures.append_array(v7.failures)
	var v6=load("res://tests/update_v6_test.gd").new();add_child(v6);v6.run(game);checks+=v6.checks;failures.append_array(v6.failures)
	if failures.is_empty():
		print("HORDE_TEST_OK: "+str(checks)+" checks; ownership and migration, power purchases/timers/force/shield/rescue, cinematic moving transformation, animated souls, police capture, frontal-only helicopter collision, late chained holes/double jumps, physical vehicle contacts/passengers/persistent wrecks, progression/ritual/economy, pit death/flight and long-run bounds")
		get_tree().quit(0)
	else:get_tree().quit(1)
