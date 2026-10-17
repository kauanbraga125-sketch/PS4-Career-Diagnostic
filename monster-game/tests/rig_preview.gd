extends SceneTree
class RigBoard extends Node2D:
	var art=HordeArt.new()
	var actor=HordeActor.new(art)
	var tick=0.0
	var debug_bones=false
	func _ready() -> void:
		actor.zombie.attach(self)
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("1b1329"))
		var names=["PARADO","CORRIDA 1","CORRIDA 2","SUBINDO","CAINDO","POUSANDO","EMPURRANDO","ESPELHADO"]
		var states=["idle","run","run","rise","fall","run","push","run"]
		for i in range(8):
			var x=160+(i%4)*320
			var y=320+(i/4)*350
			var phase=[0.0,.15,.65,.2,.6,.8,.3,.4][i]+tick
			var land=.10 if i==5 else 0.0
			var feet=Vector2(x-15,y)
			draw_line(Vector2(x-125,y),Vector2(x+125,y),Color("78677e"),1)
			actor.paint(self,0,feet,235,phase,states[i],tick,land,Color.WHITE,i==7)
			if debug_bones:
				var r=actor.zombie
				var mirror=-1.0 if i==7 else 1.0
				for id in r.bones:
					var bone=r.bones[id] as Bone2D
					var pos=feet+bone.global_position*Vector2(mirror,1)*235/r.MODEL_HEIGHT
					draw_circle(pos,2.2,Color.CYAN if id.begins_with("left") else Color.ORANGE)
					if bone.get_parent() is Bone2D:
						var parent=bone.get_parent() as Bone2D
						draw_line(pos,feet+parent.global_position*Vector2(mirror,1)*235/r.MODEL_HEIGHT,Color(.3,1,.7,.5),1)
			draw_string(art.title_font,Vector2(x-104,y-258),names[i],HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("ffcd73"))
		draw_string(art.body_font,Vector2(27,710),"Estrutura Bone2D: mesmo personagem em todas as poses",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("a2e4cf"))
var board: RigBoard
func _initialize() -> void:
	root.size=Vector2i(1280,720)
	board=RigBoard.new();root.add_child(board)
	call_deferred("capture")
func capture() -> void:
	var folder=OS.get_environment("HORDE_RIG_QA_PATH")
	if folder.is_empty():folder="/workspace/scratch/09b2746aad23/runtime/rig-qa"
	DirAccess.make_dir_recursive_absolute(folder)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/poses.png")
	board.debug_bones=true;board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/bones.png")
	board.debug_bones=false
	for i in range(48):
		board.tick=i/48.0;board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/motion-%03d.png"%i)
	print("RIG_PREVIEW_OK")
	quit()
