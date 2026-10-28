extends Node
## 无头逻辑测试：godot --headless --path . -- --test
## 覆盖：数据完整性、抽卡概率与保底、好感等级、存档往返。退出码非 0 表示失败。

const Gacha := preload("res://src/systems/Gacha.gd")

var failures := 0
var checks := 0


func _ready() -> void:
	await get_tree().process_frame
	Game.s = Game.default_state()
	_test_data()
	_test_affection()
	_test_gacha()
	_test_save()
	_test_story()
	_test_dates()
	_test_audio()
	await _test_fonts()
	await _test_drag_scroll()
	_test_combat_rules()
	await _test_battle_sim()
	await _test_challenge_flow()
	_test_debug_slot()
	print("\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _test_data() -> void:
	print("[数据完整性]")
	check(Data.char_order.size() == 3, "3 位男主")
	check(Data.card_order.size() == 21, "21 张思念卡（实际 %d）" % Data.card_order.size())
	for id in Data.card_order:
		var c: Dictionary = Data.cards[id]
		check(Data.characters.has(c.char), "卡 %s 的角色存在" % id)
		check(int(c.rarity) in [3, 4, 5], "卡 %s 稀有度合法" % id)
	for pid in Data.gacha.pools.keys():
		for fid in Data.gacha.pools[pid].featured:
			check(Data.cards.has(fid) and int(Data.cards[fid].rarity) == 5, "UP 卡 %s 是 5★" % fid)
	var manifest_keys: Array = Data.manifest_keys()
	check(manifest_keys.size() > 40, "美术清单已生成（%d 项）" % manifest_keys.size())
	for ch in Data.chapters:
		for sc in ch.scenes:
			check(manifest_keys.has(str(sc.bg)), "场景 %s/%s 的背景在清单里" % [ch.id, sc.id])
			for line in sc.lines:
				var t := str(line.get("t", "say"))
				if t == "say":
					var who := str(line.who)
					check(who in ["narrator", "me"] or Data.characters.has(who) or (who == "npc" and str(line.get("name", "")) != ""), "说话人 %s 存在" % who)
				elif t == "battle":
					check(Data.enemies.has(str(line.enemy)), "敌人 %s 存在" % line.enemy)
					check(Data.characters.has(str(line.partner)) or str(line.partner) == "auto", "搭档 %s 存在" % line.partner)
				elif t == "cg":
					check(manifest_keys.has(str(line.key)), "CG %s 在清单里" % line.key)
				elif t == "bg":
					check(manifest_keys.has(str(line.key)), "背景 %s 在清单里" % line.key)
				elif t == "choice":
					check(line.options.size() >= 2, "选项数 ≥ 2")
	for cid in Data.char_order:
		check(Data.chats.has(cid), "%s 有短信脚本" % cid)
		check(Data.calls.has(cid), "%s 有电话脚本" % cid)
		for expr in ["calm", "smile", "shy", "serious"]:
			check(manifest_keys.has("characters/%s/%s" % [cid, expr]), "%s 的 %s 立绘在清单里" % [cid, expr])
	for id in Data.card_order:
		check(manifest_keys.has("cards/" + id), "卡 %s 的插画在清单里" % id)


func _test_affection() -> void:
	print("[好感]")
	Game.s = Game.default_state()
	check(Game.affection_level("shen_yan") == 1, "初始 Lv.1")
	var leveled := Game.add_affection("shen_yan", 45)
	check(leveled and Game.affection_level("shen_yan") == 2, "45 点升到 Lv.2")
	var prog := Game.affection_progress("shen_yan")
	check(prog[0] == 5 and prog[1] == 60, "进度 5/60（实际 %d/%d）" % [prog[0], prog[1]])
	Game.s.affection["shen_yan"] = 99999
	check(Game.affection_level("shen_yan") == Game.AFF_THRESHOLDS.size(), "封顶等级")


func _test_gacha() -> void:
	print("[抽卡]")
	seed(12345)
	Game.s = Game.default_state()
	Game.s.diamonds = 100000000
	var n := 20000
	var count := {3: 0, 4: 0, 5: 0}
	var gap5 := 0
	var max_gap5 := 0
	var gap4 := 0
	var max_gap4 := 0
	var last5_featured := true
	var guarantee_ok := true
	var featured: Array = Data.gacha.pools.limited.featured
	for i in n:
		var r := Gacha.pull_one("limited")
		count[int(r.rarity)] += 1
		gap5 += 1
		gap4 += 1
		if int(r.rarity) == 5:
			max_gap5 = maxi(max_gap5, gap5)
			gap5 = 0
			gap4 = 0
			var is_feat := featured.has(r.card)
			if not last5_featured and not is_feat:
				guarantee_ok = false
			last5_featured = is_feat
		elif int(r.rarity) == 4:
			max_gap4 = maxi(max_gap4, gap4)
			gap4 = 0
	var rate5 := float(count[5]) / n
	var rate4 := float(count[4]) / n
	check(rate5 > 0.013 and rate5 < 0.025, "5★ 综合概率 %.2f%%（含保底，应在 1.3%%–2.5%%）" % (rate5 * 100))
	check(rate4 > 0.08 and rate4 < 0.15, "4★ 综合概率 %.2f%%" % (rate4 * 100))
	check(max_gap5 <= 70, "5★ 最长间隔 %d ≤ 70" % max_gap5)
	check(max_gap4 <= 10, "4★ 最长间隔 %d ≤ 10" % max_gap4)
	check(guarantee_ok, "歪了之后下一次 5★ 必为 UP")
	Game.s = Game.default_state()
	var leaked := false
	for i in 3000:
		var r := Gacha.pull_one("standard")
		if bool(Data.cards[r.card].get("limited", false)):
			leaked = true
	check(not leaked, "常驻池不掉限定卡")
	Game.s = Game.default_state()
	Game.s.tickets.limited = 3
	Game.s.diamonds = 2000
	var res := Gacha.pull("limited", 10)
	check(res.ok and res.tickets_used == 3 and res.diamonds_used == 1050, "十连扣费：3 券 + 1050 钻")
	check(Game.diamonds() == 950, "剩余钻石 950（实际 %d）" % Game.diamonds())
	var res2 := Gacha.pull("limited", 10)
	check(not res2.ok, "钻石不足时拒绝")
	check(Game.stardust() >= 0, "星屑非负")
	check(int(Game.s.tasks.progress.get("pull", 0)) == 10, "许愿计入每日任务")


func _test_save() -> void:
	print("[存档]")
	Game.s = Game.default_state()
	Game.set_player_name("测试员")
	Game.add_card("gu_ci_5_1")
	Game.add_card("gu_ci_5_1")
	check(int(Game.s.cards["gu_ci_5_1"].dup) == 1 and Game.stardust() == 100, "重复 5★ 转 100 星屑")
	check(Game.equipped("gu_ci").has("gu_ci_5_1"), "新卡自动装备")
	Game.save()
	Game.load_game()
	check(Game.player_name() == "测试员", "存档往返：名字")
	check(Game.owns("gu_ci_5_1") and Game.card_level("gu_ci_5_1") == 1, "存档往返：卡")
	check(Game.upgrade_card("gu_ci_5_1") and Game.card_level("gu_ci_5_1") == 2, "升级卡")
	var st := Game.card_stats("gu_ci_5_1")
	check(st.atk == 97, "Lv.2 攻击 97（实际 %d）" % st.atk)
	var team := Game.team_stats("gu_ci")
	check(team.atk > Game.BASE_STATS.atk, "装备卡提升面板")
	var r := Game.do_signin()
	check(r.size() > 0 and not Game.can_signin(), "签到一次后当天不可再签")
	Game.reset()
	check(not Game.has_save(), "清档")


func _test_story() -> void:
	print("[剧情与回忆]")
	Game.s = Game.default_state()
	check(Data.chapters.size() >= 2, "至少 2 章")
	check(Data.chapter("ch2").get("scenes", []).size() == 5, "第二章 5 节")
	check(Data.chapter("ch3").get("scenes", []).size() == 5 and str(Data.chapter("ch3").get("requires", "")) == "ch2", "第三章 5 节，完成第二章后解锁")
	check(Data.chapter("ch4").get("scenes", []).size() == 5 and str(Data.chapter("ch4").get("requires", "")) == "ch3", "第四章 5 节，完成第三章后解锁")
	var ch4_enemies := {}
	for sc in Data.chapter("ch4").get("scenes", []):
		for line in sc.lines:
			if str(line.get("t", "")) == "battle":
				ch4_enemies[str(line.enemy)] = true
	check(ch4_enemies.size() == 5, "第四章 5 场战斗都是新敌人（%d）" % ch4_enemies.size())
	check(Data.enemy("zero_lock").has("phase2"), "第四章 Boss 零号之锁有第二形态")
	var bgms: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio.json")).get("bgm", {})
	for ch in Data.chapters:
		for sc in ch.scenes:
			if sc.has("bgm"):
				check(bgms.has(str(sc.bgm)), "%s/%s 的 BGM %s 在 audio.json 里" % [ch.id, sc.id, sc.bgm])
	var vid_cards := 0
	for id in Data.card_order:
		if Data.card_video(id) != null:
			vid_cards += 1
			check(int(Data.cards[id].rarity) == 5, "动态思念 %s 是 5★" % id)
	print("    动态思念 %d 张" % vid_cards)
	var cgs: Array = Data.cg_list()
	check(cgs.size() >= 7, "剧情 CG ≥ 7 张（实际 %d）" % cgs.size())
	var seen := {}
	for e in cgs:
		check(not seen.has(e.key), "CG %s 不重复" % e.key)
		seen[e.key] = true
	var k := str(cgs[0].key)
	check(not Game.cg_unlocked(k), "CG 初始未解锁")
	check(Game.unlock_cg(k) and Game.cg_unlocked(k), "首次解锁 CG")
	check(not Game.unlock_cg(k), "重复解锁返回 false")
	# 每个 cg 段落都要能在本节内收尾（cg_end 前必须有 cg）
	for ch in Data.chapters:
		for sc in ch.scenes:
			var open := false
			var ok := true
			for line in sc.lines:
				var t := str(line.get("t", ""))
				if t == "cg":
					open = true
				elif t == "cg_end":
					ok = ok and open
					open = false
			check(ok, "%s/%s 的 cg_end 成对" % [ch.id, sc.id])


func _test_dates() -> void:
	print("[约会]")
	var keys: Array = Data.manifest_keys()
	check(Data.dates.size() == 9, "9 个约会（实际 %d）" % Data.dates.size())
	for cid in Data.char_order:
		check(Data.dates_of(cid).size() == 3, "%s 有 3 个约会" % cid)
	for d in Data.dates:
		check(keys.has(str(d.bg)), "约会 %s 的背景在清单里" % d.id)
		var touches := 0
		for line in d.lines:
			var t := str(line.get("t", "say"))
			if t == "touch":
				touches += 1
				check(line.spots.size() >= 2, "约会 %s 的触碰点 ≥ 2" % d.id)
			elif t == "cg":
				check(keys.has(str(line.key)), "约会 CG %s 在清单里" % line.key)
			elif t == "say":
				check(str(line.who) in ["narrator", "me"] or Data.characters.has(str(line.who)), "约会 %s 说话人存在" % d.id)
		check(touches == 1, "约会 %s 有一段触碰互动" % d.id)
	Game.s = Game.default_state()
	var d1: Dictionary = Data.date("shen_yan_1")
	var d3: Dictionary = Data.date("shen_yan_3")
	check(not Game.date_unlocked(d1), "好感 Lv.1 时约会未解锁")
	Game.s.affection["shen_yan"] = 40
	check(Game.can_date(d1) and not Game.date_unlocked(d3), "Lv.2 解锁第一个约会，第三个仍锁着")
	var dia := Game.diamonds()
	var res := Game.finish_date("shen_yan_1")
	check(res.first and Game.diamonds() == dia + 100, "首次约会奖励 100 钻")
	check(Game.affection("shen_yan") == 55, "约会 +15 好感（实际 %d）" % Game.affection("shen_yan"))
	check(Game.dated_today("shen_yan") and not Game.can_date(d1), "当天不能再约")
	check(Game.can_date(Data.date("gu_ci_1")) == false, "顾辞好感不够仍不能约")
	Game.s.dates.day = "2000-01-01"
	check(Game.can_date(d1), "跨天后可以再约")
	var res2 := Game.finish_date("shen_yan_1")
	check(not res2.first and res2.reward.is_empty(), "重复约会不再给首次奖励")


func _test_audio() -> void:
	print("[声音]")
	check(Audio.voice_id("shen_yan", "退后。") == "243e8e11fbf27341", "配音文件名算法与 gen_audio.py 一致")
	# 统计男主台词的配音覆盖率（配音缺失不报错，只是静音）
	var n := {"total": 0, "voiced": 0}  # lambda 按值捕获局部变量，所以用字典计数
	var walk := func(lines: Array, f: Callable) -> void:
		for line in lines:
			var t := str(line.get("t", "say"))
			if t == "say" and Data.characters.has(str(line.get("who", ""))):
				n.total += 1
				if Audio.has_voice(str(line.who), str(line.text)):
					n.voiced += 1
			elif t == "choice":
				for o in line.options:
					f.call(o.get("lines", []), f)
	for ch in Data.chapters:
		for sc in ch.scenes:
			walk.call(sc.lines, walk)
	for d in Data.dates:
		walk.call(d.lines, walk)
	print("    男主台词 %d 句，有配音 %d 句" % [n.total, n.voiced])
	check(n.total > 100, "男主台词数量 > 100")
	for cid in Data.char_order:
		check(str(Data.character(cid).get("voice", {}).get("id", "")) != "", "%s 配置了音色" % cid)


## 弹窗挂在 CanvasLayer 下，拿不到 root 主题；必须也用中文字体，否则真机上是方块。
func _test_fonts() -> void:
	check(UIKit.font != null, "加载到中文字体")
	check(UIKit.font.has_char("观".unicode_at(0)), "字体包含常用汉字")
	var layer := CanvasLayer.new()
	add_child(layer)
	var lbl := Label.new()
	layer.add_child(lbl)
	var edit := LineEdit.new()
	layer.add_child(edit)
	await get_tree().process_frame
	check(lbl.get_theme_font("font") == UIKit.font, "CanvasLayer 下的 Label 用中文字体")
	check(edit.get_theme_font("font") == UIKit.font, "CanvasLayer 下的输入框用中文字体")
	layer.queue_free()
	# 代码和数据里出现的所有字符，打包的字体里都要有（真机上没有系统字体兜底）
	var missing := {}
	for dir in ["res://src/screens", "res://src/autoload", "res://data"]:
		for f in DirAccess.get_files_at(dir):
			if not (f.ends_with(".gd") or f.ends_with(".json")):
				continue
			var txt := FileAccess.get_file_as_string(dir.path_join(f))
			for i in txt.length():
				var c := txt.unicode_at(i)
				if c > 127 and not UIKit.font.has_char(c):
					missing[String.chr(c)] = f
	check(missing.is_empty(), "所有文字都在打包字体里 %s" % str(missing))


func _mouse(pos: Vector2, pressed: Variant = null) -> void:
	var ev: InputEvent
	if pressed == null:
		var mm := InputEventMouseMotion.new()
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		ev = mm
	else:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		ev = mb
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input(ev, true)
	await get_tree().process_frame


## 手指按在按钮上往上拖，列表要滚动，而且松手不能触发按钮；轻点按钮仍然能点。
func _test_drag_scroll() -> void:
	var host := Control.new()
	host.position = Vector2.ZERO
	host.size = Vector2(1080, 900)
	add_child(host)
	var v := UIKit.vbox(10)
	var taps := {"n": 0}
	for i in 30:
		var b := UIKit.button("条目 %d" % i, "ghost", 30, 120)
		b.pressed.connect(func() -> void: taps.n += 1)
		v.add_child(b)
	var sc := UIKit.scroll(v)
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(sc)
	await get_tree().process_frame
	await get_tree().process_frame
	await _mouse(Vector2(540, 700), true)
	for i in 10:
		await _mouse(Vector2(540, 700 - 40 * (i + 1)))
	await _mouse(Vector2(540, 300), false)
	check(sc.scroll_vertical >= 300, "手指拖动能滚动列表（滚动了 %d）" % sc.scroll_vertical)
	check(taps.n == 0, "拖动松手不会误点按钮")
	sc.set_process(false)
	await _mouse(Vector2(540, 450), true)
	await _mouse(Vector2(540, 450), false)
	check(taps.n == 1, "轻点按钮仍然有效")
	host.queue_free()


const CombatRules := preload("res://src/systems/Combat.gd")


func _test_combat_rules() -> void:
	var fresh := {"hp": 1200, "atk": 90, "def": 30}
	var strong := {"hp": 9000, "atk": 900, "def": 300}
	for bid in CombatRules.roster(Data.enemies).boss:
		var be: Dictionary = Data.enemy(bid)
		var fs: Dictionary = CombatRules.hunt_scale(fresh, be)
		var hit := maxf(5.0, 90.0 - float(be.def) * 0.5)
		check(float(be.hp) * fs.hp_mult / hit <= 40.0, "新手讨伐 %s 约 %d 下普攻可打完" % [bid, int(float(be.hp) * fs.hp_mult / hit)])
		var ss: Dictionary = CombatRules.hunt_scale(strong, be)
		check(is_equal_approx(ss.hp_mult, 1.4) and is_equal_approx(ss.atk_mult, 1.1), "高战力讨伐 %s 封顶为强化版" % bid)
	check(CombatRules.element_mult("潮", "焰") == 1.5, "潮克焰")
	check(CombatRules.element_mult("焰", "星") == 1.5, "焰克星")
	check(CombatRules.element_mult("星", "潮") == 1.5, "星克潮")
	check(CombatRules.element_mult("焰", "潮") == 0.75, "被克制伤害降低")
	check(CombatRules.element_mult("潮", "潮") == 1.0, "同属性无加成")
	check(CombatRules.weakness("焰") == "潮", "焰的弱点是潮")
	check(CombatRules.stars(true, 0.8, 1) == 3, "满足全部条件三星")
	check(CombatRules.stars(true, 0.3, 2) == 1, "血量不足只有一星")
	check(CombatRules.stars(false, 1.0, 5) == 0, "失败零星")
	# 敌人数据
	var used := {}
	for ch in Data.chapters:
		for sc in ch.scenes:
			for l in sc.lines:
				if str(l.get("t", "")) == "battle":
					var eid := str(l.get("enemy", ""))
					check(Data.enemies.has(eid), "剧情战斗敌人存在 %s" % eid)
					used[eid] = true
	check(used.size() >= 14, "14 场剧情战斗敌人各不相同（%d 种）" % used.size())
	var manifest := Data.manifest_keys()
	for eid in Data.enemies:
		var e: Dictionary = Data.enemies[eid]
		check(str(e.get("element", "")) in ["潮", "星", "焰"], "%s 有属性" % eid)
		check(manifest.has(str(e.get("img", ""))), "%s 的形象在美术清单里" % eid)
		for mv in e.get("pattern", []):
			check(CombatRules.MOVES.has(str(mv)), "%s 的招式 %s 有效" % [eid, mv])
		if e.has("phase2"):
			check(manifest.has(str(e.phase2.img)), "%s 第二形态形象在美术清单里" % eid)
	# 回廊
	var bosses := 0
	for n in range(1, CombatRules.TOWER_FLOORS + 1):
		var f := CombatRules.tower_floor(n, Data.enemies)
		check(Data.enemies.has(f.enemy), "回廊第 %d 层敌人有效" % n)
		if f.boss:
			bosses += 1
			check(bool(Data.enemies[f.enemy].get("boss", false)), "回廊第 %d 层是 Boss" % n)
	check(bosses == 6, "回廊每 5 层一个 Boss")
	var f1 := CombatRules.tower_floor(1, Data.enemies)
	var f30 := CombatRules.tower_floor(30, Data.enemies)
	check(float(Data.enemies[f30.enemy].hp) * f30.hp_mult > float(Data.enemies[f1.enemy].hp) * f1.hp_mult * 5.0, "回廊越往上越难")
	check(Data.enemies.has(CombatRules.daily_enemy("2026-10-28", Data.enemies)), "每日讨伐敌人有效")


## 真的开一场战斗，模拟完美闪避、护盾、打断、Boss 变身和结算。
func _test_battle_sim() -> void:
	Game.s = Game.default_state()
	Game.mark_tutorial("battle")
	Game.mark_tutorial("battle2")
	var script: GDScript = load("res://src/screens/Battle.gd")
	var b: Control = script.new()
	b.params = {"enemy": "rift_heart", "partner": "gu_ci", "key": "test:rift"}
	add_child(b)
	await get_tree().process_frame
	check(b.elem_e == "潮" and b.elem_p == "星", "属性读取正确")
	b.set_process(false)
	# 完美闪避：重击预警最后 0.2 秒
	b.state = "tele"
	b.cur_move = "heavy"
	b.tele_len = 1.5
	b.st_timer = 1.3
	b.dodge_cd = 0.0
	b._dodge()
	check(b.perfect == 1 and b.invuln > 1.0, "预警末尾闪避判定为完美闪避")
	Engine.time_scale = 1.0
	# 过早闪避不算完美
	b.state = "tele"
	b.st_timer = 0.2
	b.dodge_cd = 0.0
	b._dodge()
	check(b.perfect == 1, "过早闪避不算完美")
	# 护盾：普攻只扣盾
	b._to_idle()
	b.shield_max = 500.0
	b.shield = 500.0
	var hp_before: float = b.ehp
	b._attack()
	check(b.ehp == hp_before and b.shield < 500.0, "护盾挡住伤害")
	b.shield = 1.0
	b.attack_cd = 0.0
	b._attack()
	check(b.shield == 0.0 and b.state == "stun", "破盾后敌人眩晕")
	# 蓄力打断
	b._to_idle()
	b.pattern = ["charge"]
	b.pat_i = 0
	b._start_move()
	b.charge_dealt = b.charge_need + 1.0
	b._enemy_tick(0.01)
	check(b.state == "stun", "蓄力期间打出足够伤害可以打断")
	# Boss 变身
	b._to_idle()
	b.ehp = b.ehp_max * 0.52
	b.skill_cd = 0.0
	b._skill()
	check(b.phase == 2, "Boss 血量过半进入第二形态")
	check(b.elem_e == "星", "第二形态换了属性")
	# 结算
	b.paused = false  # 结算
	b.php = b.php_max
	b.ehp = 1.0
	b.attack_cd = 0.0
	b._attack()
	check(b.over, "击败敌人后结束")
	await get_tree().create_timer(1.1).timeout
	check(Game.battle_stars("test:rift") == 3, "满血 + 完美闪避 = 三星")
	Router.clear_overlay()
	b.queue_free()
	Engine.time_scale = 1.0



func _find_button(root: Node, text_part: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		var b := n as Button
		if b.is_visible_in_tree() and (b.text.contains(text_part) or _has_label(b, text_part)):
			return b
	return null


func _has_label(n: Node, text_part: String) -> bool:
	for l in n.find_children("*", "Label", true, false):
		if (l as Label).text.contains(text_part):
			return true
	return false


func _tap(b: Control) -> void:
	if b == null:
		return
	var pos := b.get_global_rect().get_center()
	if get_viewport().get_visible_rect().has_point(pos):
		await _mouse(pos, true)
		await _mouse(pos, false)
	elif b is Button:
		(b as Button).pressed.emit()
		await get_tree().process_frame


## v0.4.0 闪退回归：挑战 → 讨伐 / 回廊第 1 层 → 选搭档（每位男主都试）→ 必须进入战斗。
func _test_challenge_flow() -> void:
	print("[挑战入口进战斗]")
	Game.s = Game.default_state()
	Game.mark_tutorial("home")
	Game.mark_tutorial("battle")
	Game.mark_tutorial("battle2")
	for entry in [["讨伐", "hunt"], ["挑战", "tower"]]:
		for cid in Data.char_order:
			Router.go("Home")
			Router.push("Challenge")
			await get_tree().process_frame
			await get_tree().process_frame
			var screen: Control = Router.stack.back().node
			var btn := _find_button(screen, entry[0])
			if entry[1] == "tower":
				btn = null
				for n in screen.find_children("*", "Button", true, false):
					if (n as Button).text == "挑战" and n.is_visible_in_tree():
						btn = n
						break
			check(btn != null, "%s：找到入口按钮" % entry[1])
			await _tap(btn)
			await get_tree().process_frame
			var name := Data.char_name(cid)
			var pick := _find_button(Router.overlay, name)
			check(pick != null, "%s：弹出选搭档并有 %s" % [entry[1], name])
			await _tap(pick)
			await get_tree().process_frame
			await get_tree().process_frame
			check(Router.current_name() == "Battle", "%s + %s：进入战斗（当前 %s）" % [entry[1], name, Router.current_name()])
			if Router.current_name() == "Battle":
				var bt: Control = Router.stack.back().node
				check(str(bt.params.get("partner", "")) == cid and str(bt.params.get("mode", "")) == entry[1], "%s：战斗参数正确" % entry[1])
				bt.set_process(false)
			check(Router.overlay.get_child_count() == 0 or _no_picker(), "%s：选搭档弹窗已关闭" % entry[1])
	Router.go("Home")
	await get_tree().process_frame


func _no_picker() -> bool:
	return not _has_label(Router.overlay, "选择搭档")


## 调试菜单：测试存档和主存档分开，解锁只改测试存档。
func _test_debug_slot() -> void:
	print("[调试 · 测试存档]")
	check(Game.debug_enabled(), "调试入口已开启（正式版可关）")
	Game.s = Game.default_state()
	Game.s.player_name = "主存档玩家"
	Game.save()
	Game.switch_slot(true)
	check(Game.is_test_slot(), "切换到测试存档")
	Game.debug_unlock_to("ch4")
	check(Game.chapter_unlocked("ch4") and Game.scene_done("ch3", "s5") and Game.scene_done("ch1", "s1"), "测试存档解锁到第四章，前面章节已通关")
	check(not Game.scene_done("ch4", "s1"), "第四章本身未标记通关")
	Game.debug_add_resources()
	check(Game.diamonds() >= 20000, "测试存档加资源")
	Game.switch_slot(false)
	check(not Game.is_test_slot() and Game.player_name() == "主存档玩家", "切回主存档，名字还在")
	check(not Game.chapter_unlocked("ch4") and Game.diamonds() < 20000, "主存档没有被解锁或加资源")
	Game.debug_unlock_to("ch4")
	check(not Game.chapter_unlocked("ch4"), "主存档上调用解锁无效")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.TEST_SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SLOT_FILE))
	Game.reset()
