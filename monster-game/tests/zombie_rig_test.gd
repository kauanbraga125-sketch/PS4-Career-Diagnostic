extends Node
var checks=0
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error("HORDE_RIG_FAIL: "+message)
func run(game) -> void:
	var rig=game.actor.zombie as HordeZombieRig
	check(rig.skeleton is Skeleton2D,"Zombie uses a real Skeleton2D hierarchy")
	check(rig.skeleton.is_inside_tree() and rig.skeleton.get_bone_count()==15,"Skeleton is registered, so parent movement invalidates all child transforms")
	check(rig.bones.size()==15,"Pelvis, spine, head and independent right/left limb chains")
	for side in ["left","right"]:
		check(rig.bones[side+"_upper_arm"].get_parent()==rig.bones.spine,"Each shoulder inherits the torso")
		check(rig.bones[side+"_thigh"].get_parent()==rig.bones.pelvis,"Each leg inherits the pelvis")
		check(rig.bones[side+"_hand"].get_parent()==rig.bones[side+"_forearm"],"Wrist inherits its own forearm")
		check(rig.bones[side+"_foot"].get_parent()==rig.bones[side+"_shin"],"Ankle inherits its own shin")
	var states=["idle","run","rise","fall","push","panic","capture"]
	for state in states:
		for frame in range(32):
			var phase=frame/32.0
			rig.pose(phase,state,phase*2,.10 if frame%2==0 else 0,.7)
			var intact=true
			for side in ["left","right"]:
				for pair in [["upper_arm","forearm",15.0],["forearm","hand",13.0],["thigh","shin",19.0],["shin","foot",17.0]]:
					var a=rig.bones[side+"_"+pair[0]] as Bone2D
					var b=rig.bones[side+"_"+pair[1]] as Bone2D
					intact=intact and absf(a.global_position.distance_to(b.global_position)-pair[2])<.0001
			check(intact,"Fixed anatomical lengths across "+state+" phase "+str(frame))
			var shoulders=true
			for side in ["left","right"]:
				var local=rig.RIGHT_SHOULDER if side=="right" else rig.LEFT_SHOULDER
				shoulders=shoulders and (rig.bones.spine.global_transform*local).distance_to(rig.bones[side+"_upper_arm"].global_position)<.0001
			check(shoulders,"Torso movement carries both shoulder sockets")
	# Draw-time reuse must not leak a preceding actor's capture pose into a jumper.
	rig.pose(.25,"rise",.8)
	var expected=rig.bones.head.global_transform
	rig.pose(.5,"capture",.8);rig.pose(.25,"rise",.8)
	check(rig.bones.head.global_transform.is_equal_approx(expected),"Pose is independent of preceding actor/state")
	rig.pose(0,"idle",0)
	check(rig.bones.left_hand.global_position.x<rig.bones.spine.global_position.x-10,"Far hand is on the far side in the menu")
	check(rig.bones.right_hand.global_position.x>rig.bones.spine.global_position.x+20,"Near hand is on the near side in the menu")
	for phase in [0.0,.5]:
		rig.pose(phase,"run",phase)
		var right_reach=rig.bones.right_hand.global_position.x-rig.bones.right_upper_arm.global_position.x
		var left_reach=rig.bones.left_hand.global_position.x-rig.bones.left_upper_arm.global_position.x
		var foot_difference=rig.bones.right_foot.global_position.x-rig.bones.left_foot.global_position.x
		check((right_reach-left_reach)*foot_difference<0,"Arms oppose their corresponding legs during the stride")
	# In each planted portion of a stride, the bottom of the foot is on the floor.
	for frame in range(12):
		var phase=frame/24.0
		rig.pose(phase,"run",phase)
		var sole=rig.bones.right_foot.global_transform*rig.bindings.right_foot*Vector2(101,211)
		check(absf(sole.y)<.02,"Grounded support foot stays on the baseline")
	print("HORDE_RIG_CHECKS: ",checks)
