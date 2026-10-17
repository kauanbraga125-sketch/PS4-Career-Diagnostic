extends Node
# v0.8.13 gameplay regressions; no new textures/sprites.
var checks := 0
var failures: Array[String] = []
func expect(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures.append(msg)
		push_error("HORDE_0813_FAIL: " + msg)

func isolated(count: int) -> HordeRun:
	var r := HordeRun.new()
	r.start(MonsterCatalog.defaults().levels, 813)
	r.entities.clear();r.physics_surfaces.clear();r.physics_gaps.clear();r.events.clear();r.next_segment = 99999
	while r.members.size() < count: r.add_member(0, false)
	return r

func run_checks() -> void:
	var r := isolated(30)
	var car := r.add_entity("car", 1450.0)
	var tank := r.add_entity("tank", 1900.0)
	r.configure_vehicle(car);r.configure_vehicle(tank)
	expect(int(car.required_count) == 4 and int(MonsterCatalog.VEHICLES.car.need) == 4, "Cars always need four")
	expect(int(tank.required_count) == 12 and int(MonsterCatalog.VEHICLES.tank.need) == 12, "Tanks always need twelve")
	expect(not bool(car.reinforced) and not bool(tank.reinforced), "Fake armored vehicles are disabled")
	expect(not MonsterCatalog.VEHICLES.has("armored_car"), "No missing armored-car artwork is referenced")

	var recruits := isolated(3)
	var person := recruits.add_entity("civilian", 940.0)
	var old_members: int = recruits.members.size()
	var slot: float = recruits.slot_x(old_members)
	recruits.complete_capture(person)
	expect(person.taken and recruits.members.size() == old_members + 1, "Civilian adds member immediately")
	var latest: Dictionary = recruits.members[-1]
	expect(is_equal_approx(float(latest.x), slot), "New character joins its real formation slot")
	expect(is_equal_approx(float(latest.y), recruits.ground_y(slot)), "New character starts standing, not floating")
	expect(is_zero_approx(float(latest.arrival)), "New character has no floating arrival bounce")

	var gunners := isolated(4)
	var soldier := gunners.add_entity("soldier", HordeRun.ANCHOR + 580.0)
	var seen: Dictionary = {}
	var vy_by_mode: Dictionary = {}
	for j in range(6):
		soldier.timer = 0.0
		gunners.update_enemies(1.0 / 60.0)
		for bullet in gunners.entities:
			if bullet.kind == "bullet":
				seen[str(bullet.get("shot_mode", ""))] = true
				vy_by_mode[str(bullet.get("shot_mode", ""))] = float(bullet.vy)
	expect(seen.has("low") and seen.has("high") and seen.has("tracking"), "Soldiers cycle through three modes")
	expect(float(vy_by_mode.get("low", 0.0)) > 0, "Low bullet angles toward feet")
	expect(float(vy_by_mode.get("high", 0.0)) < 0, "High bullet angles above standing runner")

	var fly := isolated(1)
	fly.perk_kind = 3;fly.perk_left = 6
	fly.members[0].y = 340.0
	var before_y: float = float(fly.members[0].y)
	var width: float = float(MonsterCatalog.VEHICLES.truck.width) * HordeBalance.VEHICLE_SCALE
	var roof := fly.add_entity("truck", HordeRun.ANCHOR + width * 0.5)
	fly.rebuild_surfaces()
	fly.advance(1.0 / 60.0)
	expect(absf(float(fly.members[0].y) - before_y) < 18.0, "Flying onto truck has no sudden position snap")

	var tunnels := isolated(16)
	tunnels.tunnels.clear()
	tunnels.schedule_tunnel(1, 1500.0)
	tunnels.update_tunnels()
	expect(bool(tunnels.tunnels[0].get("rewards_spawned", false)), "Tunnel rewards planned before entering")
	var coins := 0
	for e in tunnels.entities:
		if e.kind == "coin": coins += 1
	expect(coins >= 12, "Tunnel contains visible coin formations")
	expect(tunnels.remaining_soul_slots() >= 0, "Tunnel rewards respect soul budget")
	print("HORDE_0813_REGRESSIONS: ", checks, " checks / ", failures.size(), " failures")
