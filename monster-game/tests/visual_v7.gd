extends Node
var out=OS.get_environment("HORDE_V7_QA_PATH")
func _ready() -> void:
	if out.is_empty():out=OS.get_user_data_dir()+"/qa-v7"
var checks=0
func shot(g,name: String) -> void:
	g.configure_layout();g.queue_redraw();g.market_canvas.queue_redraw()
	await get_tree().process_frame
	await g.capture_frame(out+"/"+name+".png")
func run(g) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	g.capture_freeze=true;g.sound.set_enabled(false);g.data=MonsterCatalog.defaults();g.data.wallet=3190;g.ui_time=1.2
	await shot(g,"home")
	g.perform_action("collection");await shot(g,"collection")
	g.perform_action("missions");await shot(g,"missions")
	g.open_market(0);await shot(g,"market")
	g.market.select("upgrade0");g.market.update(.2);await shot(g,"market-expanded")
	g.market.open(3);await shot(g,"scenarios")
	g.market.scroll_by(90);await shot(g,"scenarios-scroll")
	g.market.open(2);await shot(g,"powers")
	var touch=InputEventScreenTouch.new();touch.index=10;touch.position=Vector2(815,500)+g.layout_origin;touch.pressed=true;g._input(touch)
	var drag=InputEventScreenDrag.new();drag.index=10;drag.position=Vector2(815,280)+g.layout_origin;g._input(drag)
	touch.pressed=false;touch.position=drag.position;g._input(touch)
	assert(g.market.scroll>100 and g.market.selected.is_empty());checks+=1
	await shot(g,"powers-scroll")
	g.settings_from="home";g.change_screen("settings");await shot(g,"settings")
	g.preview_course(12000,4);g.runner.entities.clear();g.runner.add_entity("bus",810);g.runner.add_entity("moto",1170);await shot(g,"bus-and-rider")
	g.runner.entities.clear();var car=g.runner.add_entity("car",840);await shot(g,"car-passenger")
	g.runner.entities.clear();g.runner.npc_serial=14;var npc=g.runner.add_entity("civilian",700);npc.spoke=true;npc.speech_left=2;await shot(g,"npc-bubble")
	g.runner.npc_serial=0;g.runner.entities.clear();g.runner.add_entity("gap",680,HordeRun.FLOOR,0,320);g.runner.add_entity("hump",1150);await shot(g,"terrain")
	g.change_screen("pause");await shot(g,"pause")
	var before=g.runner.world_px;g._physics_process(.5);assert(g.runner.world_px==before);checks+=1
	g.runner.souls=26;g.runner.coins=134;g.runner.cars=6;g.run_report={"old_level":2,"old_progress":27,"levels":1,"coins":256};g.data.player_level=3;g.data.level_souls=17;g.data.best_souls=31;g.data.best=1350
	g.change_screen("results")
	for fill_time in [.25,1.1,2.0,4.7]:
		g.result_time=fill_time
		await shot(g,"results-"+str(fill_time).replace(".","-"))
	# Verify safe-area layout in a wide phone and a tablet.
	for size in [Vector2i(1560,720),Vector2i(1280,960)]:
		get_window().size=size
		await get_tree().process_frame;await get_tree().process_frame
		g.change_screen("home");await shot(g,"home-"+str(size.x))
		g.change_screen("pause");await shot(g,"pause-"+str(size.x))
	print("HORDE_V7_VISUAL_OK ",checks," touch/pause checks; 24 captures")
	get_tree().quit(0)
