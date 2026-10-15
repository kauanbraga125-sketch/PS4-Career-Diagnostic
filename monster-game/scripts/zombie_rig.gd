class_name HordeZombieRig
extends RefCounted

# Bone2D hierarchy in model space. Drawing shares this skeleton between actors,
# while physics and each horde member's world-space foot remain in HordeRun.
const MODEL_HEIGHT=120.0
const THIGH=19.0
const SHIN=17.0
const UPPER_ARM=15.0
const FOREARM=13.0
const RIGHT_SHOULDER=Vector2(10.8,-15.2)
const LEFT_SHOULDER=Vector2(-10.8,-14.3)
var skeleton=Skeleton2D.new()
var bones: Dictionary={}
var textures: Dictionary={}
var bindings: Dictionary={}
var draw_order=["left_upper_arm","left_forearm","left_hand","left_thigh","left_shin","left_foot","right_thigh","right_shin","right_foot","pelvis","spine","right_upper_arm","right_forearm","right_hand","head"]

func _init(art: HordeArt) -> void:
	skeleton.name="ZombieSkeleton"
	add_bone("pelvis",skeleton,Vector2(0,-43),0)
	add_bone("spine",bones.pelvis,Vector2(0,-5),22)
	add_bone("head",bones.spine,Vector2(4,-22),0)
	for side in ["left","right"]:
		var near_side=side=="right"
		add_bone(side+"_upper_arm",bones.spine,RIGHT_SHOULDER if near_side else LEFT_SHOULDER,UPPER_ARM)
		add_bone(side+"_forearm",bones[side+"_upper_arm"],Vector2(0,UPPER_ARM),FOREARM)
		add_bone(side+"_hand",bones[side+"_forearm"],Vector2(0,FOREARM),0)
		add_bone(side+"_thigh",bones.pelvis,Vector2(5.2 if near_side else -5.2,0),THIGH)
		add_bone(side+"_shin",bones[side+"_thigh"],Vector2(0,THIGH),SHIN)
		add_bone(side+"_foot",bones[side+"_shin"],Vector2(0,SHIN),0)
	# The shirt and pelvis have their own anchors. The shorts belong to the
	# pelvis, covering the clothing at the tops of both thighs in every pose.
	var sheet=art.rigs[0][1].atlas
	textures.spine=HordeArt.atlas(sheet,[507,119,280,230])
	textures.pelvis=HordeArt.atlas(sheet,[548,314,227,97])
	bindings.spine=segment_transform(Vector2(141,210),Vector2(141,27),Vector2(0,-21.24))
	bindings.pelvis=fixed_transform(Vector2(102,37),27.0/227.0)
	textures.head=art.rigs[0][0]
	bindings.head=fixed_transform(Vector2(187,361),50.0/394.0)
	var cleaned=load("res://assets/art/rig-zombie-v71.png") as Texture2D
	var layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/zombie-rig-v71.json"))
	var limbs: Array=[]
	for region in layout.parts:limbs.append(HordeArt.atlas(cleaned,region))
	for side in ["left","right"]:
		var mirror=-1.0 if side=="left" else 1.0
		textures[side+"_upper_arm"]=limbs[2]
		textures[side+"_forearm"]=limbs[3]
		textures[side+"_hand"]=limbs[4]
		textures[side+"_thigh"]=limbs[5]
		textures[side+"_shin"]=limbs[6]
		textures[side+"_foot"]=art.rigs[0][7]
		bindings[side+"_upper_arm"]=segment_transform(Vector2(83,32),Vector2(87,270),Vector2(0,UPPER_ARM),mirror)
		bindings[side+"_forearm"]=segment_transform(Vector2(70,40),Vector2(58,251),Vector2(0,FOREARM),mirror)
		bindings[side+"_hand"]=fixed_transform(Vector2(76,28),.052,mirror)
		bindings[side+"_thigh"]=segment_transform(Vector2(88,38),Vector2(95,264),Vector2(0,THIGH))
		bindings[side+"_shin"]=segment_transform(Vector2(75,33),Vector2(65,274),Vector2(0,SHIN))
		bindings[side+"_foot"]=fixed_transform(Vector2(101,24),.073 if side=="right" else .069)
	pose(0,"idle",0)

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE and is_instance_valid(skeleton):skeleton.free()

func attach(owner_node: Node) -> void:
	if skeleton.is_inside_tree():return
	# Bone2D needs the scene tree to invalidate descendant transforms when a
	# parent moves. This hidden, top-level skeleton stays in model coordinates.
	skeleton.top_level=true
	skeleton.visible=false
	owner_node.add_child(skeleton)

func add_bone(id: String,parent: Node2D,at: Vector2,length: float) -> void:
	var bone=Bone2D.new()
	bone.name=id;bone.set_autocalculate_length_and_angle(false)
	bone.position=at;bone.set_length(length);bone.set_bone_angle(PI*.5)
	bone.rest=bone.transform
	parent.add_child(bone);bones[id]=bone

static func fixed_transform(anchor: Vector2,scale: float,mirror: float=1.0) -> Transform2D:
	var x=Vector2(scale*mirror,0);var y=Vector2(0,scale)
	return Transform2D(x,y,-x*anchor.x-y*anchor.y)

static func segment_transform(start: Vector2,end: Vector2,target: Vector2,mirror: float=1.0) -> Transform2D:
	var source=(end-start).normalized();var normal=Vector2(source.y,-source.x)
	var along=target.normalized();var across=Vector2(along.y,-along.x)
	var scale=target.length()/start.distance_to(end)
	var x=(across*normal.x*mirror+along*source.x)*scale
	var y=(across*normal.y*mirror+along*source.y)*scale
	return Transform2D(x,y,-x*start.x-y*start.y)

