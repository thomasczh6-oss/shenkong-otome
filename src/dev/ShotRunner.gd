extends Node
## 自动截图：`godot --path . -- --shots=/tmp/shots`。
## 造一份演示存档，依次打开各界面并截图，用于无人值守地检查界面。

var out_dir := ""


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	get_tree().quit()


func _shot(name: String, wait := 0.6) -> void:
	await get_tree().create_timer(wait).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("[shot] ", path)


func _run() -> void:
	Game.reset()
	Game.set_player_name("小鹿")
	for id in ["shen_yan_5_1", "shen_yan_4_1", "shen_yan_3_2", "gu_ci_4_2", "gu_ci_5_2", "lu_zhuo_3_1"]:
		Game.add_card(id)
	Game.s.affection = {"shen_yan": 120, "gu_ci": 60, "lu_zhuo": 30}
	Game.s.story.done = {"ch1/s1": true}
	Game.save()

	Router.go("Title")
	await _shot("01_title")
	Router.go("Home")
	await _shot("19_tutorial", 1.0)
	Router.clear_overlay()
	Game.mark_tutorial("home")
	Game.mark_tutorial("battle")
	Game.mark_tutorial("battle2")
	Router.go("Home")
	await _shot("02_home")
	# 陪伴：点立绘
	var home: Node = Router.stack.back().node
	home._companion(home.get_children().filter(func(n): return n is TextureRect and n.material != null)[0], Data.character(str(Game.s.favorite)))
	await _shot("42_home_companion", 0.6)
	Router.go("Home")
	for c in ["gu_ci", "lu_zhuo"]:
		Game.s.favorite = c
		Router.go("Home")
		await _shot("02_home_" + c)
	Game.s.favorite = "shen_yan"
	Router.go("Home")
	Router.push("Chapters")
	await _shot("03_chapters")

	Router.push("Story", {"chapter": "ch1", "scene": "s1"})
	var story: Control = Router.stack.back().node
	await get_tree().create_timer(0.3).timeout
	story._advance()  # 标题
	for i in 9:
		story._advance()
		await get_tree().process_frame
		story._finish_typing()
	await _shot("04_story_dialog")
	var guard := 0
	while story.choice_layer == null and guard < 40 and not story.ended:
		story._advance()
		await get_tree().process_frame
		story._finish_typing()
		guard += 1
	await _shot("05_story_choice")
	if story.choice_layer != null:
		var opt: Dictionary = story.lines[story.idx].options[0]
		story._pick(opt)
	guard = 0
	while Router.current_name() != "Battle" and guard < 60:
		story._advance()
		await get_tree().process_frame
		story._finish_typing()
		guard += 1
		await get_tree().process_frame
	if Router.current_name() == "Battle":
		var battle: Control = Router.stack.back().node
		await get_tree().create_timer(0.5).timeout
		for i in 3:
			battle._attack()
			battle.attack_cd = 0.0
		await _shot("06_battle")
		battle.meter = 100.0
		battle._resonance()
		battle._skill()
		await _shot("07_battle_result", 0.4)
		Router.clear_overlay()
		Router.back({"win": true})
	await get_tree().create_timer(0.3).timeout
	Router.go("Home")

	Router.push("Gacha")
	await _shot("08_gacha")
	var gacha: Control = Router.stack.back().node
	gacha._do_pull(10)
	await _shot("09_gacha_result", 2.0)
	Router.go("Home")

	Router.push("Cards")
	await _shot("10_cards")
	Router.push("CardDetail", {"card": "shen_yan_5_1"})
	await _shot("11_card_detail")
	# 觉醒 3 阶 + 心语
	if Game.owns("shen_yan_5_1"):
		Game.s.cards["shen_yan_5_1"]["awaken"] = 3
		Game.s.cards["shen_yan_5_1"]["dup"] = 1
		Game.s.stardust = 999
		Router.back()
		Router.push("CardDetail", {"card": "shen_yan_5_1"})
		await get_tree().create_timer(0.3).timeout
		for sc in Router.stack.back().node.find_children("*", "ScrollContainer", true, false):
			(sc as ScrollContainer).scroll_vertical = 99999
		await _shot("43_card_awaken", 0.4)
	# 委托：一位进行中、一位可领取、一位空闲
	Game.start_commission("shen_yan", "mid")
	Game.start_commission("gu_ci", "long")
	Game.s.commissions.gu_ci.end = Game.now_unix() - 1
	Router.push("Commission")
	await _shot("44_commission", 0.4)
	await _click(_find_button(Router.stack.back().node, "领取"))
	await _shot("45_commission_note", 0.5)
	Router.clear_overlay()
	Game.s.commissions = {}
	Router.go("Home")

	Router.push("Daily", {"tab": 0})
	await _shot("12_daily_messages")
	Router.push("Chat", {"char": "shen_yan"})
	await _shot("13_chat", 2.5)
	Router.back()
	var daily: Control = Router.stack.back().node
	daily.set_tab(2)
	await _shot("14_moments")
	daily.set_tab(3)
	await _shot("15_signin_tasks")
	Router.push("Call", {"char": "shen_yan"})
	await _shot("16_call")
	Router.go("Home")

	Router.push("Shop")
	await _shot("17_shop")
	Router.push("Profile")
	await _shot("18_profile")
	# 调试菜单：连点版本号 7 次 → 切到测试存档 → 跳到第四章（真实点击）
	await _open_debug_menu()
	await _shot("37_debug_menu_main", 0.3)
	await _click(_find_button(Router.overlay, "切换到测试存档"))
	await get_tree().create_timer(0.3).timeout
	Router.push("Profile")
	await _open_debug_menu()
	await _shot("38_debug_menu_test", 0.3)
	await _click(_find_button(Router.overlay, "第四章"))
	await get_tree().create_timer(0.3).timeout
	print("[shot] debug jump: ", Router.current_name(), " test=", Game.is_test_slot(), " ch4=", Game.chapter_unlocked("ch4"))
	await _shot("39_debug_ch4_chapters", 0.4)
	Game.switch_slot(false)
	print("[shot] main slot ch4=", Game.chapter_unlocked("ch4"))
	Router.go("Home")

	# 挑战：每日讨伐、回廊、选搭档、图鉴、新战斗机制
	Game.s.tower = {"best": 4}
	Game.s.battle_stars = {"tower:1": 3, "tower:2": 2, "tower:3": 3, "tower:4": 1}
	Game.s.bestiary = {"tide_shade": true, "mist_eel": true, "coral_siren": true, "rift_heart": true}
	Router.push("Challenge")
	await _shot("26_challenge")
	# 真实点击路径：点「讨伐」→ 弹出选搭档 → 点顾辞 → 进入战斗（v0.4.0 在真机上这里闪退）
	var hunt_btn := _find_button(Router.stack.back().node, "讨伐")
	await _click(hunt_btn)
	await _shot("27_pick_partner")
	var pick := _find_button(Router.overlay, "顾辞")
	await _click(pick)
	await _shot("27b_hunt_battle", 1.5)
	print("[shot] hunt battle open: ", Router.current_name())
	Router.clear_overlay()
	Router.go("Home")
	Router.push("Challenge")
	await get_tree().create_timer(0.4).timeout
	Router.push("Bestiary")
	await _shot("28_bestiary")
	Router.go("Home")
	Router.push("Battle", {"enemy": "coral_siren", "partner": "shen_yan"})
	var bt: Control = Router.stack.back().node
	await get_tree().create_timer(0.4).timeout
	bt.pattern = ["charge"]
	bt.pat_i = 0
	bt._to_idle()
	bt.st_timer = 99.0
	await _shot("29_battle_charge", 0.5)
	bt.meter = 100.0
	bt._resonance()
	await _shot("30_battle_qte", 0.45)
	Router.go("Home")
	Router.push("Battle", {"enemy": "rift_heart", "partner": "gu_ci"})
	bt = Router.stack.back().node
	await get_tree().create_timer(0.4).timeout
	bt.ehp = bt.ehp_max * 0.51
	bt._skill()
	await _shot("31_battle_phase2", 2.0)
	Router.go("Home")

	# 第二章：带 CG 的剧情
	for sc in Data.chapter("ch1").scenes:
		Game.s.story.done["ch1/" + str(sc.id)] = true
	Game.unlock_chapter("ch2")
	Router.push("Chapters")
	await _shot("20_chapters_ch2")
	Router.push("Story", {"chapter": "ch2", "scene": "s2"})
	story = Router.stack.back().node
	await get_tree().create_timer(0.3).timeout
	guard = 0
	while not story.cg_active and guard < 80 and not story.ended:
		if story.choice_layer != null:
			story._pick(story.lines[story.idx].options[0])
		elif Router.current_name() == "Battle":
			Router.back({"win": true})
		else:
			story._advance()
		await get_tree().process_frame
		story._finish_typing()
		guard += 1
	story._advance()
	await get_tree().process_frame
	story._finish_typing()
	await _shot("21_story_cg", 1.2)
	Router.go("Home")
	for e in Data.cg_list().slice(0, 7):
		Game.unlock_cg(str(e.key))
	Router.push("Gallery")
	await _shot("22_gallery")
	Router.go("Home")

	# 第四章：章节列表、开场对白、CG、终章 Boss 变身
	for cid in ["ch1", "ch2", "ch3"]:
		for sc in Data.chapter(cid).scenes:
			Game.s.story.done[cid + "/" + str(sc.id)] = true
		Game.unlock_chapter(cid)
	Game.unlock_chapter("ch4")
	Router.push("Chapters")
	await get_tree().create_timer(0.3).timeout
	var chs: Node = Router.stack.back().node
	for sc in chs.find_children("*", "ScrollContainer", true, false):
		(sc as ScrollContainer).scroll_vertical = 99999
	await _shot("32_chapters_ch4", 0.4)
	Router.go("Home")
	Router.push("Story", {"chapter": "ch4", "scene": "s1"})
	story = Router.stack.back().node
	for i in 3:
		await get_tree().create_timer(0.2).timeout
		story._advance()
		await get_tree().process_frame
		story._finish_typing()
	await _shot("33_ch4_dialog", 0.6)
	Router.go("Home")
	for scid in ["s2", "s5"]:
		Router.push("Story", {"chapter": "ch4", "scene": scid})
		story = Router.stack.back().node
		await get_tree().create_timer(0.3).timeout
		guard = 0
		while not story.cg_active and guard < 120 and not story.ended:
			if story.choice_layer != null:
				story._pick(story.lines[story.idx].options[0])
			elif Router.current_name() == "Battle":
				Router.back({"win": true})
			else:
				story._advance()
			await get_tree().process_frame
			story._finish_typing()
			guard += 1
		story._advance()
		await get_tree().process_frame
		story._finish_typing()
		await _shot("34_ch4_cg_" + scid, 1.2)
		Router.go("Home")
	# 第五章：顾辞告白 CG、结局（牵顾辞的手）、深空之鲸变身
	Game.unlock_chapter("ch5")
	for spec in [["s3", 0, 0], ["s5", 1, 1]]:
		Router.push("Story", {"chapter": "ch5", "scene": spec[0]})
		story = Router.stack.back().node
		await get_tree().create_timer(0.3).timeout
		var cgs_seen := 0
		guard = 0
		while guard < 200 and not story.ended:
			if story.cg_active:
				cgs_seen += 1
				if cgs_seen > int(spec[2]):
					break
				while story.cg_active and guard < 200:
					story._advance()
					await get_tree().process_frame
					story._finish_typing()
					guard += 1
				continue
			if story.choice_layer != null:
				var opts: Array = story.lines[story.idx].options
				story._pick(opts[mini(int(spec[1]), opts.size() - 1)])
			elif Router.current_name() == "Battle":
				Router.back({"win": true})
			else:
				story._advance()
			await get_tree().process_frame
			story._finish_typing()
			guard += 1
		story._advance()
		await get_tree().process_frame
		story._finish_typing()
		await _shot("40_ch5_cg_" + str(spec[0]), 1.2)
		Router.go("Home")
	Router.push("Battle", {"enemy": "abyss_whale", "partner": "gu_ci"})
	bt = Router.stack.back().node
	await get_tree().create_timer(0.4).timeout
	bt.ehp = bt.ehp_max * 0.51
	bt._skill()
	await _shot("41_whale_p2", 2.0)
	Router.go("Home")
	# 第六章：顾辞雾港上空 CG、千灯终章 CG、灯母变身
	Game.unlock_chapter("ch6")
	for scid in ["s3", "s5"]:
		Router.push("Story", {"chapter": "ch6", "scene": scid})
		story = Router.stack.back().node
		await get_tree().create_timer(0.3).timeout
		guard = 0
		while guard < 200 and not story.ended and not story.cg_active:
			if story.choice_layer != null:
				story._pick(story.lines[story.idx].options[0])
			elif Router.current_name() == "Battle":
				Router.back({"win": true})
			else:
				story._advance()
			await get_tree().process_frame
			story._finish_typing()
			guard += 1
		story._advance()
		await get_tree().process_frame
		story._finish_typing()
		await _shot("46_ch6_cg_" + scid, 1.2)
		Router.go("Home")
	Router.push("Battle", {"enemy": "fog_heron", "partner": "gu_ci"})
	bt = Router.stack.back().node
	await get_tree().create_timer(0.4).timeout
	await _shot("47_fog_heron", 0.3)
	Router.go("Home")
	Router.push("Battle", {"enemy": "lantern_mother", "partner": "shen_yan"})
	bt = Router.stack.back().node
	await get_tree().create_timer(0.4).timeout
	bt.ehp = bt.ehp_max * 0.51
	bt._skill()
	await _shot("48_lantern_mother_p2", 2.0)
	Router.go("Home")
	# 第七章：顾辞极光 CG、冰海终章 CG、霜钟守望者变身
	Game.unlock_chapter("ch7")
	for scid in ["s3", "s5"]:
		Router.push("Story", {"chapter": "ch7", "scene": scid})
		story = Router.stack.back().node
		await get_tree().create_timer(0.3).timeout
		guard = 0
		while guard < 200 and not story.ended and not story.cg_active:
			if story.choice_layer != null:
				story._pick(story.lines[story.idx].options[0])
			elif Router.current_name() == "Battle":
				Router.back({"win": true})
			else:
				story._advance()
			await get_tree().process_frame
			story._finish_typing()
			guard += 1
		story._advance()
		await get_tree().process_frame
		story._finish_typing()
		await _shot("49_ch7_cg_" + scid, 1.2)
		Router.go("Home")
	Router.push("Battle", {"enemy": "echo_wolf", "partner": "lu_zhuo"})
	bt = Router.stack.back().node
	await get_tree().create_timer(0.4).timeout
	await _shot("50_echo_wolf", 0.3)
	Router.go("Home")
	Router.push("Battle", {"enemy": "frost_clock", "partner": "shen_yan"})
	bt = Router.stack.back().node
	await get_tree().create_timer(0.4).timeout
	bt.ehp = bt.ehp_max * 0.51
	bt._skill()
	await _shot("51_frost_clock_p2", 2.0)
	Router.go("Home")
	Router.push("Battle", {"enemy": "zero_lock", "partner": "lu_zhuo"})
	bt = Router.stack.back().node
	await get_tree().create_timer(0.4).timeout
	await _shot("35_zero_lock", 0.3)
	bt.ehp = bt.ehp_max * 0.51
	bt._skill()
	await _shot("36_zero_lock_p2", 2.0)
	Router.go("Home")

	# 约会
	Router.push("Dates", {"char": "shen_yan"})
	await _shot("23_dates")
	Router.push("Story", {"date": "shen_yan_2"})
	story = Router.stack.back().node
	await get_tree().create_timer(0.3).timeout
	guard = 0
	while story.touch_layer == null and guard < 40 and not story.ended:
		if story.choice_layer != null:
			story._pick(story.lines[story.idx].options[0])
		else:
			story._advance()
		await get_tree().process_frame
		story._finish_typing()
		guard += 1
	await _shot("24_date_touch", 1.0)
	for c in story.touch_layer.get_children():
		if c is Button:
			c.pressed.emit()
			break
	await get_tree().process_frame
	story._finish_typing()
	await _shot("25_date_reaction", 0.5)
	Router.go("Home")
	Game.reset()


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


func _open_debug_menu() -> void:
	await get_tree().create_timer(0.3).timeout
	var page: Node = Router.stack.back().node
	for sc in page.find_children("*", "ScrollContainer", true, false):
		(sc as ScrollContainer).scroll_vertical = 99999
	await get_tree().create_timer(0.3).timeout
	var ver := _find_button(page, "深与空恋 · v")
	for i in 7:
		await _click(ver)


## 用真实的鼠标事件点一个按钮（和手机上的点击走同一条路）。
func _click(b: Control) -> void:
	if b == null:
		print("[shot] 找不到按钮")
		return
	var pos := b.get_global_rect().get_center()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		get_viewport().push_input(ev, true)
		await get_tree().process_frame

