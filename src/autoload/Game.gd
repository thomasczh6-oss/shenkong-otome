extends Node
## 存档与数值：货币、好感、思念卡、剧情进度、保底、签到任务、月卡、通行证。
## 存档是一个 Dictionary（s），整体序列化为 user://save.json。

signal changed(what: String)

const SAVE_PATH := "user://save.json"
## 测试存档：调试菜单里切换，和主存档完全分开，不会覆盖主存档。
const TEST_SAVE_PATH := "user://save_test.json"
const SLOT_FILE := "user://slot.txt"

## 好感等级阈值与称呼（参考主流乙游的“亲密度”梯度）。
const AFF_THRESHOLDS := [0, 40, 100, 180, 280, 400, 550, 730, 940, 1180, 1450]
const AFF_NAMES := ["陌生", "初识", "熟悉", "信赖", "在意", "心动", "依恋", "倾心", "挚爱", "契约", "永恒"]

const SIGNIN_REWARDS := [
	{"diamonds": 100}, {"gold": 2000}, {"tickets_standard": 1}, {"diamonds": 150},
	{"gold": 3000}, {"tickets_limited": 1}, {"diamonds": 300},
]

const DAILY_TASKS := [
	{"id": "story", "name": "阅读 1 段剧情", "goal": 1, "reward": {"diamonds": 50, "xp": 25}},
	{"id": "battle", "name": "赢下 1 场战斗", "goal": 1, "reward": {"diamonds": 50, "xp": 25}},
	{"id": "chat", "name": "回复 1 条消息", "goal": 1, "reward": {"diamonds": 50, "xp": 25}},
	{"id": "pull", "name": "许愿 1 次", "goal": 1, "reward": {"diamonds": 50, "xp": 25}},
]

const PASS_MAX_LEVEL := 20
const PASS_XP_PER_LEVEL := 100
const CARD_MAX_LEVEL := 50
const BASE_STATS := {"hp": 1200, "atk": 90, "def": 30}

var s: Dictionary = {}
var save_path := SAVE_PATH


func _ready() -> void:
	if debug_enabled() and FileAccess.file_exists(SLOT_FILE) and FileAccess.get_file_as_string(SLOT_FILE).strip_edges() == "test":
		save_path = TEST_SAVE_PATH
	load_game()


func default_state() -> Dictionary:
	return {
		"version": 1,
		"player_name": "",
		"created_at": int(Time.get_unix_time_from_system()),
		"diamonds": 3000,
		"gold": 20000,
		"stardust": 0,
		"tickets": {"standard": 10, "limited": 5},
		"affection": {},
		"cards": {},
		"equipped": {},
		"story": {"done": {}, "unlocked": ["ch1"]},
		"pity": {},
		"signin": {"streak": 0, "last": ""},
		"tasks": {"date": "", "progress": {}, "claimed": {}},
		"chat": {},
		"moments": {"liked": {}},
		"month_card": {"until": 0, "last_claim": ""},
		"battle_pass": {"level": 1, "xp": 0, "claimed": [], "premium": false},
		"settings": {"text_speed": 1.0, "auto": false, "bgm_volume": 0.7, "voice_volume": 1.0},
		"stats": {"battles": 0, "wins": 0, "pulls": 0},
		"favorite": "shen_yan",
		"gallery": {},
		"dates": {"done": {}, "day": "", "today": {}},
		"tutorial": {},
		"battle_stars": {},
		"tower": {"best": 0},
		"hunt": {"date": "", "done": false},
		"bestiary": {},
	}


# ---------------- 存档 ----------------

func load_game() -> void:
	s = default_state()
	if FileAccess.file_exists(save_path):
		var f := FileAccess.open(save_path, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				for k in parsed.keys():
					s[k] = parsed[k]
	_refresh_daily()


func save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(s, "\t"))


func has_save() -> bool:
	return str(s.get("player_name", "")) != ""


func reset() -> void:
	s = default_state()
	var d := DirAccess.open("user://")
	var fname := save_path.get_file()
	if d != null and d.file_exists(fname):
		d.remove(fname)
	changed.emit("reset")


# ---------------- 调试（测试存档） ----------------

## 正式版把 project.godot 里的 application/config/debug_menu 改成 false 即可关掉调试入口。
func debug_enabled() -> bool:
	return bool(ProjectSettings.get_setting("application/config/debug_menu", false))


