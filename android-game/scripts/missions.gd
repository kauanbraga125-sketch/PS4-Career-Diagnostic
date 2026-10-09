class_name StreetMissions
extends Node

const STORIES = [
	["De volta ao porto","Lia: a oficina reabriu. Venha à esquina conhecer sua nova cidade.",150],
	["Primeiro frete","Lia: pegue um carro, recolha as peças no centro e leve ao porto.",300],
	["Entrega expressa","Rafa: precisamos de uma moto. Atravesse quatro pontos antes do prazo.",400],
	["Depois da tempestade","Dona Rosa: três caixas de remédios ficaram pelo parque. Recolha todas a pé.",350],
	["Mira responsável","Lia: encontre o equipamento no estande e acerte os três alvos metálicos.",400],
	["Ninguém fica para trás","Rafa está preso na área industrial. Afaste os três guardas e leve-o à clínica.",700],
	["Curvas da serra","Rafa: teste a moto na estrada oeste. Quatro checkpoints, sem atalhos pelo mar.",650],
	["Rastro de papel","Lia: há provas em três depósitos do porto. Entre, recolha e saia.",800],
	["Sem deixar rastro","O alarme disparou. Despiste a patrulha e retorne à oficina sem ser visto.",750],
	["A última entrega","Lia: leve as provas de carro ao farol. Complete a rota e elimine a emboscada final.",1500]
]
var game
var index = 0
var stage = 0
var targets: Array[Vector3] = []
var countdown = -1.0
var transition = 0.0
var kills = 0
var hits = 0
var entities: Array[Node] = []
var marker: Node3D
var marker_label: Label3D
var objective = ""
var elapsed = 0.0

func setup(owner_game) -> void:
	game = owner_game
	marker = Node3D.new()
	game.add_child(marker)
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 2.0
	torus.outer_radius = 2.25
	torus.rings = 20
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = StreetModels.mat(Color("e7bc68"))
	marker.add_child(ring)
	marker_label = Label3D.new()
	marker_label.position.y = 4.0
	marker_label.font_size = 48
	marker_label.pixel_size = 0.024
	marker_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker_label.no_depth_test = true
	marker_label.modulate = Color("f4d594")
	marker.add_child(marker_label)
	start(index)

