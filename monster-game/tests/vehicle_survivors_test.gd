extends Node

# Regression checks for individual vehicle losses, specifically the truck/plane
# post-jump snapback that used to erase an entire horde.
var checks := 0
var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("HORDE_VEHICLE_SURVIVORS_FAIL: " + message)

func isolated(count: int) -> HordeRun:
	var run := HordeRun.new()
	run.start(MonsterCatalog.defaults().levels, 81011)
	run.entities.clear();run.events.clear();run.next_segment = 99999
	for i in range(count - 1): run.add_member(0, false)
	return run

func run_checks() -> void:
	for kind in ["truck", "plane"]:
		var run := isolated(4)
		var width := float(MonsterCatalog.VEHICLES[kind].width) * HordeBalance.VEHICLE_SCALE
		var vehicle := run.add_entity(kind, HordeRun.ANCHOR + width * 0.5 + 12)
		var edge := float(vehicle.x) - float(vehicle.width) * 0.5
		var survivor_id := int(run.members[0].id)
		var doomed_id := int(run.members[1].id)
		var survivor_x := float(vehicle.x) + float(vehicle.width) * 0.5 + 65
		run.members[0].x = survivor_x
		run.members[1].x = edge + float(vehicle.width) * 0.65
		run.members[1].y = float(vehicle.y) - float(vehicle.roof) + 26
		run.update_vehicle(vehicle, 1.0 / 60.0)
		expect(not run.dead, kind + ": one failed landing cannot end the run")
		expect(int(run.members.size()) == 3, kind + ": only the embedded member is lost")
		expect(not run.member_by_id(survivor_id).is_empty(), kind + ": member beyond vehicle survives")
		expect(run.member_by_id(doomed_id).is_empty(), kind + ": embedded member is removed")
		expect(absf(float(run.member_by_id(survivor_id).x) - survivor_x) < 0.01, kind + ": survivor is never snapped behind the vehicle")

		var roof_run := isolated(1)
		var roof := roof_run.add_entity(kind, HordeRun.ANCHOR + width * 0.5 + 12)
		var roof_edge := float(roof.x) - float(roof.width) * 0.5
		roof_run.members[0].x = roof_edge + float(roof.width) * 0.65
		roof_run.members[0].y = float(roof.y) - float(roof.roof) + 6
		var original_x := float(roof_run.members[0].x)
		roof_run.update_vehicle(roof, 1.0 / 60.0)
		expect(not roof_run.dead and roof_run.members.size() == 1, kind + ": small roof contact jitter is harmless")
		expect(absf(float(roof_run.members[0].x) - original_x) < 0.01, kind + ": roof walker is never teleported")

		var rear := isolated(2)
		var obstruction := rear.add_entity(kind, HordeRun.ANCHOR + width * 0.5 + 12)
		var passed_id := int(rear.members[0].id)
		rear.members[0].x = float(obstruction.x) + float(obstruction.width) * 0.5 + 65
		for t in range(230):
			rear.advance(1.0 / 60.0)
			if rear.dead: break
		expect(rear.losses >= 1, kind + ": the member left behind by the camera is lost")
		expect(not rear.dead and not rear.member_by_id(passed_id).is_empty(), kind + ": the runner who cleared the vehicle continues")

	var front := isolated(1)
	var car := front.add_entity("car", HordeRun.ANCHOR + float(MonsterCatalog.VEHICLES.car.width) * HordeBalance.VEHICLE_SCALE * 0.5 + 12)
	front.update_vehicle(car, 1.0 / 60.0)
	expect(car.contacts.size() == 1 and not car.taken, "normal vehicle pushing remains available")
	print("HORDE_VEHICLE_SURVIVORS: ", checks, " checks / ", failures.size(), " failures")
