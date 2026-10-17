extends Node

# No images, new level geometry or art resources are required for these checks.
var checks := 0
var failures: Array[String] = []

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("HORDE_0812_FAIL: " + label)

func isolated(count: int) -> HordeRun:
	var r := HordeRun.new()
	r.start(MonsterCatalog.defaults().levels, 812)
	r.entities.clear();r.physics_surfaces.clear();r.physics_gaps.clear();r.events.clear();r.next_segment = 99999
	while r.members.size() < count: r.add_member(0, false)
	return r

func run_checks() -> void:
	var stage_zero: float = HordeDirector.stage_speed(0)
	expect(is_equal_approx(stage_zero, 305.0), "Tunnel progression preserves initial speed")
	expect(is_equal_approx(HordeDirector.stage_speed(2) - stage_zero, 1.2 * (1.10 * 22.0)), "Speed gained through tunnels increased by 20 percent")
	var masked := isolated(16)
	masked.perk_kind = 2;masked.perk_left = 10.0
	expect(masked.member_force() == 2, "Mask gives two effective force units per survivor")
	expect(masked.active_count() == 16 and masked.active_count() * masked.member_force() == 32, "16 living masked characters have 32 force")
	masked.power_levels["mask_force"] = 1
	expect(masked.member_force() == 3, "Mask strength upgrades still work")
	masked.power_levels["mask_size"] = 1
	expect(masked.member_force() == 6, "Mask titan multiplier still works")
	masked.jump()
	expect(float(masked.members[0].get("jump_gravity_scale", 1.0)) > 1.0, "Masked jump is shorter and heavier")

	for kind in ["truck", "plane"]:
		var r := isolated(1)
		var spec: Dictionary = MonsterCatalog.VEHICLES[kind]
		var width: float = float(spec.width) * HordeBalance.VEHICLE_SCALE
		var obstacle := r.add_entity(kind, HordeRun.ANCHOR + width * 0.5 + 12.0)
		var roof_y: float = float(obstacle.y) - float(obstacle.roof)
		var rear_x: float = float(obstacle.x) + float(obstacle.width) * 0.5 - 24.0
		r.members[0].x = rear_x
		r.members[0].y = roof_y + 7.0
		var support := r.member_floor(r.members[0])
		expect(int(support.roof) == int(obstacle.id), kind + ": support remains at rear edge")
		r.update_vehicle(obstacle, 1.0 / 60.0)
		expect(r.members.size() == 1 and not r.dead, kind + ": roof jitter cannot kill survivor")
		expect(absf(float(r.members[0].x) - rear_x) < 0.01, kind + ": roof runner is never sent back to bumper")
		r.flip_vehicle(obstacle)
		r.rebuild_surfaces()
		expect(int(r.member_floor(r.members[0]).roof) == int(obstacle.id), kind + ": flipped roof stays briefly horizontal")
		r.elapsed += 1.1
		r.rebuild_surfaces()
		expect(int(r.member_floor(r.members[0]).roof) == -1, kind + ": flipped roof eventually expires")

	var camera := isolated(2)
	camera.view_left = 100.0
	camera.members[0].x = 72.0
	var first_id: int = int(camera.members[0].id)
	camera.advance(1.0 / 60.0)
	expect(not camera.member_by_id(first_id).is_empty(), "Camera retains partly visible character")
	camera.members[0].x = -90.0
	camera.advance(1.0 / 60.0)
	expect(camera.member_by_id(first_id).is_empty(), "Camera removes only fully hidden character")

	var large := isolated(96)
	large.view_left = 100.0
	expect(large.slot_x(95) + 43.0 >= large.view_left, "Large horde formation stays on screen at rest")

	var regroup := isolated(4)
	var original: float = float(regroup.members[0].x)
	regroup.members[0].x = original + 90.0
	regroup.members[0].reform_hold_until = regroup.elapsed + HordeTuning.LANDING_RECOVERY_SECONDS
	expect(is_equal_approx(regroup.reform_x(regroup.members[0], original, 1.0 / 60.0), original + 90.0), "Wait before regrouping after a landing")
	regroup.elapsed += HordeTuning.LANDING_RECOVERY_SECONDS + 0.1
	var next_x: float = regroup.reform_x(regroup.members[0], original, 1.0 / 60.0)
	expect(next_x < original + 90.0 and next_x > original, "Regrouping resumes smoothly without teleporting")

	print("HORDE_0812_REGRESSIONS: ", checks, " checks / ", failures.size(), " failures")