func is_test_slot() -> bool:
	return save_path == TEST_SAVE_PATH


## 切换主存档 / 测试存档。先把当前存档写盘，再读另一份。
func switch_slot(test: bool) -> void:
	if test == is_test_slot():
		return
	save()
	save_path = TEST_SAVE_PATH if test else SAVE_PATH
	var f := FileAccess.open(SLOT_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string("test" if test else "main")
	load_game()
	changed.emit("slot")


## 只在测试存档上生效：把 ch_id 之前的章节全部标记通关，并解锁 ch_id（"all" 解锁全部）。
func debug_unlock_to(ch_id: String) -> void:
	if not is_test_slot():
		return
	if str(s.get("player_name", "")) == "":
		s.player_name = "测试员"
	for t in ["home", "battle", "battle2"]:
		s.tutorial[t] = true
	var n := 0
	for ch in Data.chapters:
		var cid := str(ch.id)
		n += 1
		if not s.story.unlocked.has(cid):
			s.story.unlocked.append(cid)
		if cid == ch_id:
			break
		for sc in ch.scenes:
			s.story.done[scene_key(cid, str(sc.id))] = true
	_debug_power_for_chapter(n)
	save()
	changed.emit("debug")


## 把测试号的养成拉到「正常玩到第 n 章」的大致水平：每位男主两张 4★ 思念，
## 等级 1 + 6×(n-1)（第四章约 19 级），好感约 Lv.2 + n，并装备这两张。
func _debug_power_for_chapter(n: int) -> void:
	var lv := 1 + 6 * (n - 1)
	for cid in Data.char_order:
		var picks: Array = []
		for card_id in Data.card_order:
			var c: Dictionary = Data.cards[card_id]
			if str(c.char) == cid and int(c.rarity) == 4:
				picks.append(card_id)
		for card_id in picks.slice(0, 2):
			if not owns(card_id):
				s.cards[card_id] = {"level": 1, "dup": 0}
			s.cards[card_id]["level"] = maxi(card_level(card_id), lv)
		s.equipped[cid] = picks.slice(0, 2)
		var aff_target: int = AFF_THRESHOLDS[mini(AFF_THRESHOLDS.size() - 1, 1 + n)]
		s.affection[cid] = maxi(affection(cid), aff_target)


func debug_add_resources() -> void:
	if not is_test_slot():
		return
	s.diamonds = int(s.diamonds) + 20000
	s.gold = int(s.get("gold", 0)) + 200000
	s.stardust = int(s.get("stardust", 0)) + 2000
	s.tickets.standard = int(s.tickets.get("standard", 0)) + 50
	s.tickets.limited = int(s.tickets.get("limited", 0)) + 50
	save()
	changed.emit("debug")


func player_name() -> String:
	var n := str(s.get("player_name", ""))
	return n if n != "" else "观测员"


func set_player_name(n: String) -> void:
	s.player_name = n.strip_edges().substr(0, 10)
	save()
	changed.emit("name")


# ---------------- 货币 ----------------

func diamonds() -> int:
	return int(s.diamonds)


func gold() -> int:
	return int(s.gold)


func stardust() -> int:
	return int(s.stardust)


func tickets(pool: String) -> int:
	return int(s.tickets.get(pool, 0))


func grant(reward: Dictionary) -> void:
	for k in reward.keys():
		var v := int(reward[k])
		match k:
			"diamonds":
				s.diamonds = diamonds() + v
			"gold":
				s.gold = gold() + v
			"stardust":
				s.stardust = stardust() + v
			"tickets_standard":
				s.tickets["standard"] = tickets("standard") + v
			"tickets_limited":
				s.tickets["limited"] = tickets("limited") + v
			"xp":
				add_pass_xp(v)
	changed.emit("currency")
	save()


func spend(kind: String, amount: int) -> bool:
	var have := 0
	match kind:
		"diamonds":
			have = diamonds()
		"gold":
			have = gold()
		"stardust":
			have = stardust()
	if have < amount:
		return false
	s[kind] = have - amount
	changed.emit("currency")
	save()
	return true


# ---------------- 好感 ----------------

func affection(cid: String) -> int:
	return int(s.affection.get(cid, 0))


func affection_level(cid: String) -> int:
	var pts := affection(cid)
	var lv := 1
	for i in AFF_THRESHOLDS.size():
		if pts >= int(AFF_THRESHOLDS[i]):
			lv = i + 1
	return lv


func affection_name(cid: String) -> String:
	return AFF_NAMES[mini(affection_level(cid), AFF_NAMES.size()) - 1]


## 返回 [当前等级内已积累, 本级所需]。
func affection_progress(cid: String) -> Array:
	var lv := affection_level(cid)
	if lv >= AFF_THRESHOLDS.size():
		return [1, 1]
	var lo := int(AFF_THRESHOLDS[lv - 1])
	var hi := int(AFF_THRESHOLDS[lv])
	return [affection(cid) - lo, hi - lo]


## 返回是否升级。
func add_affection(cid: String, pts: int) -> bool:
	var before := affection_level(cid)
	s.affection[cid] = affection(cid) + pts
	var leveled := affection_level(cid) > before
	changed.emit("affection")
	save()
	return leveled


# ---------------- 思念卡 ----------------

func owns(card_id: String) -> bool:
	return s.cards.has(card_id)


func card_level(card_id: String) -> int:
	return int(s.cards.get(card_id, {}).get("level", 0))


## 获得一张卡；重复则转为星屑。返回是否为新卡。
func add_card(card_id: String) -> bool:
	var card: Dictionary = Data.cards.get(card_id, {})
	if owns(card_id):
		s.cards[card_id]["dup"] = int(s.cards[card_id].get("dup", 0)) + 1
		var r := str(int(card.get("rarity", 3)))
		s.stardust = stardust() + int(Data.gacha.get("dup_stardust", {}).get(r, 5))
		return false
	s.cards[card_id] = {"level": 1, "dup": 0}
	var cid := str(card.get("char", ""))
	var eq: Array = equipped(cid)
	if eq.size() < 2:
		eq.append(card_id)
		s.equipped[cid] = eq
	changed.emit("cards")
	return true


func card_stats(card_id: String) -> Dictionary:
	var c: Dictionary = Data.cards.get(card_id, {})
	var lv := maxi(card_level(card_id), 1)
	var m := 1.0 + 0.08 * float(lv - 1)
	return {
		"hp": int(float(c.get("hp", 0)) * m),
		"atk": int(float(c.get("atk", 0)) * m),
		"def": int(float(c.get("def", 0)) * m),
	}


func upgrade_cost(card_id: String) -> int:
	return 400 * maxi(card_level(card_id), 1)


func upgrade_card(card_id: String) -> bool:
	if not owns(card_id) or card_level(card_id) >= CARD_MAX_LEVEL:
		return false
	var cost := upgrade_cost(card_id)
	if gold() < cost:
		return false
	s.gold = gold() - cost
	s.cards[card_id]["level"] = card_level(card_id) + 1
	changed.emit("cards")
	save()
	return true


func equipped(cid: String) -> Array:
	return Array(s.equipped.get(cid, []))


func is_equipped(card_id: String) -> bool:
	var c: Dictionary = Data.cards.get(card_id, {})
	return equipped(str(c.get("char", ""))).has(card_id)


## 装备 / 卸下，返回提示文案。
func toggle_equip(card_id: String) -> String:
	var c: Dictionary = Data.cards.get(card_id, {})
	var cid := str(c.get("char", ""))
	var eq: Array = equipped(cid)
	if eq.has(card_id):
		eq.erase(card_id)
		s.equipped[cid] = eq
		save()
		changed.emit("cards")
		return "已卸下"
	if eq.size() >= 2:
		eq.pop_front()
	eq.append(card_id)
	s.equipped[cid] = eq
	save()
	changed.emit("cards")
	return "已装备"


## 与某位搭档并肩作战时的面板：基础 + 装备卡 + 好感加成（每级 2%）。
func team_stats(cid: String) -> Dictionary:
	var hp := float(BASE_STATS.hp)
	var atk := float(BASE_STATS.atk)
	var def := float(BASE_STATS.def)
	for card_id in equipped(cid):
		var st := card_stats(card_id)
		hp += st.hp
		atk += st.atk
		def += st.def
	var bonus := 1.0 + 0.02 * float(affection_level(cid) - 1)
	return {"hp": int(hp * bonus), "atk": int(atk * bonus), "def": int(def * bonus)}


func power(cid: String) -> int:
	var st := team_stats(cid)
	return int(st.atk * 4 + st.hp / 4.0 + st.def * 3)


# ---------------- 剧情 ----------------

func scene_key(ch_id: String, scene_id: String) -> String:
	return ch_id + "/" + scene_id


func scene_done(ch_id: String, scene_id: String) -> bool:
	return s.story.done.has(scene_key(ch_id, scene_id))


func mark_scene_done(ch_id: String, scene_id: String) -> bool:
	var first := not scene_done(ch_id, scene_id)
	s.story.done[scene_key(ch_id, scene_id)] = true
	task_progress("story")
	save()
	changed.emit("story")
	return first


func chapter_unlocked(ch_id: String) -> bool:
	return s.story.unlocked.has(ch_id)


func unlock_chapter(ch_id: String) -> void:
	if not chapter_unlocked(ch_id):
		s.story.unlocked.append(ch_id)
		save()


func chapter_progress(ch_id: String) -> Array:
	var scenes: Array = Data.chapter(ch_id).get("scenes", [])
	var done := 0
	for sc in scenes:
		if scene_done(ch_id, str(sc.id)):
			done += 1
	return [done, scenes.size()]


# ---------------- 回忆（剧情 CG） ----------------

func cg_unlocked(key: String) -> bool:
	return s.gallery.has(key)


## 返回是否首次解锁。
func unlock_cg(key: String) -> bool:
	if cg_unlocked(key):
		return false
	s.gallery[key] = int(Time.get_unix_time_from_system())
	save()
	changed.emit("gallery")
	return true


# ---------------- 约会 ----------------

func date_unlocked(d: Dictionary) -> bool:
	return affection_level(str(d.get("char", ""))) >= int(d.get("level", 1))


func date_done_ever(id: String) -> bool:
	return s.dates.done.has(id)


func dated_today(cid: String) -> bool:
	return str(s.dates.get("day", "")) == today() and s.dates.today.has(cid)


func can_date(d: Dictionary) -> bool:
	return date_unlocked(d) and not dated_today(str(d.get("char", "")))


## 约会结束结算：每次 +好感，首次再给钻石。返回 {first, affection, reward, leveled}。
func finish_date(id: String) -> Dictionary:
	var d := Data.date(id)
	if d.is_empty():
		return {}
	var cid := str(d.char)
	if str(s.dates.get("day", "")) != today():
		s.dates.day = today()
		s.dates.today = {}
	s.dates.today[cid] = id
	var first := not date_done_ever(id)
	s.dates.done[id] = int(s.dates.done.get(id, 0)) + 1
	var aff := int(Data.dates_cfg.get("daily_affection", 15))
	var leveled := add_affection(cid, aff)
	var reward: Dictionary = Data.dates_cfg.get("first_reward", {}) if first else {}
	if reward.size() > 0:
		grant(reward)
	save()
	return {"first": first, "affection": aff, "reward": reward, "leveled": leveled}


# ---------------- 新手引导 ----------------

func tutorial_done(step: String) -> bool:
	return bool(s.tutorial.get(step, false))


func mark_tutorial(step: String) -> void:
	s.tutorial[step] = true
	save()


# ---------------- 日常 ----------------

func today() -> String:
	return Time.get_date_string_from_system()


func _refresh_daily() -> void:
	if str(s.tasks.get("date", "")) != today():
		s.tasks = {"date": today(), "progress": {}, "claimed": {}}


func can_signin() -> bool:
	return str(s.signin.get("last", "")) != today()


func signin_day() -> int:
	return int(s.signin.get("streak", 0)) % 7


func do_signin() -> Dictionary:
	if not can_signin():
		return {}
	var reward: Dictionary = SIGNIN_REWARDS[signin_day()]
	s.signin.last = today()
	s.signin.streak = int(s.signin.get("streak", 0)) + 1
	grant(reward)
	return reward


func task_progress(id: String, n := 1) -> void:
	_refresh_daily()
	s.tasks.progress[id] = int(s.tasks.progress.get(id, 0)) + n
	changed.emit("tasks")
	save()


func task_state(task: Dictionary) -> Dictionary:
	_refresh_daily()
	var id := str(task.id)
	var p := int(s.tasks.progress.get(id, 0))
	return {
		"progress": mini(p, int(task.goal)),
		"goal": int(task.goal),
		"done": p >= int(task.goal),
		"claimed": s.tasks.claimed.has(id),
	}


func claim_task(task: Dictionary) -> Dictionary:
	var st := task_state(task)
	if not st.done or st.claimed:
		return {}
	s.tasks.claimed[str(task.id)] = true
	grant(task.reward)
	return task.reward


# ---------------- 月卡 / 通行证 ----------------

func month_card_active() -> bool:
	return int(s.month_card.get("until", 0)) > int(Time.get_unix_time_from_system())


func month_card_days_left() -> int:
	var left := int(s.month_card.get("until", 0)) - int(Time.get_unix_time_from_system())
	return maxi(0, int(ceil(float(left) / 86400.0)))


func buy_month_card(days := 30, instant := 300) -> void:
	var now := int(Time.get_unix_time_from_system())
	var base := maxi(now, int(s.month_card.get("until", 0)))
	s.month_card.until = base + days * 86400
	grant({"diamonds": instant})


func month_card_claimable() -> bool:
	return month_card_active() and str(s.month_card.get("last_claim", "")) != today()


func claim_month_card(daily := 100) -> bool:
	if not month_card_claimable():
		return false
	s.month_card.last_claim = today()
	grant({"diamonds": daily})
	return true


func add_pass_xp(v: int) -> void:
	var bp: Dictionary = s.battle_pass
	bp.xp = int(bp.get("xp", 0)) + v
	while int(bp.xp) >= PASS_XP_PER_LEVEL and int(bp.level) < PASS_MAX_LEVEL:
		bp.xp = int(bp.xp) - PASS_XP_PER_LEVEL
		bp.level = int(bp.level) + 1
	changed.emit("pass")


func pass_reward(level: int, premium: bool) -> Dictionary:
	if premium:
		return {"tickets_limited": 1} if level % 5 == 0 else {"diamonds": 80}
	return {"diamonds": 150} if level % 5 == 0 else {"gold": 1500}


func pass_claimed(level: int, premium: bool) -> bool:
	return s.battle_pass.claimed.has("%s_%d" % ["p" if premium else "f", level])


func claim_pass(level: int, premium: bool) -> Dictionary:
	if level > int(s.battle_pass.level) or pass_claimed(level, premium):
		return {}
	if premium and not bool(s.battle_pass.get("premium", false)):
		return {}
	s.battle_pass.claimed.append("%s_%d" % ["p" if premium else "f", level])
	var r := pass_reward(level, premium)
	grant(r)
	return r


# ---------------- 聊天 / 瞬间 ----------------

func chat_state(cid: String) -> Dictionary:
	if not s.chat.has(cid):
		s.chat[cid] = {"index": 0, "log": []}
	return s.chat[cid]


func moment_liked(mid: String) -> bool:
	return s.moments.liked.has(mid)


func like_moment(mid: String) -> void:
	s.moments.liked[mid] = true
	save()


# ---------------- 战斗进度 ----------------

func battle_stars(key: String) -> int:
	return int(s.get("battle_stars", {}).get(key, 0))


## 记录星级，返回首次达成三星时的额外奖励（没有则为空）。
func record_stars(key: String, n: int) -> Dictionary:
	if key == "":
		return {}
	if not s.has("battle_stars"):
		s.battle_stars = {}
	var old := battle_stars(key)
	if n > old:
		s.battle_stars[key] = n
	if n >= 3 and old < 3:
		var bonus := {"diamonds": 30}
		grant(bonus)
		return bonus
	save()
	return {}


func total_stars() -> int:
	var t := 0
	for k in s.get("battle_stars", {}):
		t += int(s.battle_stars[k])
	return t


func mark_seen(enemy_id: String) -> void:
	if not s.has("bestiary"):
		s.bestiary = {}
	s.bestiary[enemy_id] = true


func tower_best() -> int:
	return int(s.get("tower", {}).get("best", 0))


## 通关某层：第一次通关返回 true（发首通奖励）。
func clear_tower(floor_n: int) -> bool:
	if not s.has("tower"):
		s.tower = {"best": 0}
	if floor_n > tower_best():
		s.tower.best = floor_n
		save()
		return true
	return false


func hunt_done_today() -> bool:
	var h: Dictionary = s.get("hunt", {})
	return str(h.get("date", "")) == today() and bool(h.get("done", false))


func mark_hunt_done() -> void:
	s.hunt = {"date": today(), "done": true}
	save()

