class_name MonsterCatalog
extends RefCounted

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

static func defaults() -> Dictionary:
	return {"version":1,"wallet":120,"best":0,"runs":0,"audio":true,"levels":{"horde":0,"jump":0,"magnet":0,"perk":0},"claimed":[]}

static func upgrade_cost(item: Dictionary,level: int) -> int:
	return int(item.price)*(level+1)