static func stride(phase: float,side: String) -> Vector2:
	var raw=HordeActor.stride_foot(phase)
	return Vector2(raw.x*.63+(3.2 if side=="right" else -3.2),(-13.65 if side=="right" else -12.9)+(raw.y+4)*.78)

func solve_leg(side: String,target: Vector2,foot_angle: float=0) -> void:
	var thigh=bones[side+"_thigh"] as Bone2D
	var shin=bones[side+"_shin"] as Bone2D
	var foot=bones[side+"_foot"] as Bone2D
	var hip=thigh.global_position
	var delta=target-hip
	var distance=clampf(delta.length(),2.01,THIGH+SHIN-.01)
	var direction=delta.normalized()
	var along=(THIGH*THIGH-SHIN*SHIN+distance*distance)/(2*distance)
	var bend=sqrt(maxf(0,THIGH*THIGH-along*along))
	var knee=hip+direction*along+Vector2(direction.y,-direction.x)*bend
	var ankle=hip+direction*distance
	thigh.rotation=(knee-hip).angle()-PI*.5-bones.pelvis.global_rotation
	shin.rotation=(ankle-knee).angle()-(knee-hip).angle()
	foot.rotation=foot_angle-shin.global_rotation

func pose(phase: float,state: String,time: float,landing: float=0,pose_mix: float=1.0) -> void:
	bones.head.position=Vector2(4,-22)
	var running=state in ["run","panic_run","police_run","capture"]
	var wave=sin(phase*TAU)
	var arm_wave=cos(phase*TAU)
	var bob=absf(wave)*2.1 if running else sin(time*2.8)*.65
	var compression=sin(clampf(landing/.20,0,1)*PI)*4.5
	bones.pelvis.position=Vector2(-1+wave*.6 if running else -1,-43+bob+compression)
	bones.pelvis.rotation=wave*.025 if running else sin(time*1.8)*.01
	bones.spine.rotation=.105+wave*.025 if running else .015+sin(time*2.1)*.015
	bones.head.rotation=-bones.spine.rotation*.65+sin(time*3)*.025
	var right_angle=-.30+arm_wave*.80 if running else -.35+sin(time*2.4)*.06
	var left_angle=-.30-arm_wave*.80 if running else .32+sin(time*2.4+1)*.06
	var right_bend=-1.22+cos(phase*TAU)*.10 if running else -1.18
	var left_bend=-1.22-cos(phase*TAU)*.10 if running else -.12
	var right_foot=stride(phase,"right") if running else Vector2(12,-13.65)
	var left_foot=stride(phase+.5,"left") if running else Vector2(-12,-12.9)
	if state in ["rise","fly"]:
		bones.pelvis.position.y=-43;bones.spine.rotation=.16
		right_foot=right_foot.lerp(Vector2(21,-29),pose_mix)
		left_foot=left_foot.lerp(Vector2(-18,-23),pose_mix)
		right_angle=lerpf(right_angle,-1.35,pose_mix);right_bend=lerpf(right_bend,-.55,pose_mix)
		left_angle=lerpf(left_angle,.58,pose_mix);left_bend=lerpf(left_bend,-1.10,pose_mix)
	elif state=="fall":
		bones.spine.rotation=.06
		right_foot=right_foot.lerp(Vector2(15,-16),pose_mix);left_foot=left_foot.lerp(Vector2(-13,-14),pose_mix)
		right_angle=lerpf(right_angle,-.80,pose_mix);left_angle=lerpf(left_angle,.32,pose_mix)
		right_bend=-.95;left_bend=-.45
	elif state=="push":
		bones.spine.rotation=.24;right_angle=-1.40;left_angle=-1.50;right_bend=-.20;left_bend=-.20
		right_foot=Vector2(18,-13.65);left_foot=Vector2(-17,-12.9)
	elif state in ["panic","panic_run"]:
		right_angle=-2.15+sin(time*12)*.18;left_angle=1.9+cos(time*12)*.18;right_bend=-.65;left_bend=.65
	elif state=="capture":
		var reach=sin(phase*PI)
		bones.spine.rotation=.10+reach*.26
		right_angle=-1.48;left_angle=-1.20;right_bend=-.35;left_bend=-.60
		bones.head.position=Vector2(4+reach*2,-22)
	bones.head.rotation=-bones.spine.rotation*.65+sin(time*3)*.025
	bones.right_upper_arm.rotation=right_angle;bones.left_upper_arm.rotation=left_angle
	bones.right_forearm.rotation=right_bend;bones.left_forearm.rotation=left_bend
	bones.right_hand.rotation=.12;bones.left_hand.rotation=.12
	solve_leg("left",left_foot)
	solve_leg("right",right_foot,-.12*pose_mix if state=="rise" else 0)

func paint(canvas: Node2D,foot: Vector2,height: float,phase: float,state: String,time: float,landing: float,tint: Color,reverse: bool,pose_mix: float) -> void:
	pose(phase,state,time,landing,pose_mix)
	var scale=height/MODEL_HEIGHT
	var root=Transform2D(Vector2(-scale if reverse else scale,0),Vector2(0,scale),foot)
	for id in draw_order:
		var bone=bones[id] as Bone2D
		var shade=tint*Color(.79,.82,.88,1) if id.begins_with("left_") else tint
		canvas.draw_set_transform_matrix(root*bone.global_transform*bindings[id])
		canvas.draw_texture(textures[id],Vector2.ZERO,shade)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
