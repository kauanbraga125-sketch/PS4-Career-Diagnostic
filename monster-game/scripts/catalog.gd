class_name MonsterCatalog
extends RefCounted

const ANCHOR=340.0
const ZONE_LENGTH=18000.0
const MAX_HORDE=24
const AREAS=[
	{"name":"Cemitério","price":0,"description":"A primeira madrugada. Túmulos, névoa e criaturas à espera.","color":Color("bba0dd")},
	{"name":"Cidade em Caos","price":0,"description":"Civis fugindo, incêndios e helicópteros caindo ao fundo.","color":Color("efb58a")},
	{"name":"Zona Industrial","price":2200,"description":"Fábricas, guindastes e tropas entre as chaminés.","color":Color("9cddd5")},
	{"name":"Aeroporto","price":3800,"description":"Hangares, pistas iluminadas e grandes aviões.","color":Color("b4d7ee")}
]
const VEHICLES={
	"moto":{"name":"MOTO","need":2,"icon":0,"height":96.0,"width":150.0,"collision":80.0,"reward":2,"rescues":1,"reverse":true,"windows":[]},
	"car":{"name":"CARRO","need":4,"icon":1,"height":122.0,"width":246.0,"collision":102.0,"reward":3,"rescues":1,"reverse":false,"windows":[Vector2(-.02,-.16)],"passenger_height":32.0},
	"bus":{"name":"ÔNIBUS","need":8,"icon":2,"height":234.0,"width":470.0,"collision":150.0,"reward":8,"rescues":4,"reverse":false,"windows":[Vector2(-.15,-.08),Vector2(.021,-.08),Vector2(.192,-.08),Vector2(.356,-.08)],"passenger_height":50.0},
	"truck":{"name":"CAMINHÃO","need":10,"icon":3,"height":226.0,"width":460.0,"collision":142.0,"reward":10,"rescues":4,"reverse":false,"windows":[Vector2(-.25,-.045)],"passenger_height":30.0},
	"tank":{"name":"TANQUE","need":12,"icon":4,"height":184.0,"width":370.0,"collision":130.0,"reward":12,"rescues":4,"reverse":false,"windows":[]},
	"plane":{"name":"AVIÃO","need":16,"icon":5,"height":324.0,"width":680.0,"collision":160.0,"reward":18,"rescues":6,"reverse":false,"windows":[Vector2(-.179,-.046),Vector2(-.109,-.046),Vector2(-.044,-.046),Vector2(.017,-.046),Vector2(.075,-.046),Vector2(.13,-.046)],"passenger_height":23.0}
}
const CIVILIANS=[{"rig":4,"height":105.0},{"rig":6,"height":104.0},{"rig":7,"height":110.0}]

const MONSTERS=[
	{"name":"Zumbi","tag":"A horda começa aqui","description":"Sua primeira criatura. Capture civis para aumentar a horda e coletar almas.","color":Color("93e1be")},
	{"name":"Esqueleto","tag":"Recruta da madrugada","description":"Assusta civis e desmonta ao cair. Um visual diferente para sua horda.","color":Color("f1ddba")},
	{"name":"Mascarado","tag":"Bônus da máscara","description":"A máscara transforma a horda. Protege de impactos e destrói pequenas ameaças.","color":Color("f29786")},
	{"name":"Mosca Mutante","tag":"Bônus do cristal","description":"O cristal transforma o grupo. As asas permitem flutuar sobre buracos e perigos.","color":Color("c39cf3")}
]
const UPGRADES=[
	{"id":"horde","name":"PRIMEIRA HORDA","icon":-1,"price":350,"max":3,"description":"Mais um zumbi no início de cada corrida."},
	{"id":"jump","name":"PULO ÁGIL","icon":4,"price":420,"max":3,"description":"Pulos mais altos. No nível 2, libera salto duplo."},
	{"id":"magnet","name":"ÍMÃ DE MOEDAS","icon":3,"price":360,"max":3,"description":"Atrai moedas de uma distância maior."},
	{"id":"perk","name":"METAMORFOSE","icon":0,"price":500,"max":3,"description":"Mais 2 segundos em cada transformação."}
]
const CHALLENGES=[
	{"id":"recruits","target":5,"reward":40,"title":"RECRUTE 5 CRIATURAS"},
	{"id":"coins","target":25,"reward":50,"title":"COLETE 25 MOEDAS"},
	{"id":"distance","target":500,"reward":75,"title":"ALCANCE 500 METROS"}
]

