extends "res://src/screens/BaseScreen.gd"
## 挑战：每日讨伐（每天一个 Boss）+ 潮汐回廊（30 层爬塔）+ 敌人图鉴入口。
## 出战前可以自选搭档，选克制属性的搭档伤害 ×1.5。

const Combat := preload("res://src/systems/Combat.gd")
const HUNT_REWARD := {"gold": 3000, "diamonds": 60, "stardust": 30}


func build() -> void:
	Audio.play_bgm("tension")
	var right := UIKit.button("图鉴", "ghost", 26, 64)
	right.custom_minimum_size = Vector2(130, 64)
	right.pressed.connect(func() -> void: Router.push("Bestiary"))
	var page := UIKit.page("挑战", func() -> void: Router.back(), right)
	var v: VBoxContainer = page[1]
	var list := UIKit.vbox(22)
	list.add_child(_hunt_card())
	list.add_child(_tower_head())
	var best := Game.tower_best()
	for n in range(1, Combat.TOWER_FLOORS + 1):
		list.add_child(_floor_row(n, best))
	v.add_child(UIKit.scroll(list))
	add_child(page[0])


func on_resume(_result: Variant) -> void:
	rebuild()


func _hunt_card() -> Control:
	var eid := Combat.daily_enemy(Game.today(), Data.enemies)
	var e := Data.enemy(eid)
	var el := str(e.get("element", ""))
	var weak := Combat.weakness(el)
	var aura := Color(str(e.get("aura", "#ff9ec7")))
	var panel := UIKit.panel(Color(0.2, 0.1, 0.3, 0.92), 28, 24, aura, 3)
	var h := UIKit.hbox(20)
	var img := UIKit.image_box(Data.texture(str(e.get("img", ""))), Vector2(220, 220), 24, Color(aura, 0.6), 2)
	h.add_child(img)
	var bv := UIKit.vbox(8)
	bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bv.add_child(UIKit.label("每日讨伐", 26, UIKit.C_GOLD, HORIZONTAL_ALIGNMENT_LEFT, false))
	var row := UIKit.hbox(10)
	row.add_child(UIKit.label(str(e.get("name", "")), 40, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	row.add_child(UIKit.pill(el, UIKit.element_color(el), 22))
	bv.add_child(row)
	bv.add_child(UIKit.label("强度随搭档战力调整 · 弱点「%s」· 推荐 %s" % [weak, _char_of(weak)], 24, UIKit.C_MUTED))
	bv.add_child(UIKit.label("奖励：" + UIKit.reward_text(HUNT_REWARD), 24, UIKit.C_TEXT))
	var done := Game.hunt_done_today()
	var b := UIKit.button("今日已讨伐 ✓" if done else "讨伐", "ghost" if done else "primary", 30, 84)
	b.disabled = done
	b.pressed.connect(func() -> void:
		_pick_partner(eid, func(cid: String) -> void:
			var sc := Combat.hunt_scale(Game.team_stats(cid), e)
			Router.push("Battle", {"enemy": eid, "partner": cid, "mode": "hunt", "key": "hunt:" + eid,
				"hp_mult": sc.hp_mult, "atk_mult": sc.atk_mult, "reward": HUNT_REWARD})))
	bv.add_child(b)
	h.add_child(bv)
	panel.add_child(h)
	return panel


func _tower_head() -> Control:
	var v := UIKit.vbox(6)
	var row := UIKit.hbox(10)
	row.add_child(UIKit.label("❀ 潮汐回廊", 38, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	row.add_child(UIKit.spacer(0, true))
	row.add_child(UIKit.pill("已通关 %d / %d" % [Game.tower_best(), Combat.TOWER_FLOORS], UIKit.C_ACCENT, 24))
	v.add_child(row)
	v.add_child(UIKit.label("一层比一层强，每 5 层守着一个 Boss。首次通关有奖励，三星再加钻石。", 24, UIKit.C_MUTED))
	return v


func _floor_row(n: int, best: int) -> Control:
	var f := Combat.tower_floor(n, Data.enemies)
	var e := Data.enemy(str(f.enemy))
	var el := str(e.get("element", ""))
	var locked := n > best + 1
	var cleared := n <= best
	var border := UIKit.C_GOLD if f.boss else UIKit.C_LINE
	var panel := UIKit.panel(UIKit.C_PANEL, 22, 16, border, 2 if f.boss else 1)
	var h := UIKit.hbox(16)
	var img := UIKit.image_box(Data.texture(str(e.get("img", ""))), Vector2(120, 120), 18)
	if locked:
		img.modulate = Color(0.35, 0.35, 0.45)
	h.add_child(img)
	var bv := UIKit.vbox(4)
	bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UIKit.hbox(8)
	row.add_child(UIKit.label("第 %d 层" % n, 30, UIKit.C_GOLD if f.boss else UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	row.add_child(UIKit.label(str(e.get("name", "")), 28, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	row.add_child(UIKit.pill(el, UIKit.element_color(el), 20))
	if f.boss:
		row.add_child(UIKit.pill("BOSS", UIKit.C_GOLD, 20))
	bv.add_child(row)
	var stars := Game.battle_stars("tower:%d" % n)
	var star_txt := ""
	for i in 3:
		star_txt += "★" if i < stars else "☆"
	bv.add_child(UIKit.label(star_txt + ("    首通：" + UIKit.reward_text(f.reward) if not cleared else "    已通关"), 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT, false))
	h.add_child(bv)
	var b := UIKit.button("未解锁" if locked else ("再战" if cleared else "挑战"), "ghost" if locked or cleared else "primary", 26, 80)
	b.custom_minimum_size = Vector2(140, 80)
	b.disabled = locked
	b.pressed.connect(func() -> void:
		_pick_partner(str(f.enemy), func(cid: String) -> void:
			Router.push("Battle", {"enemy": f.enemy, "partner": cid, "mode": "tower", "floor": n, "key": "tower:%d" % n,
				"hp_mult": f.hp_mult, "atk_mult": f.atk_mult, "reward": f.reward})))
	h.add_child(b)
	panel.add_child(h)
	return panel


func _char_of(el: String) -> String:
	for cid in Data.char_order:
		if str(Data.character(cid).get("element", "")) == el:
			return Data.char_name(cid)
	return "任意搭档"


## 选搭档弹窗：显示属性、战力和克制关系。
func _pick_partner(eid: String, on_pick: Callable) -> void:
	var e := Data.enemy(eid)
	var el := str(e.get("element", ""))
	var panel := UIKit.panel(UIKit.C_PANEL, 32, 32, UIKit.C_LINE, 2)
	panel.custom_minimum_size = Vector2(900, 0)
	var v := UIKit.vbox(18)
	v.add_child(UIKit.label("选择搭档", 42, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("对手：%s（%s）· 弱点「%s」" % [str(e.get("name", "")), el, Combat.weakness(el)], 26, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var holder := {"dim": null}
	for cid in Data.char_order:
		var ch := Data.character(cid)
		var pel := str(ch.get("element", ""))
		var mult := Combat.element_mult(pel, el)
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 150)
		var col := Color(str(ch.get("color", "#ffffff")))
		b.add_theme_stylebox_override("normal", UIKit.sb(Color(col, 0.12), 24, Color(col, 0.7), 2))
		b.add_theme_stylebox_override("hover", UIKit.sb(Color(col, 0.22), 24, col, 3))
		b.add_theme_stylebox_override("pressed", UIKit.sb(Color(col, 0.3), 24, col, 3))
		var h := UIKit.hbox(16)
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 16
		h.offset_right = -16
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face := UIKit.image_box(Data.texture(Data.portrait_key(cid, "smile")), Vector2(118, 118), 59)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(face)
		var tv := UIKit.vbox(4)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(UIKit.label("%s  · %s" % [str(ch.get("name", "")), pel], 32, col, HORIZONTAL_ALIGNMENT_LEFT, false))
		tv.add_child(UIKit.label("战力 %d" % Game.power(cid), 24, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT, false))
		h.add_child(tv)
		if mult > 1.0:
			h.add_child(UIKit.pill("克制 ×1.5", UIKit.C_OK, 22))
		elif mult < 1.0:
			h.add_child(UIKit.pill("被克制", UIKit.C_DANGER, 22))
		for c in h.get_children():
			if c is Control:
				c.mouse_filter = Control.MOUSE_FILTER_IGNORE
				c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.add_child(h)
		var captured: String = cid
		b.pressed.connect(func() -> void:
			_close_dim(holder)
			on_pick.call(captured))
		v.add_child(b)
	var cancel := UIKit.button("取消", "ghost", 28, 80)
	v.add_child(cancel)
	panel.add_child(v)
	holder.dim = Router.modal(panel, true)
	cancel.pressed.connect(func() -> void: _close_dim(holder))


# Lambdas capture locals by value, so the modal is kept in a dict holder.
func _close_dim(holder: Dictionary) -> void:
	var d = holder.get("dim")
	if d != null and is_instance_valid(d):
		d.queue_free()
	holder.dim = null
