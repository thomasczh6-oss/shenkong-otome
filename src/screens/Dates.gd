extends "res://src/screens/BaseScreen.gd"
## 约会：按男主分页，好感达到要求后解锁约会地点；每位男主每天可约会一次，首次约会解锁回忆 CG。

var cid := ""


func build() -> void:
	if cid == "":
		cid = str(params.get("char", Game.s.get("favorite", Data.char_order[0])))
	var ch := Data.character(cid)
	Audio.play_bgm("daily")
	var page := UIKit.page("约会", func() -> void: Router.back(), UIKit.pill("每人每天 1 次", UIKit.C_ROSE, 22))
	var v: VBoxContainer = page[1]

	var chips := UIKit.hbox(8)
	for id in Data.char_order:
		var captured: String = id
		var b := UIKit.button(Data.char_name(id) + ("  ✓" if Game.dated_today(id) else ""), "primary" if id == cid else "ghost", 26, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			cid = captured
			rebuild())
		chips.add_child(b)
	v.add_child(chips)

	# 男主信息条
	var head := UIKit.panel(UIKit.C_PANEL, 24, 18, Color(str(ch.get("color", "#ffffff"))), 2)
	var hh := UIKit.hbox(18)
	hh.add_child(UIKit.image_box(Data.texture(Data.portrait_key(cid, "smile")), Vector2(140, 140), 70))
	var hv := UIKit.vbox(6)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.label(str(ch.get("name", "")), 40, Color(str(ch.get("color", "#ffffff"))), HORIZONTAL_ALIGNMENT_LEFT, false))
	hv.add_child(UIKit.label("♥ Lv.%d %s" % [Game.affection_level(cid), Game.affection_name(cid)], 26, UIKit.C_ROSE, HORIZONTAL_ALIGNMENT_LEFT, false))
	var prog := Game.affection_progress(cid)
	hv.add_child(UIKit.progress(prog[0], prog[1], UIKit.C_ROSE, 14))
	hv.add_child(UIKit.label("今天已经约会过了，明天再来吧。" if Game.dated_today(cid) else "今天还可以约会一次。", 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT, false))
	hh.add_child(hv)
	head.add_child(hh)
	v.add_child(head)

	var list := UIKit.vbox(20)
	for d in Data.dates_of(cid):
		list.add_child(_date_card(d))
	v.add_child(UIKit.scroll(list))
	add_child(page[0])


func on_resume(_result: Variant) -> void:
	rebuild()


func _date_card(d: Dictionary) -> Control:
	var id := str(d.id)
	var unlocked := Game.date_unlocked(d)
	var panel := UIKit.panel(UIKit.C_PANEL, 26, 0, UIKit.C_LINE, 2)
	panel.clip_contents = true
	var v := UIKit.vbox(0)
	var cover := UIKit.image(Data.texture(str(d.get("bg", ""))))
	cover.custom_minimum_size = Vector2(0, 240)
	if not unlocked:
		cover.modulate = Color(0.4, 0.4, 0.5)
	v.add_child(cover)
	var body := UIKit.margin(26, 18, 26, 22)
	var bv := UIKit.vbox(10)
	var row := UIKit.hbox(12)
	row.add_child(UIKit.label(str(d.get("title", "")), 36, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	row.add_child(UIKit.spacer(0, true))
	if Game.date_done_ever(id):
		row.add_child(UIKit.pill("回忆已解锁", UIKit.C_GOLD, 22))
	elif not unlocked:
		row.add_child(UIKit.pill("♥ Lv.%d 解锁" % int(d.get("level", 1)), UIKit.C_MUTED, 22))
	bv.add_child(row)
	bv.add_child(UIKit.label(str(d.get("desc", "")), 26, UIKit.C_MUTED))
	var btn: Button
	if not unlocked:
		btn = UIKit.button("好感达到 Lv.%d「%s」后解锁" % [int(d.get("level", 1)), Game.AFF_NAMES[int(d.get("level", 1)) - 1]], "ghost", 28, 80)
		btn.disabled = true
	elif Game.dated_today(cid):
		btn = UIKit.button("今天已约会", "ghost", 28, 80)
		btn.disabled = true
	else:
		var first := not Game.date_done_ever(id)
		btn = UIKit.button("出发" + ("    首次奖励 " + UIKit.reward_text(Data.dates_cfg.get("first_reward", {})) if first else ""), "primary", 30, 84)
		btn.pressed.connect(func() -> void: Router.push("Story", {"date": id}))
	bv.add_child(btn)
	body.add_child(bv)
	v.add_child(body)
	panel.add_child(v)
	return panel
