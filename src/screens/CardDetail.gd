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

	var box := UIKit.image_box(Data.texture("cards/" + id), Vector2(0, 980), 28, UIKit.rarity_color(rarity), 3)
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
	row.add_child(UIKit.spacer(0, true))
	row.add_child(UIKit.label("Lv.%d / %d" % [Game.card_level(id), Game.CARD_MAX_LEVEL] if owned else "未获得", 26, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_RIGHT, false))
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
