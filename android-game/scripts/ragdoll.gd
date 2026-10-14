class_name StreetRagdoll
extends RefCounted

static func build(skeleton: Skeleton3D) -> PhysicalBoneSimulator3D:
	var simulator=PhysicalBoneSimulator3D.new()
	simulator.name="PhysicalRagdoll"
	skeleton.add_child(simulator)
	var links={"Hips":"Spine","Spine":"Spine1","Spine1":"Neck","Head":"", "LeftArm":"LeftForeArm","LeftForeArm":"LeftHand","RightArm":"RightForeArm","RightForeArm":"RightHand","LeftUpLeg":"LeftLeg","LeftLeg":"LeftFoot","RightUpLeg":"RightLeg","RightLeg":"RightFoot"}
	for label in links:
		var id=skeleton.find_bone(label)
		if id<0: continue
		var rest=skeleton.get_bone_global_rest(id)
		var child_id=skeleton.find_bone(links[label]) if not links[label].is_empty() else -1
		var local_end=Vector3(0,.22,0)
		if child_id>=0: local_end=rest.affine_inverse()*skeleton.get_bone_global_rest(child_id).origin
		var length=maxf(.12,local_end.length())
		var radius=.12 if label in ["Hips","Spine","Spine1"] else (.105 if label=="Head" else .075)
		var body=PhysicalBone3D.new()
		body.name="Body_"+label
		simulator.add_child(body)
		body.set("bone_name",label)
		assert(body.get_bone_id()>=0,"Physical bone must bind: "+label)
		body.mass=9.0 if label in ["Hips","Spine","Spine1"] else 3.0
		body.linear_damp=.3
		body.angular_damp=2.0
		body.collision_layer=32
		body.collision_mask=1|4
		body.body_offset=Transform3D(Basis(Quaternion(Vector3.UP,local_end.normalized())),local_end*.5)
		body.joint_offset=body.body_offset.affine_inverse()
		if label!="Hips":
			body.joint_type=PhysicalBone3D.JOINT_TYPE_CONE
			body.set("joint_constraints/swing_span",35.0 if label in ["Spine","Spine1","LeftLeg","RightLeg"] else 65.0)
			body.set("joint_constraints/twist_span",18.0)
		var shape=CollisionShape3D.new()
		var capsule=CapsuleShape3D.new()
		capsule.radius=radius
		capsule.height=maxf(radius*2,length*.92)
		shape.shape=capsule
		body.add_child(shape)
	return simulator