const SKIN_PRICES=[0,1000,2800,4500]
const POWERS=[
	{"kind":3,"name":"SUPER FLY","price":0,"description":"Suba sozinho. Segure a tela para mergulhar."},
	{"kind":2,"name":"MASCARADO","price":2800,"description":"Transforme a horda em uma força de destruição."}
]
const POWER_UPGRADES=[
	{"id":"fly_time","kind":3,"name":"VOO PROLONGADO","price":500,"max":3,"description":"Mais 3 segundos de voo por nível."},
	{"id":"mask_time","kind":2,"name":"MAIS TEMPO","price":500,"max":3,"description":"Mais 3 segundos de transformação por nível."},
	{"id":"mask_force","kind":2,"name":"MAIS FORÇA","price":650,"max":3,"description":"Cada membro empurra com força extra."},
	{"id":"mask_shield","kind":2,"name":"ESCUDO","price":900,"max":1,"description":"Absorve três impactos por transformação."},
	{"id":"mask_size","kind":2,"name":"TITÃ MASCARADO","price":1600,"max":1,"description":"Aumenta o tamanho e dobra a força."},
	{"id":"mask_revive","kind":2,"name":"ÚLTIMO SUSPIRO","price":2500,"max":1,"description":"Resgata a horda de um buraco uma vez por transformação."}
]
const CIVIL_PHRASES=["HELP ME!","ME AJUDE!","¡AYUDA!","SOCORRO!","RUN, MARTY!","¡CORRE!","NOPE!","I WANT TO LIVE!","SALVE-SE!","¡NO ME COMAS!","WINTER IS COMING!","CADÊ O HERÓI?","THIS IS FINE!","¡SOCORRO!","GAME OVER?!","ME TIRA DAQUI!","NOT TODAY!","¡VÁMONOS!","HASTA LA VISTA!","CORRE, FORREST!","WHY ME?!","NÃO HOJE!","¡POR AQUÍ!","HELP!"]
const ARMY_PHRASES=["CONTACT!","MOVE! MOVE!","RECUAR!","¡ATRÁS!","HOLD THE LINE!"]
const POLICE_PHRASES=["STOP!","POLICE!","STOP! STOP!","PARADO!","¡ALTO!"]
const MISSIONS=[
	{"id":"recruits","stat":"souls","target":8,"ritual":22,"title":"CAPTURE 8 ALMAS","mode":"sum"},
	{"id":"coins","stat":"coins","target":40,"ritual":20,"title":"COLETE 40 MOEDAS","mode":"sum"},
	{"id":"distance","stat":"distance","target":450,"ritual":24,"title":"ALCANCE 450 METROS","mode":"best"},
	{"id":"cars","stat":"cars","target":2,"ritual":26,"title":"VIRE 2 VEÍCULOS","mode":"sum"},
	{"id":"jumps","stat":"jumps","target":6,"ritual":22,"title":"FAÇA 6 SALTOS SEGUROS","mode":"sum"},
	{"id":"bonuses","stat":"bonuses","target":3,"ritual":22,"title":"ATIVE 3 BÔNUS","mode":"sum"},
	{"id":"horde","stat":"horde","target":10,"ritual":26,"title":"FORME UMA HORDA DE 10","mode":"best"},
	{"id":"distance_long","stat":"distance","target":1000,"ritual":28,"title":"ALCANCE 1000 METROS","mode":"best"},
	{"id":"coins_many","stat":"coins","target":140,"ritual":24,"title":"COLETE 140 MOEDAS","mode":"sum"},
	{"id":"cars_many","stat":"cars","target":5,"ritual":30,"title":"VIRE 5 VEÍCULOS","mode":"sum"},
	{"id":"flights","stat":"flights","target":3,"ritual":26,"title":"VOE EM 3 TRANSFORMAÇÕES","mode":"sum"},
	{"id":"boost","stat":"boost","target":180,"ritual":24,"title":"CORRA 180 M EM FRENESI","mode":"sum"},
	{"id":"soldiers","stat":"soldiers","target":4,"ritual":28,"title":"CAPTURE 4 SOLDADOS","mode":"sum"},
	{"id":"souls_many","stat":"souls","target":35,"ritual":30,"title":"CAPTURE 35 ALMAS","mode":"sum"},
	{"id":"tunnels","stat":"tunnels","target":2,"ritual":28,"title":"ATRAVESSE 2 TÚNEIS","mode":"best"},
	{"id":"groups","stat":"groups","target":3,"ritual":26,"title":"CAPTURE 3 GRUPOS DE CIVIS","mode":"sum"},
	{"id":"rescues","stat":"rescues","target":10,"ritual":30,"title":"CAPTURE 10 PASSAGEIROS","mode":"sum"},
	{"id":"horde_large","stat":"horde","target":18,"ritual":32,"title":"FORME UMA HORDA DE 18","mode":"best"}
]

static func active_missions(tier: int) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var start=posmod(tier,6)*3
	var scale=1+int(tier/6)*.35
	for i in range(3):
		var item=MISSIONS[start+i].duplicate()
		item.target=ceili(float(item.target)*scale)
		item.title=str(item.title).replace(str(MISSIONS[start+i].target),str(item.target))
		item.key=str(tier)+":"+str(item.id)
		result.append(item)
	return result

static func defaults() -> Dictionary:
	return {"version":6,"audio_levels":{"music":.75,"effects":.85,"voices":1.0},"wallet":120,"best":0,"runs":0,"audio":true,"levels":{"horde":0,"jump":0,"magnet":0,"perk":0},"claimed":[],"owned":[0],"skin":0,"areas":[0,1],"power_owned":[3],"power_levels":{"fly_time":0,"mask_time":0,"mask_force":0,"mask_shield":0,"mask_size":0,"mask_revive":0},"mission_tier":0,"mission_progress":{},"missions_completed":0,"player_level":1,"level_souls":0,"best_souls":0,"total_souls":0,"active_souls":0,"ritual_progress":0,"ritual_pending":[],"ritual_ready":false}

static func upgrade_cost(item: Dictionary,level: int) -> int:
	return int(item.price)*(level+1)*(level+1)
