extends Node
var checks=0
var failures: Array[String]=[]

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);push_error("HORDE_MENU_FAIL: "+message)

func touch(g,action: String) -> void:
	var found=false
	for button in g.buttons.duplicate():
		if button.action!=action:continue
		var event=InputEventScreenTouch.new();event.index=11;event.position=g.to_global(button.rect.get_center());event.pressed=true;g._input(event)
		event.pressed=false;g._input(event);found=true;break
	check(found,"Touchable control: "+action)

func bounds(g) -> void:
	for button in g.buttons:check(g.full_rect().encloses(button.rect),"Button remains on screen: "+str(button.action))

func run(g) -> void:
	g.capture_freeze=true;g.sound.set_enabled(false)
	var folder=OS.get_environment("HORDE_MENU_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(folder)
	for size in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=size
		g.data=MonsterCatalog.defaults();g.data.wallet=6000;g.data.ritual_progress=66;g.ui_time=1
		g.change_screen("home");await get_tree().create_timer(.15).timeout
		await g.capture_frame(folder+"/home-"+str(size.x)+"x"+str(size.y)+".png")
		check(g.buttons.size()==6,"Three shortcuts, play, settings and help");bounds(g)
		for action in ["market","collection","missions","settings","help"]:
			touch(g,action)
			await g.capture_frame(folder+"/"+action+"-"+str(size.x)+"x"+str(size.y)+".png")
			check(g.screen==action,"Home opens "+action);bounds(g)
			if action=="market":
				for tab in range(4):
					touch(g,"market_tab_"+str(tab));await g.capture_frame(folder+"/market-tab-"+str(tab)+"-"+str(size.x)+".png")
					var items=g.market.items(g.data);touch(g,"market_select_"+items[0].key);g.market.update(.3)
					await g.capture_frame(folder+"/market-expanded-"+str(tab)+"-"+str(size.x)+".png");bounds(g)
					check(float(g.market.expanded[items[0].key])==1,"Selected row expands fully")
					if tab==2:
						touch(g,"market_next");await g.capture_frame(folder+"/market-powers-page2-"+str(size.x)+".png");check(g.market.page==1,"Power upgrades paginate")
			if action=="settings":
				var before=g.data.audio_levels.voices
				touch(g,"mix_minus_voices");check(g.data.audio_levels.voices<before and g.data.audio_levels.music==.75,"Voice volume changes independently")
				var press=InputEventScreenTouch.new();press.index=15;press.position=g.to_global(Vector2(657,242));press.pressed=true;g._input(press)
				var drag=InputEventScreenDrag.new();drag.index=15;drag.position=g.to_global(Vector2(903,242));g._input(drag)
				press.pressed=false;g._input(press)
				check(is_equal_approx(g.data.audio_levels.music,1.0) and g.slider_channel.is_empty(),"Native drag adjusts slider and releases cleanly")
			g.perform_action("back");await g.capture_frame(folder+"/.routing.png")
		# Buy through the actual expanded market row, then inspect the live crowd.
		touch(g,"market");await g.capture_frame(folder+"/.routing.png")
		touch(g,"market_tab_1");await g.capture_frame(folder+"/.routing.png")
		touch(g,"market_select_monster1");g.market.update(.3);await g.capture_frame(folder+"/.routing.png")
		touch(g,"skin_1");check(1 in g.data.owned and g.data.wallet==5000,"Expanded purchase unlocks the skeleton at its real price")
		g.perform_action("back");await g.capture_frame(folder+"/home-unlocked-"+str(size.x)+".png")
		touch(g,"play");check(g.screen=="run" and g.runner.members[0].kind==0,"Play starts with a zombie after buying skeleton")
		g.perform_action("pause");await g.capture_frame(folder+"/.routing.png")
		touch(g,"settings");await g.capture_frame(folder+"/.routing.png");touch(g,"back")
		check(g.screen=="pause","Settings returns to pause without resuming simulation")
		g.perform_action("home");await g.capture_frame(folder+"/.routing.png")
	get_window().size=Vector2i(1280,720);await get_tree().create_timer(.15).timeout
	g.data=MonsterCatalog.defaults();g.change_screen("home");g.ui_time=1
	await g.capture_frame(folder+"/ritual-a.png")
	g.ui_time=1.47;await g.capture_frame(folder+"/ritual-b.png")
	var first=Image.load_from_file(folder+"/ritual-a.png");var second=Image.load_from_file(folder+"/ritual-b.png")
	var d=g.home_menu.layout(g.full_rect())
	var region=Rect2i(d.altar-Vector2(d.altar_height*.20,d.altar_height*.23),Vector2(d.altar_height*.4,d.altar_height*.12))
	check(first.get_region(region).get_data()!=second.get_region(region).get_data(),"Liquid itself visibly moves between frames")
	g.data.owned=[0,1];g.data.power_owned=[3,2];g.data.ritual_progress=70
	g.preview_course(22300,6);g.runner.grant_perk(3);g.runner.add_entity("bomb",1400);g.runner.add_entity("gap",1800,HordeRun.FLOOR,0,240)
	var motion=folder+"/motion";DirAccess.make_dir_recursive_absolute(motion)
	for frame in range(180):
		g.capture_freeze=false;g._physics_process(1.0/30);g._process(1.0/30);g.capture_freeze=true
		await g.capture_frame(motion+"/frame-%04d.png"%frame)
	check(g.runner.world_px>22300 and g.runner.perk_kind==3 and g.runner.losses==0,"Native motion shows a moving cinematic transformation and safe flight")
	print("HORDE_MENU_OK: ",checks," native checks; three aspect ratios, market rows/purchases, collection, independent sliders, animated liquid and 180 rendered cinematic frames")
	get_tree().quit(0 if failures.is_empty() else 1)
