extends "res://src/screens/BaseScreen.gd"
## 思念（卡牌图鉴）：按角色 / 稀有度筛选，点开看详情、升级、装备。

var filter_char := ""
var filter_rarity := 0


func build() -> void:
	var owned := 0
	for id in Data.card_order:
		if Game.owns(id):
			owned += 1
	var page := UIKit.page("思念", func() -> void: Router.back(), UIKit.pill("已收集 %d / %d" % [owned, Data.card_order.size()], UIKit.C_ACCENT, 22))
	var v: VBoxContainer = page[1]

	var chips := UIKit.hbox(8)
	chips.add_child(_chip("全部", filter_char == "", func() -> void:
		filter_char = ""
		rebuild()))
	for cid in Data.char_order:
		var captured: String = cid
		chips.add_child(_chip(Data.char_name(cid), filter_char == cid, func() -> void:
			filter_char = captured
			rebuild()))
	v.add_child(chips)
	var rchips := UIKit.hbox(8)
	for r in [0, 5, 4, 3]:
		var rr: int = r
		rchips.add_child(_chip("全部稀有度" if r == 0 else UIKit.stars(r), filter_rarity == r, func() -> void:
			filter_rarity = rr
			rebuild()))
	v.add_child(rchips)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 18)
	for id in Data.card_order:
		var c: Dictionary = Data.cards[id]
		if filter_char != "" and str(c.get("char", "")) != filter_char:
			continue
		if filter_rarity != 0 and int(c.get("rarity", 3)) != filter_rarity:
			continue
		grid.add_child(_tile(id, c))
	v.add_child(UIKit.scroll(grid))
	add_child(page[0])


func on_resume(_result: Variant) -> void:
	rebuild()


func _chip(text: String, active: bool, on_press: Callable) -> Button:
	var b := UIKit.button(text, "primary" if active else "ghost", 24, 60)
	b.pressed.connect(on_press)
	return b


func _tile(id: String, c: Dictionary) -> Control:
	var rarity := int(c.get("rarity", 3))
	var owned := Game.owns(id)
	var panel := UIKit.panel(UIKit.C_PANEL, 22, 10, UIKit.rarity_color(rarity) if owned else UIKit.C_LINE, 2)
	panel.custom_minimum_size = Vector2(320, 0)
	var v := UIKit.vbox(6)
	var box := UIKit.image_box(Data.texture("cards/" + id), Vector2(300, 380), 16)
	if not owned:
		box.modulate = Color(0.45, 0.45, 0.55)
	v.add_child(box)
	v.add_child(UIKit.label(UIKit.stars(rarity), 20, UIKit.rarity_color(rarity), HORIZONTAL_ALIGNMENT_CENTER, false))
	v.add_child(UIKit.label(str(c.get("name", "")), 26, UIKit.C_TEXT if owned else UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER, false))
	var sub := "Lv.%d" % Game.card_level(id) if owned else "未获得"
	if owned and Game.is_equipped(id):
		sub += " · 装备中"
	v.add_child(UIKit.label(sub, 20, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER, false))
	panel.add_child(v)
	UIKit.on_tap(panel, func() -> void: Router.push("CardDetail", {"card": id}))
	return panel
