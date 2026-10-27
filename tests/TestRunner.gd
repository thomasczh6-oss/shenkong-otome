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
