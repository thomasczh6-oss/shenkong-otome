extends RefCounted
## 战斗规则（纯逻辑，方便测试）：属性克制、敌人招式、星级、潮汐回廊和每日讨伐。

## 克制关系：潮克焰，焰克星，星克潮。
const BEATS := {"潮": "焰", "焰": "星", "星": "潮"}

## 敌人招式。tele = 预警时长；mult = 伤害倍率（乘敌人攻击）。
const MOVES := {
	"hit": {"name": "攻击", "tele": 0.9, "mult": 1.0},
	"heavy": {"name": "重击", "tele": 1.5, "mult": 2.2},
	"combo": {"name": "连击", "tele": 1.0, "mult": 0.6, "hits": 3, "gap": 0.32},
	"shield": {"name": "护盾", "tele": 0.7, "shield": 0.16},
	"charge": {"name": "蓄力", "tele": 4.0, "mult": 3.0, "break": 0.09},
	"heal": {"name": "回复", "tele": 1.0, "heal": 0.07},
}

const PERFECT_WINDOW := 0.4  # 出手前这么多秒内闪避 = 完美闪避
const TOWER_FLOORS := 30


static func element_mult(attacker: String, defender: String) -> float:
	if attacker == "" or defender == "":
		return 1.0
	if BEATS.get(attacker, "") == defender:
		return 1.5
	if BEATS.get(defender, "") == attacker:
		return 0.75
	return 1.0


## 克制 el 的属性。
static func weakness(el: String) -> String:
	for k in BEATS:
		if BEATS[k] == el:
			return k
	return ""


static func move(id: String) -> Dictionary:
	return MOVES.get(id, MOVES.hit)


## 招式显示名：敌人自己的招式名优先。
static func move_name(enemy: Dictionary, id: String) -> String:
	var names: Dictionary = enemy.get("skill_names", {})
	return str(names.get(id, move(id).name))


## 1 星：胜利；2 星：剩余血量 ≥ 50%；3 星：再加至少一次完美闪避。
static func stars(win: bool, hp_ratio: float, perfect_dodges: int) -> int:
	if not win:
		return 0
	var n := 1
	if hp_ratio >= 0.5:
		n += 1
		if perfect_dodges >= 1:
			n += 1
	return n


## 回廊用的敌人顺序：普通敌人按血量从低到高，每 5 层换成 Boss。
static func roster(enemies: Dictionary) -> Dictionary:
	var normal: Array = []
	var bosses: Array = []
	for id in enemies:
		var e: Dictionary = enemies[id]
		if bool(e.get("boss", false)):
			bosses.append(id)
		else:
			normal.append(id)
	var by_hp := func(a, b) -> bool: return float(enemies[a].hp) < float(enemies[b].hp)
	normal.sort_custom(by_hp)
	bosses.sort_custom(by_hp)
	return {"normal": normal, "boss": bosses}


static func tower_floor(n: int, enemies: Dictionary) -> Dictionary:
	var r := roster(enemies)
	var boss := n % 5 == 0
	var pool: Array = r.boss if boss else r.normal
	var idx := (n / 5 - 1) if boss else (n - 1 - n / 5)
	var id: String = pool[posmod(idx, pool.size())]
	var e: Dictionary = enemies[id]
	# 让第 1 层大约等于 900 血的潮影，之后每层 +9%
	var base_hp := float(e.hp)
	var target := 900.0 * pow(1.09, n - 1) * (1.6 if boss else 1.0)
	var hp_mult := target / base_hp
	return {
		"floor": n,
		"enemy": id,
		"boss": boss,
		"hp_mult": hp_mult,
		"atk_mult": pow(1.06, n - 1) * 60.0 / float(e.atk) * (1.15 if boss else 1.0),
		"reward": {"gold": 400 + 120 * n, "diamonds": 40 if boss else 15, "stardust": 10 * n if boss else 0},
	}


## 每日讨伐：按日期挑一个 Boss，所有人当天一样。
static func daily_enemy(date: String, enemies: Dictionary) -> String:
	var r := roster(enemies)
	var pool: Array = r.boss
	if pool.is_empty():
		pool = r.normal
	return str(pool[absi(date.hash()) % pool.size()])
