extends SceneTree
class Body extends Node2D:
	var art=HordeArt.new()
	var actor=HordeActor.new(art)
	var phase=0.0
	var state="idle"
	func _ready() -> void:actor.zombie.attach(self)
	func _draw() -> void:actor.paint(self,0,Vector2(125,310),295,phase,state,phase,.1 if state=="run" else 0)
func _initialize() -> void:call_deferred("capture")
func capture() -> void:
	var view=SubViewport.new();view.size=Vector2i(300,330);view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var body=Body.new();view.add_child(body)
	var out=OS.get_environment("HORDE_ALPHA_QA_PATH")
	if out.is_empty():out="/workspace/scratch/09b2746aad23/runtime/rig-alpha-qa"
	DirAccess.make_dir_recursive_absolute(out)
	for state in ["idle","run","rise","fall","push","capture"]:
		for i in range(4):
			body.state=state;body.phase=i/4.0;body.queue_redraw()
			await process_frame;await RenderingServer.frame_post_draw
			view.get_texture().get_image().save_png(out+"/"+state+"-%d.png"%i)
	print("HORDE_ALPHA_PREVIEW_OK")
	quit()