func coords(list: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in list: out.append(CityWorld.ground(Vector3(p[0],0,p[1])))
	return out

func clear_entities() -> void:
	for e in entities:
		if is_instance_valid(e): e.queue_free()
	entities.clear()

func start(number: int) -> void:
	clear_entities()
	index = clampi(number,0,10)
	stage = 0
	kills = 0
	hits = 0
	countdown = -1
	transition = 0
	if index>=10:
		objective = "Campanha concluída. A cidade é sua: explore e encontre todas as armas."
		marker.visible = false
		return
	marker.visible = true
	match index:
		0: targets = coords([[120,18]])
		1: targets = coords([[120,-102],[480,18]])
		2:
			targets = coords([[360,5],[360,-240],[120,-240],[120,5]])
			countdown = 180
		3: targets = coords([[-180,-132],[-252,-240],[-132,-360]])
		4:
			targets = coords([[-108,-360]])
			for z in [-371,-360,-349]:
				var body = StaticBody3D.new()
				body.collision_layer = 16
				body.set_meta("range_target",true)
				body.set_meta("active",true)
				game.add_child(body)
				body.position = CityWorld.ground(Vector3(-90,0,z),1.55)
				var shape = CollisionShape3D.new()
				var sphere = SphereShape3D.new()
				sphere.radius = 1.2
				shape.shape = sphere
				body.add_child(shape)
				StreetModels.part(body,Vector3(0.18,2.4,2.4),Vector3.ZERO,Color("d5ad61"))
				StreetModels.part(body,Vector3(0.20,1.10,1.1),Vector3.ZERO,Color("ab4a39"))
				StreetModels.part(body,Vector3(0.22,0.32,0.32),Vector3.ZERO,Color("e9dec6"))
				entities.append(body)
		5:
			targets = coords([[492,132],[120,258]])
			spawn_guards([[481,128],[498,138],[485,149]])
			var hostage = game.spawn_npc(Vector3(492,0,132),2,"hostage")
			entities.append(hostage)
		6:
			targets = coords([[-240,5],[-480,5],[-480,-360],[-240,-360]])
			countdown = 210
		7:
			targets = coords([[378,138],[498,258],[618,378]])
			spawn_guards([[382,143],[502,262],[622,382]])
		8:
			targets = coords([[60,18]])
			game.heat = maxf(game.heat,65)
			game.spawn_patrol()
		9:
			targets = coords([[240,5],[480,5],[600,240],[600,600],[652,600]])
			countdown = 300
			spawn_guards([[642,600],[650,608],[640,611]])
	update_objective()

func spawn_guards(positions: Array) -> void:
	for p in positions:
		var enemy = game.spawn_npc(Vector3(p[0],0,p[1]),7,"enemy")
		entities.append(enemy)

func current_target() -> Vector3:
	if targets.is_empty() or index>=10: return Vector3.ZERO
	return targets[mini(stage,targets.size()-1)]

func update_objective() -> void:
	if index>=10: return
	match index:
		0: objective = "Vá ao encontro de Lia na esquina da oficina."
		1: objective = "De carro: recolha as peças." if stage==0 else "Leve as peças ao porto, de carro."
		2: objective = "De moto: checkpoint %d / 4" % (stage+1)
		3: objective = "A pé: recolha a caixa de remédios %d / 3." % (stage+1)
		4: objective = "Encontre uma arma e acerte os alvos: %d / 3." % hits
		5: objective = "Afaste os guardas (%d/3) e aproxime-se de Rafa." % kills if stage==0 else "Escolte Rafa até a clínica."
		6: objective = "De moto: curva da serra %d / 4." % (stage+1)
		7: objective = "A pé: recolha o documento %d / 3." % (stage+1)
		8: objective = "Despiste a polícia e volte à oficina."
		9: objective = "De carro: rota do farol %d / 5." % (stage+1) if stage<4 else "Afaste a emboscada (%d/3) e entregue de carro." % kills
	marker.position = current_target()+Vector3(0,0.18,0)
	marker_label.text = "OBJETIVO"

func tick(dt: float) -> void:
	elapsed += dt
	if index>=10: return
	if transition>0:
		transition -= dt
		if transition<=0: start(index)
		return
	var pos = game.focus_position()
	marker_label.text = str(int(pos.distance_to(current_target()))) + " m"
	marker.rotation.y += dt*0.5
	# Race clocks begin on mounting the required vehicle, so exploration stays possible.
	var v = game.player.vehicle
	var valid_vehicle = v and ((index in [2,6] and v.motorcycle) or (index==9 and not v.motorcycle))
	if countdown>0 and (stage>0 or valid_vehicle):
		countdown -= dt
		if countdown<=0:
			fail("O prazo acabou. A missão foi reiniciada.")
			return
	if index==4:
		if hits>=3: complete()
		return
	if pos.distance_to(current_target())> (12 if v else 5): return
	match index:
		1,9:
			if not v or v.motorcycle: return
			if index==9 and stage==4 and kills<3: return
		2,6:
			if not v or not v.motorcycle: return
		3,7:
			if v: return
		5:
			if stage==0 and kills<3: return
		8:
			if game.heat>0: return
	advance()

func advance() -> void:
	stage += 1
	game.sound.play("pickup")
	if stage>=targets.size(): complete()
	else:
		game.notify("Etapa concluída. Próximo destino marcado no mapa.")
		update_objective()

func complete() -> void:
	if index>=10 or transition>0: return
	var reward = STORIES[index][2]
	game.money += reward
	game.notify("MISSÃO CONCLUÍDA  /  +R$ " + str(reward),5)
	game.sound.play("mission")
	game.player.health = minf(100,game.player.health+25)
	index += 1
	transition = 4
	clear_entities()
	marker.visible = false
	game.save_game()
	if index>=10:
		objective = "10/10 missões concluídas. Explore Porto Livre."
		game.notify("PORTO LIVRE  /  Campanha concluída!",7)

func fail(reason: String) -> void:
	game.notify(reason,5)
	start(index)

func on_defeat(npc: StreetNPC) -> void:
	if entities.has(npc) and npc.role=="enemy":
		kills += 1
		update_objective()
	if npc.role=="hostage" and index==5: fail("Rafa caiu. O resgate foi reiniciado.")

func hit_target(body: Node) -> void:
	if index!=4 or not body.get_meta("active",false): return
	body.set_meta("active",false)
	body.collision_layer = 0
	body.visible = false
	hits += 1
	game.sound.play("pickup")
	update_objective()
