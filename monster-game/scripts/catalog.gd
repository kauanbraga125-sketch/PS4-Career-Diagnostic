class_name MonsterCatalog
extends RefCounted

const ANCHOR=340.0
const ZONE_LENGTH=6000.0
const MAX_HORDE=24
const AREAS=[
	{"name":"Cemitério","price":0,"description":"A primeira madrugada. Túmulos, névoa e criaturas à espera.","color":Color("bba0dd")},
	{"name":"Cidade em Caos","price":0,"description":"Civis fugindo, incêndios e helicópteros caindo ao fundo.","color":Color("efb58a")},
	{"name":"Zona Industrial","price":700,"description":"Fábricas, guindastes e tropas entre as chaminés.","color":Color("9cddd5")},
	{"name":"Aeroporto","price":1200,"description":"Hangares, pistas iluminadas e grandes aviões.","color":Color("b4d7ee")}
]
const VEHICLES={
	"moto":{"name":"MOTO","need":2,"icon":0,"height":65.0,"width":110.0,"collision":55.0,"reward":5,"rescues":1},
	"car":{"name":"CARRO","need":4,"icon":-1,"height":96.0,"width":155.0,"collision":70.0,"reward":8,"rescues":1},
	"bus":{"name":"ÔNIBUS","need":8,"icon":1,"height":132.0,"width":230.0,"collision":112.0,"reward":18,"rescues":3},
	"truck":{"name":"CAMINHÃO","need":10,"icon":4,"height":123.0,"width":210.0,"collision":105.0,"reward":22,"rescues":3},
	"tank":{"name":"TANQUE","need":12,"icon":2,"height":112.0,"width":195.0,"collision":90.0,"reward":28,"rescues":4},
	"plane":{"name":"AVIÃO","need":16,"icon":3,"height":140.0,"width":240.0,"collision":114.0,"reward":40,"rescues":5}
}

const MONSTERS=[
	{"name":"Zumbi","tag":"A horda começa aqui","description":"Encontrado na pista. Cada recruta ajuda a manter sua corrida viva.","color":Color("93e1be")},
	{"name":"Esqueleto","tag":"Recruta da madrugada","description":"Outra criatura coletável. Junta-se ao grupo com sua própria animação.","color":Color("f1ddba")},
	{"name":"Mascarado","tag":"Bônus da máscara","description":"A máscara transforma toda a horda. Destrói carros e obstáculos por alguns segundos.","color":Color("f29786")},
	{"name":"Mosca Mutante","tag":"Bônus do cristal","description":"O cristal transforma o grupo. As asas permitem flutuar sobre buracos e perigos.","color":Color("c39cf3")}
]
const UPGRADES=[
	{"id":"horde","name":"PRIMEIRA HORDA","icon":-1,"price":50,"max":3,"description":"Mais um zumbi no início de cada corrida."},
	{"id":"jump","name":"PULO ÁGIL","icon":4,"price":65,"max":3,"description":"Pulos mais altos. No nível 2, libera salto duplo."},
	{"id":"magnet","name":"ÍMÃ DE MOEDAS","icon":3,"price":70,"max":3,"description":"Atrai moedas de uma distância maior."},
	{"id":"perk","name":"METAMORFOSE","icon":0,"price":80,"max":3,"description":"Mais 2 segundos em cada transformação."}
]
const CHALLENGES=[
	{"id":"recruits","target":5,"reward":40,"title":"RECRUTE 5 CRIATURAS"},
	{"id":"coins","target":25,"reward":50,"title":"COLETE 25 MOEDAS"},
	{"id":"distance","target":500,"reward":75,"title":"ALCANCE 500 METROS"}
]

const SKIN_PRICES=[0,240,650,950]
const MISSIONS=[
	{"id":"recruits","stat":"recruits","target":5,"reward":40,"title":"RECRUTE 5 CRIATURAS","mode":"sum"},
	{"id":"coins","stat":"coins","target":25,"reward":50,"title":"COLETE 25 MOEDAS","mode":"sum"},
	{"id":"distance","stat":"distance","target":500,"reward":75,"title":"ALCANCE 500 METROS","mode":"best"},
	{"id":"cars","stat":"cars","target":3,"reward":80,"title":"VIRE 3 VEÍCULOS","mode":"sum"},
	{"id":"jumps","stat":"jumps","target":8,"reward":70,"title":"FAÇA 8 SALTOS SEGUROS","mode":"sum"},
	{"id":"bonuses","stat":"bonuses","target":3,"reward":60,"title":"ATIVE 3 BÔNUS","mode":"sum"},
	{"id":"horde","stat":"horde","target":8,"reward":90,"title":"FORME UMA HORDA DE 8","mode":"best"},
	{"id":"distance_long","stat":"distance","target":900,"reward":110,"title":"ALCANCE 900 METROS","mode":"best"},
	{"id":"coins_many","stat":"coins","target":100,"reward":100,"title":"COLETE 100 MOEDAS","mode":"sum"},
	{"id":"cars_many","stat":"cars","target":6,"reward":130,"title":"VIRE 6 VEÍCULOS","mode":"sum"},
	{"id":"flights","stat":"flights","target":2,"reward":100,"title":"VOE EM 2 TRANSFORMAÇÕES","mode":"sum"},
	{"id":"boost","stat":"boost","target":120,"reward":120,"title":"CORRA 120 M EM FRENESI","mode":"sum"}
]

static func active_missions(tier: int) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var start=posmod(tier,4)*3
	var scale=1+int(tier/4)*.35
	for i in range(3):
		var item=MISSIONS[start+i].duplicate()
		item.target=ceili(float(item.target)*scale)
		item.title=str(item.title).replace(str(MISSIONS[start+i].target),str(item.target))
		item.reward=ceili(float(item.reward)*scale)
		item.key=str(tier)+":"+str(item.id)
		result.append(item)
	return result

static func defaults() -> Dictionary:
	return {"version":3,"wallet":120,"best":0,"runs":0,"audio":true,"levels":{"horde":0,"jump":0,"magnet":0,"perk":0},"claimed":[],"owned":[0],"skin":0,"areas":[0,1],"mission_tier":0,"mission_progress":{},"missions_completed":0}

static func upgrade_cost(item: Dictionary,level: int) -> int:
	return int(item.price)*(level+1)
