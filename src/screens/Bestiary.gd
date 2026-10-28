extends "res://src/screens/BaseScreen.gd"
## 敌人图鉴：打败过的敌人显示形象、属性、弱点、招式和介绍，没遇到的显示剪影。

const Combat := preload("res://src/systems/Combat.gd")


func build() -> void:
	var page := UIKit.page("敌人图鉴", func() -> void: Router.back())
	var v: VBoxContainer = page[1]
	var seen: Dictionary = Game.s.get("bestiary", {}).duplicate()
	# 老存档：打通过的剧情里出现的敌人也算见过
	for ch in Data.chapters:
		for sc in ch.scenes:
			if Game.scene_done(str(ch.id), str(sc.id)):
				for l in sc.lines:
					if str(l.get("t", "")) == "battle":
						seen[str(l.get("enemy", ""))] = true
	var ids: Array = []
	for id in Data.enemies:
		ids.append(id)
	ids.sort_custom(func(a, b) -> bool: return float(Data.enemies[a].hp) < float(Data.enemies[b].hp))
	v.add_child(UIKit.label("已记录 %d / %d" % [seen.size(), ids.size()], 26, UIKit.C_MUTED))
	var list := UIKit.vbox(18)
	for id in ids:
		list.add_child(_entry(str(id), seen.has(id)))
	v.add_child(UIKit.scroll(list))
	add_child(page[0])


func _entry(id: String, known: bool) -> Control:
	var e := Data.enemy(id)
	var el := str(e.get("element", ""))
	var aura := Color(str(e.get("aura", "#ffffff")))
	var panel := UIKit.panel(UIKit.C_PANEL, 24, 18, Color(aura, 0.5) if known else UIKit.C_LINE, 2)
	var h := UIKit.hbox(18)
	var img := UIKit.image_box(Data.texture(str(e.get("img", ""))), Vector2(200, 200), 22)
	if not known:
		img.modulate = Color(0.05, 0.05, 0.1)
	h.add_child(img)
	var bv := UIKit.vbox(6)
	bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UIKit.hbox(10)
	row.add_child(UIKit.label(str(e.get("name", "")) if known else "？？？", 34, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	if known:
		row.add_child(UIKit.pill(el, UIKit.element_color(el), 20))
		if bool(e.get("boss", false)):
			row.add_child(UIKit.pill("BOSS", UIKit.C_GOLD, 20))
	bv.add_child(row)
	if known:
		bv.add_child(UIKit.label("弱点：%s" % Combat.weakness(el), 24, UIKit.C_OK))
		var moves: Array = []
		for mv in e.get("pattern", []):
			var nm := Combat.move_name(e, str(mv))
			if not moves.has(nm):
				moves.append(nm)
		bv.add_child(UIKit.label("招式：" + " → ".join(moves), 22, UIKit.C_MUTED))
		if e.has("phase2"):
			bv.add_child(UIKit.label("第二形态：" + str(e.phase2.get("name", "")), 22, UIKit.C_GOLD))
		bv.add_child(UIKit.label(str(e.get("desc", "")), 22, UIKit.C_TEXT))
	else:
		bv.add_child(UIKit.label("还没有遇到过。", 24, UIKit.C_MUTED))
	h.add_child(bv)
	panel.add_child(h)
	return panel
