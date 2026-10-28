extends "res://src/screens/BaseScreen.gd"
## 思念详情：大图、属性、思念故事、升级、装备。


func build() -> void:
	var id := str(params.get("card", ""))
	var c: Dictionary = Data.cards.get(id, {})
	var rarity := int(c.get("rarity", 3))
	var owned := Game.owns(id)
	var cid := str(c.get("char", ""))
	var page := UIKit.page(str(c.get("name", "")), func() -> void: Router.back())
	var v: VBoxContainer = page[1]
	var content := UIKit.vbox(18)

	var video := Data.card_video(id) if owned else null
	var box: PanelContainer
	if video != null:
		box = UIKit.video_box(video, Vector2(0, 980), 28, UIKit.rarity_color(rarity), 3)
	else:
		box = UIKit.image_box(Data.texture("cards/" + id), Vector2(0, 980), 28, UIKit.rarity_color(rarity), 3)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not owned:
		box.modulate = Color(0.5, 0.5, 0.6)
	content.add_child(box)

	var row := UIKit.hbox(12)
	row.add_child(UIKit.label(UIKit.stars(rarity), 30, UIKit.rarity_color(rarity), HORIZONTAL_ALIGNMENT_LEFT, false))
	row.add_child(UIKit.pill(str(c.get("element", "")), UIKit.element_color(str(c.get("element", ""))), 22))
	row.add_child(UIKit.pill(Data.char_name(cid), Color(str(Data.character(cid).get("color", "#4fd1c5"))), 22))
	if bool(c.get("limited", false)):
		row.add_child(UIKit.pill("限定", UIKit.C_GOLD, 22))
	if Data.card_video(id) != null:
		row.add_child(UIKit.pill("动态思念" if owned else "获得后可看动态", UIKit.C_ROSE, 22))
	row.add_child(UIKit.spacer(0, true))
	row.add_child(UIKit.label(("Lv.%d / %d" % [Game.card_level(id), Game.CARD_MAX_LEVEL]) + ("  觉醒 %d" % Game.card_awaken(id) if Game.card_awaken(id) > 0 else "") if owned else "未获得", 26, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_RIGHT, false))
	content.add_child(row)

	var st := Game.card_stats(id)
	var stats := UIKit.hbox(10)
	for pair in [["生命", st.hp], ["攻击", st.atk], ["防御", st.def]]:
		var p := UIKit.panel(Color(1, 1, 1, 0.05), 20, 16, Color(1, 1, 1, 0.08), 2)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pv := UIKit.vbox(2)
		pv.add_child(UIKit.label(str(pair[0]), 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER, false))
		pv.add_child(UIKit.label(str(pair[1]), 34, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, false))
		p.add_child(pv)
		stats.add_child(p)
	content.add_child(stats)

	var story := UIKit.panel(UIKit.C_PANEL, 24, 24, UIKit.C_LINE, 2)
	var sv := UIKit.vbox(8)
	sv.add_child(UIKit.label("思念", 24, UIKit.C_ROSE, HORIZONTAL_ALIGNMENT_LEFT, false))
	sv.add_child(UIKit.label(str(c.get("story", "")) if owned else "获得这段思念后，才能读到他的故事。", 28, UIKit.C_TEXT if owned else UIKit.C_MUTED))
	story.add_child(sv)
	content.add_child(story)

	# 觉醒：重复思念 + 星屑，每阶全属性 +10%，3 阶解锁心语
	if owned:
		var aw := Game.card_awaken(id)
		var ap := UIKit.panel(UIKit.C_PANEL, 24, 22, Color(UIKit.C_GOLD, 0.5), 2)
		var av := UIKit.vbox(10)
		var arow := UIKit.hbox(12)
		arow.add_child(UIKit.label("觉醒", 28, UIKit.C_GOLD, HORIZONTAL_ALIGNMENT_LEFT, false))
		var pips := ""
		for i in Game.awaken_max():
			pips += "●" if i < aw else "○"
		arow.add_child(UIKit.label(pips, 30, UIKit.C_GOLD, HORIZONTAL_ALIGNMENT_LEFT, false))
		arow.add_child(UIKit.spacer(0, true))
		arow.add_child(UIKit.label("全属性 +%d%%" % (aw * 10), 24, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_RIGHT, false))
		av.add_child(arow)
		if aw >= Game.awaken_max():
			av.add_child(UIKit.label("已完全觉醒。", 24, UIKit.C_MUTED))
		else:
			av.add_child(UIKit.label("需要：重复思念 1 张（拥有 %d）· 星屑 %d（拥有 %d）" % [Game.card_dup(id), Game.awaken_cost(id), Game.stardust()], 24, UIKit.C_MUTED))
			var ab := UIKit.button("觉醒", "gold", 28, 88)
			ab.disabled = not Game.can_awaken(id)
			ab.pressed.connect(func() -> void:
				if Game.awaken_card(id):
					Router.toast("觉醒成功 → %d 阶" % Game.card_awaken(id) + ("   解锁心语！" if Game.card_awaken(id) == int(Data.awaken_cfg.get("whisper_at", 3)) else ""), 2.0)
					rebuild())
			av.add_child(ab)
		ap.add_child(av)
		content.add_child(ap)
		# 心语：觉醒 3 阶后他对你说的一句话（有配音）
		var wp := UIKit.panel(UIKit.C_PANEL, 24, 22, Color(UIKit.C_ROSE, 0.5), 2)
		var wv := UIKit.vbox(8)
		wv.add_child(UIKit.label("心语", 24, UIKit.C_ROSE, HORIZONTAL_ALIGNMENT_LEFT, false))
		if Game.whisper_unlocked(id):
			var whisper := str(c.get("whisper", ""))
			wv.add_child(UIKit.label("「%s」" % whisper, 30, UIKit.C_TEXT))
			var play := UIKit.button("♪ 听他说", "ghost", 26, 76)
			play.pressed.connect(func() -> void: Audio.play_voice(cid, whisper))
			wv.add_child(play)
		else:
			wv.add_child(UIKit.label("觉醒到 %d 阶后，可以听到他只对你说的一句话。" % int(Data.awaken_cfg.get("whisper_at", 3)), 26, UIKit.C_MUTED))
		wp.add_child(wv)
		content.add_child(wp)

	var brow := UIKit.hbox(14)
	if owned:
		var cost := Game.upgrade_cost(id)
		var up := UIKit.button("升级（金币 %d）" % cost, "gold", 28, 100)
		up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		up.disabled = Game.card_level(id) >= Game.CARD_MAX_LEVEL
		up.pressed.connect(func() -> void:
			if Game.upgrade_card(id):
				Router.toast("升级成功 → Lv.%d" % Game.card_level(id))
				rebuild()
			else:
				Router.toast("金币不足"))
		var eq := UIKit.button("卸下" if Game.is_equipped(id) else "装备", "primary" if not Game.is_equipped(id) else "ghost", 28, 100)
		eq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eq.pressed.connect(func() -> void:
			Router.toast(Game.toggle_equip(id))
			rebuild())
		brow.add_child(up)
		brow.add_child(eq)
	else:
		var go := UIKit.button("去许愿", "primary", 30, 100)
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.pressed.connect(func() -> void: Router.push("Gacha", {"pool": "limited" if bool(c.get("limited", false)) else "standard"}))
		brow.add_child(go)
	content.add_child(brow)
	content.add_child(UIKit.label("金币 %d · 装备 2 张思念并肩作战，每级好感 +2%% 面板" % Game.gold(), 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.scroll(content))
	add_child(page[0])


func on_resume(_result: Variant) -> void:
	rebuild()
