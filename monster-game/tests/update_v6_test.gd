extends Node
var checks=0
var failures: Array[String]=[]

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);push_error("HORDE_V6_FAIL: "+message)

func isolated(count: int=1) -> HordeRun:
	var r=HordeRun.new();r.start(MonsterCatalog.defaults().levels,6014)
	r.entities.clear();r.events.clear();r.tunnels.clear();r.next_segment=99999
	for i in range(count-1):r.add_member(0,false)
	return r

func run(g) -> void:
	var r=isolated(4);r.entered_tunnels=1;r.grant_perk(3)
	check(r.next_power_tunnel==4,"Collecting in tunnel 1 schedules eligibility for tunnel 4")
	r.transform_left=0;r.perk_left=0
	for tunnel in [2,3]:
		r.entered_tunnels=tunnel
		check(not r.power_eligible() and not r.try_spawn_power(1200),"No power can bypass cooldown in tunnel "+str(tunnel))
	r.entered_tunnels=4
	check(r.power_eligible(),"Tunnel 4 restores eligibility")
	var offered=0
	for i in range(200):
		r.entities.clear()
		if r.try_spawn_power(1200):offered+=1
	check(offered>15 and offered<90,"Eligible powers still use a random roll rather than a guaranteed tunnel spawn")
	r=isolated(6);r.add_entity("bomb",1000);r.grant_perk(3)
	for i in range(120):r.advance(1.0/60)
	check(r.world_px>80 and r.entities[0].x<920 and r.losses==0 and r.perk_left==0,"Metamorphosis moves the road slowly, protects members and delays the power timer")
	for i in range(60):r.advance(1.0/60)
	check(r.perk_kind==3 and r.perk_left>7 and r.time_scale>.22 and r.time_scale<.86,"Flight accelerates smoothly from the cinematic slowdown")
	r.perk_left=.01
	for i in range(100):r.advance(1.0/60)
	check(r.perk_kind==-1 and is_equal_approx(r.time_scale,1.0),"Power end smoothly restores ordinary road speed")
	var civilians=isolated();civilians.add_entity("gap",500,HordeRun.FLOOR,0,300)
	civilians.spawn_civilians(540,3,1)
	var safe=true
	for e in civilians.entities:
		if e.kind=="civilian":safe=safe and civilians.civilian_floor_safe(e.x,34)
	check(safe,"Civilian group footprint is shifted off a pit at spawn")
	var left=civilians.add_entity("civilian",445);left.vx=110
	var right=civilians.add_entity("civilian",865);right.vx=-110
	for i in range(600):
		for e in [left,right]:e.x+=e.vx/60.0
		civilians.update_civilians(1.0/60)
		safe=safe and civilians.civilian_floor_safe(left.x) and civilians.civilian_floor_safe(right.x) and left.y<=HordeRun.FLOOR and right.y<=HordeRun.FLOOR
	check(safe,"Civilians approaching either edge turn away throughout ten seconds of motion")
	var groups=isolated();groups.world_px=10000;groups.spawn_civilians(1000,3,40)
	groups.world_px=12000;groups.spawn_civilians(500,3,41)
	groups.world_px=14500;groups.spawn_civilians(1000,3,42)
	var sizes={}
	for e in groups.entities:
		if e.kind=="civilian":sizes[e.group]=int(sizes.get(e.group,0))+1
	check(sizes.get(40)==3 and sizes.get(41)==1 and sizes.get(42)==3,"Triple groups are at least 100 metres apart; nearby recovery uses a single civilian")
	var boundary=isolated();boundary.schedule_tunnel(1,18000);boundary.world_px=16500
	boundary.spawn_civilians(1100,3,100)
	var boundary_count=0
	for entity in boundary.entities:
		if entity.kind=="civilian":boundary_count+=1
	check(boundary_count in [0,3],"A tunnel boundary never splits a group into two civilians")
	var fresh=HordeRun.new();fresh.start(MonsterCatalog.defaults().levels,77)
	var initial=0
	for e in fresh.entities:
		if e.kind=="civilian":initial+=1
	check(initial==1,"Opening introduces one civilian instead of an immediate group of three")
	var apex=[];var air=[]
	for held in [false,true]:
		var jump=isolated();jump.jump();var height=0.0;var frames=0
		for i in range(140):
			jump.advance(1.0/60,held or i<3)
			height=maxf(height,HordeRun.FLOOR-float(jump.members[0].y))
			if jump.members[0].y<HordeRun.FLOOR:frames+=1
		apex.append(height);air.append(frames)
	check(apex[1]>apex[0]+40 and air[1]>air[0]+12,"Holding gives both a taller jump and a longer descent than a short tap")
	var crash=isolated(12);crash.spawn_rushing_car(HordeRun.ANCHOR+180,1)
	for i in range(100):crash.advance(1.0/60)
	check(crash.losses==1 and crash.active_count()==11,"One oncoming car removes one member across its entire horde contact")
	var dodge=isolated(24);dodge.spawn_rushing_car(HordeRun.ANCHOR+315,2);dodge.jump()
	for i in range(120):dodge.advance(1.0/60,true)
	check(not dodge.dead and dodge.losses<=1,"One oncoming car causes at most one loss while the horde follows a spatial jump wave")
	var warning=isolated(4);warning.spawn_rushing_car(1500,3)
	warning.advance(.01)
	var warned=false
	for e in warning.events:
		if e.type=="car_warning":warned=true
	check(warned,"A fast car gets an audible warning before reaching the horde")
	var speaker=isolated();speaker.speed=780;speaker.add_entity("civilian",1800).speaker=true
	speaker.advance(.01)
	check(speaker.speech_left>=2.9 and not speaker.speech_text.is_empty(),"High-speed NPC speech starts in advance and gets at least three seconds")
	var first=speaker.speech_text;speaker.add_entity("police",900);speaker.advance(.1)
	check(speaker.speech_text==first,"A second NPC cannot overwrite an active speech balloon")
	check(g.home_menu.formation([0]).size()==1 and g.home_menu.formation([0])[0].kind==0,"Fresh menu displays only the unlocked zombie")
	var crowd=g.home_menu.formation([0,1]);var back=false;var front=false
	for person in crowd:
		back=back or person.depth<0;front=front or person.depth==0
		check(person.kind in [0,1],"Crowd never treats temporary powers as permanent monsters")
	check(crowd.size()>2 and back and front,"Unlocked collection uses front and back crowd layers")
	for tab in range(4):
		g.market.open(tab)
		for item in g.market.items(MonsterCatalog.defaults()):check(item.price>=0 and item.has("description") and item.has("illustration") and item.has("action"),"Market item has illustration, description, price and purchase action: "+item.key)
	g.data=MonsterCatalog.defaults();g.data.wallet=912;g.data.audio_levels={"music":.2,"effects":.4,"voices":.8}
	var loaded=g.validate_save(g.data)
	check(loaded.wallet==912 and loaded.audio_levels==g.data.audio_levels and loaded.version==6,"Independent mixer levels survive save validation with progress")
	var migrated=g.validate_save({"version":5,"wallet":1200,"owned":[0,1],"power_owned":[2,3]})
	check(migrated.wallet==1200 and migrated.owned==[0,1] and migrated.audio_levels.voices==1.0,"Version-five saves migrate without resetting purchases")
	check(AudioServer.get_bus_effect_count(0)>0,"Final mix has a peak limiter for simultaneous effects")
	g.sound.set_mix(g.data.audio_levels)
	check(g.sound.mix_levels==g.data.audio_levels,"Music, effects and voice controls reach separate mix buses")
	g.sound.set_music("moon_menu");g.sound._process(1.1);g.sound.set_music("midnight_run");g.sound._process(.4)
	check(g.sound.music_weights[0]>0 and g.sound.music_weights[1]>0,"Music transition overlaps two streams instead of cutting abruptly")
	g.sound.duck_left=.5;g.sound._process(.1)
	check(g.sound.duck_db< -3,"An important impact lowers the music audibly")
	for clip in ["car_horn","car_crash","car_approach_1","car_approach_2","voice_fly","death_zombie","fly_wings_loop","cauldron_loop","music_menu_v6","music_early_v6","music_late_v6","civil_new_4","zombie_chuckle_4"]:
		check(g.sound.clips.has(clip) and g.sound.clips[clip].get_length()>.1,"Prepared supplied/simmer audio is loaded: "+clip)
	g.data=MonsterCatalog.defaults();g.sound.set_enabled(false);g.sound.set_mix(g.data.audio_levels)
	print("HORDE_V6_CHECKS: ",checks)
