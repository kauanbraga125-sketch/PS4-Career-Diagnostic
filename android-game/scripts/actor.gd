class_name StreetActor
extends Node3D

var skeleton: Skeleton3D
var animator: AnimationPlayer
var hand: BoneAttachment3D
var clips: Dictionary = {}
var state = ""
var landing_left = 0.0
var dead = false

func setup(style: int) -> void:
	var model = StreetModels.imported("person_%d" % posmod(style,4))
	# MakeHuman faces -Y in Blender, which exports to +Z in glTF.
	model.rotation.y = PI
	add_child(model)
	skeleton = find_type(model,"Skeleton3D") as Skeleton3D
	animator = find_type(model,"AnimationPlayer") as AnimationPlayer
	assert(skeleton and animator,"Realism pack must include rigged, animated characters")
	for clip in animator.get_animation_list():
		for label in ["idle","walk","run","jump","fall","land","death","riding","aim"]:
			if String(clip).ends_with(label):
				clips[label] = clip
				if label in ["idle","walk","run","fall","riding","aim"]:
					animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	hand = BoneAttachment3D.new()
	hand.bone_name = "RightHand"
	skeleton.add_child(hand)
	play_state("idle")

static func find_type(root: Node,type: String) -> Node:
	if root.is_class(type): return root
	for child in root.get_children():
		var result = find_type(child,type)
		if result: return result
	return null

func play_state(next: String,rate: float = 1.0) -> void:
	if not clips.has(next): return
	if state!=next:
		state = next
		animator.play(clips[next],0.16,1.0)
	animator.speed_scale = rate

func move_pose(speed: float,grounded: bool,vertical_speed: float,aiming: bool,dt: float,landed: bool = false) -> void:
	if dead: return
	if landed: landing_left = 0.32
	landing_left = maxf(0,landing_left-dt)
	if not grounded:
		play_state("jump" if vertical_speed>0.4 else "fall")
	elif landing_left>0:
		play_state("land")
	elif aiming:
		play_state("aim")
	elif speed>4.5:
		play_state("run",clampf(speed/6.5,0.75,1.3))
	elif speed>0.15:
		play_state("walk",clampf(speed/2.7,0.55,1.65))
	else:
		play_state("idle")

func mount_pose() -> void:
	play_state("riding")

func death_pose() -> void:
	dead = true
	play_state("death")

func attach_weapon(weapon: Node3D) -> void:
	hand.add_child(weapon)
	weapon.position = Vector3(0,-0.025,0.055)
	weapon.rotation_degrees = Vector3(-90,0,0)
