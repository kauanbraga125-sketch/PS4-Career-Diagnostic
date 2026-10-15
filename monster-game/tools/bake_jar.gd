extends SceneTree
func _initialize() -> void:call_deferred("bake")
func bake() -> void:
	var viewport=SubViewport.new();viewport.size=Vector2i(256,320);viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var canvas=Node2D.new();viewport.add_child(canvas)
	var jar=HordeSoulJar.new();var state={"fill":0.0}
	canvas.draw.connect(func():jar.paint_state(canvas,state.fill))
	var atlas=Image.create(2048,2560,false,Image.FORMAT_RGBA8);atlas.fill(Color.TRANSPARENT)
	for i in range(61):
		state.fill=float(i)/60;canvas.queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
		var frame=viewport.get_texture().get_image()
		atlas.blit_rect(frame,Rect2i(0,0,256,320),Vector2i((i%8)*256,(i/8)*320))
	var error=atlas.save_png("res://assets/art/soul-jar-states-v7.png")
	print("HORDE_JAR_BAKE_OK 61 states ",error);quit(error)
