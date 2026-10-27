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
	Router.go("Home")
	await _shot("02_home")
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
