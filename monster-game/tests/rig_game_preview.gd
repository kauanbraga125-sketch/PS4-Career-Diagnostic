extends Node
var out="/workspace/scratch/09b2746aad23/runtime/rig-game-qa"
func shot(g,name: String) -> void:
	g.configure_layout();g.queue_redraw();g.world_canvas.queue_redraw();g.foreground_canvas.queue_redraw()
	await get_tree().process_frame
	await g.capture_frame(out+"/"+name+".png")
func run(g) -> void:
	var requested=OS.get_environment("HORDE_RIG_GAME_PATH")
	if not requested.is_empty():out=requested
	DirAccess.make_dir_recursive_absolute(out)
	g.capture_freeze=true;g.sound.set_enabled(false);g.data=MonsterCatalog.defaults();g.data.wallet=2582;g.ui_time=1.0
	await shot(g,"menu")
	# All frames use the actual menu or runner drawing paths, not a mock-up.
	for i in range(24):
		g.ui_time=1+i/12.0;await shot(g,"frame-%03d"%i)
	g.preview_course(0,3)
	for i in range(72):
		if i in [12,48]:g.runner.jump()
		var held=(i>=12 and i<22) or i==48
		if i in [22,49]:g.runner.release_jump()
		g.preview_ticks(5,held)
		await shot(g,"frame-%03d"%(i+24))
		if i in [6,16,24,34,57]:await shot(g,"run-%03d"%i)
	g.change_screen("collection");await shot(g,"collection")
	g.change_screen("pause");await shot(g,"pause")
	print("HORDE_RIG_GAME_PREVIEW_OK")
	get_tree().quit()
