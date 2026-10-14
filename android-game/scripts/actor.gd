class_name StreetActor
extends Node3D

var skeleton: Skeleton3D
var animator: AnimationPlayer
var hand: BoneAttachment3D
var clips: Dictionary={}
var state=""
var landing_left=0.0
var dead=false
var weapon_anchor: Node3D
var right_target: Node3D
var left_target: Node3D
var right_ik: SkeletonIK3D
var left_ik: SkeletonIK3D
var simulator: PhysicalBoneSimulator3D
var aiming=false
var aim_pitch=0.0
var has_weapon=false
var weapon_kind=0

func setup(style: int) -> void:
	var model=StreetModels.imported("person_%d" % posmod(style,4))
	model.rotation.y=PI
	add_child(model)
	skeleton=find_type(model,"Skeleton3D") as Skeleton3D
	animator=find_type(model,"AnimationPlayer") as AnimationPlayer
	assert(skeleton and animator,"Character pack must include rigged animations")
	for clip in animator.get_animation_list():
		for label in ["idle","walk","run","jump","fall","land","death","riding","aim"]:
			if String(clip).ends_with(label):
				clips[label]=clip
				if label in ["idle","walk","run","fall","riding","aim"]: animator.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	hand=BoneAttachment3D.new()
	hand.bone_name="RightHand"
	skeleton.add_child(hand)
	weapon_anchor=Node3D.new()
	weapon_anchor.name="WeaponGrip"
	weapon_anchor.position=Vector3(.29,.93,-.12)
	add_child(weapon_anchor)
	right_target=Node3D.new()
	left_target=Node3D.new()
	weapon_anchor.add_child(right_target)
	weapon_anchor.add_child(left_target)
	right_target.position=Vector3(0,-.035,.015)
	left_target.position=Vector3(-.045,-.04,-.24)
	play_state("idle")

func _ready() -> void:
	for side in ["Right","Left"]:
		var ik=SkeletonIK3D.new()
		ik.root_bone=side+"Arm"
		ik.tip_bone=side+"Hand"
		ik.override_tip_basis=false
		ik.max_iterations=12
		ik.influence=0
		skeleton.add_child(ik)
		ik.target_node=ik.get_path_to(right_target if side=="Right" else left_target)
		ik.start()
		if side=="Right": right_ik=ik
		else: left_ik=ik

static func find_type(root: Node,type: String) -> Node:
	if root.is_class(type): return root
	for child in root.get_children():
		var result=find_type(child,type)
		if result: return result
	return null

func _process(dt: float) -> void:
	if dead or not right_ik: return
	var blend=minf(dt*12,1)
	var raised=has_weapon and aiming
	weapon_anchor.position=weapon_anchor.position.lerp(Vector3(.23,1.36,-.39) if raised else Vector3(.29,.93,-.12),blend)
	weapon_anchor.rotation.x=lerp_angle(weapon_anchor.rotation.x,aim_pitch if raised else -.65,blend)
	left_target.position.z=-.08 if weapon_kind==0 else -.24
	right_ik.influence=lerpf(right_ik.influence,1.0 if has_weapon else 0.0,blend)
	left_ik.influence=lerpf(left_ik.influence,1.0 if raised else 0.0,blend)

func play_state(next: String,rate: float=1.0) -> void:
	if not clips.has(next): return
	if state!=next:
		state=next
		animator.play(clips[next],.20,1)
	animator.speed_scale=rate

func move_pose(speed: float,grounded: bool,vertical_speed: float,is_aiming: bool,dt: float,landed: bool=false) -> void:
	if dead: return
	aiming=is_aiming
	if landed: landing_left=.26
	landing_left=maxf(0,landing_left-dt)
	if not grounded: play_state("jump" if vertical_speed>.4 else "fall")
	elif landing_left>0: play_state("land")
	elif speed>4: play_state("run",clampf(speed/6.1,.65,1.25))
	elif speed>.15: play_state("walk",clampf(speed/2.5,.4,1.35))
	elif is_aiming: play_state("aim")
	else: play_state("idle")

func mount_pose() -> void:
	play_state("riding")

func death_pose(impulse: Vector3=Vector3.ZERO) -> void:
	if dead: return
	dead=true
	animator.pause()
	weapon_anchor.hide()
	if right_ik: right_ik.stop()
	if left_ik: left_ik.stop()
	if not simulator: simulator=StreetRagdoll.build(skeleton)
	simulator.physical_bones_start_simulation()
	for body in simulator.get_children():
		if body is PhysicalBone3D:
			body.linear_velocity=impulse.limit_length(12)+Vector3(0,.4,0)
			body.angular_velocity=Vector3(.7,0,.3)

func recover() -> void:
	if simulator: simulator.physical_bones_stop_simulation()
	skeleton.reset_bone_poses()
	dead=false
	state=""
	weapon_anchor.show()
	if right_ik: right_ik.start()
	if left_ik: left_ik.start()
	play_state("idle")

func attach_weapon(weapon: Node3D,kind: int=0) -> void:
	weapon_anchor.add_child(weapon)
	has_weapon=true
	weapon_kind=kind
	weapon.transform=Transform3D.IDENTITY

func muzzle() -> Vector3:
	return weapon_anchor.global_transform*Vector3(0,.04,-[.26,.42,.72,.69][weapon_kind])
