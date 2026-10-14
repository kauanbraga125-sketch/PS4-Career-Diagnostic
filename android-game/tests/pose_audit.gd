extends SceneTree
func _init(): call_deferred("audit")
func audit():
	var scene=Node3D.new()
	root.add_child(scene)
	for kind in range(4):
		var gun=StreetModels.gun(kind)
		scene.add_child(gun)
		var parts: Array=[]
		StreetModels.collect_meshes(gun,Transform3D.IDENTITY,parts)
		for part in parts: print("GUN_AXIS ",kind," root=",gun.transform," bound=",part.transform*part.mesh.get_aabb())
		gun.queue_free()
	var floor_body=StaticBody3D.new()
	scene.add_child(floor_body)
	floor_body.collision_layer=1
	var shape=CollisionShape3D.new()
	var box=BoxShape3D.new()
	box.size=Vector3(30,.3,30)
	shape.shape=box
	shape.position.y=-.15
	floor_body.add_child(shape)
	var actor=StreetModels.person(0)
	scene.add_child(actor)
	actor.position=Vector3(3000,2,3000)
	floor_body.position=Vector3(3000,0,3000)
	await process_frame
	var skel=actor.skeleton
	print("SKELETON ",skel.global_transform," HIPS_REST ",skel.get_bone_global_rest(skel.find_bone("Hips")))
	actor.death_pose(Vector3(2,0,0))
	for frame in range(160): await physics_frame
	for name in ["Hips","Head","LeftFoot","RightFoot","LeftArm"]:
		var id=skel.find_bone(name)
		print("BONE_WORLD ",name," ",skel.global_transform*skel.get_bone_global_pose(id))
	for body in actor.simulator.get_children(): print("PHYS_BODY ",body.get("bone_name")," ",body.global_transform)
	print("POSE_AUDIT_OK")
	quit()
