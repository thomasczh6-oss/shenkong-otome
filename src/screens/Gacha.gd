extends "res://src/screens/BaseScreen.gd"
## 许愿（抽卡）界面：卡池切换、概率与保底展示、单抽 / 十连、结果翻牌动画。

const Gacha := preload("res://src/systems/Gacha.gd")

var pool_id := ""
var pool_ids: Array = []


func build() -> void:
	pool_ids = Data.gacha.get("pools", {}).keys()
	pool_ids.sort_custom(func(a, b) -> bool:
		return int(Data.gacha.pools[a].get("order", 0)) < int(Data.gacha.pools[b].get("order", 0)))
	if pool_id == "" or not pool_ids.has(pool_id):
		pool_id = str(params.get("pool", pool_ids[0]))
	var p := Gacha.pool(pool_id)

	var page := UIKit.page("许愿", func() -> void: Router.back(), _currency_row())
	var v: VBoxContainer = page[1]

	var tabs := UIKit.hbox(10)
	for pid in pool_ids:
		var pool: Dictionary = Data.gacha.pools[pid]
		var b := UIKit.button(str(pool.name), "primary" if pid == pool_id else "ghost", 30, 80)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var captured: String = pid
		b.pressed.connect(func() -> void:
			pool_id = captured
			rebuild())
		tabs.add_child(b)
	v.add_child(tabs)

	var content := UIKit.vbox(18)
	# 卡池横幅
	var banner := UIKit.panel(UIKit.C_PANEL, 28, 0, UIKit.C_LINE, 2)
	banner.clip_contents = true
	var bv := UIKit.vbox(0)
	var img := UIKit.image(Data.texture(str(p.get("banner", "ui/banner_standard"))))
	img.custom_minimum_size = Vector2(0, 500)
	bv.add_child(img)
	var cap := UIKit.margin(26, 18, 26, 22)
	var cv := UIKit.vbox(8)
	var trow := UIKit.hbox(12)
	trow.add_child(UIKit.label(str(p.get("name", "")), 44, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	trow.add_child(UIKit.pill(str(p.get("subtitle", "")), UIKit.C_GOLD if str(p.get("ticket", "")) == "limited" else UIKit.C_ACCENT, 22))
	trow.add_child(UIKit.spacer(0, true))
	trow.add_child(UIKit.label(str(p.get("ends", "")), 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_RIGHT, false))
	cv.add_child(trow)
	cv.add_child(UIKit.label(str(p.get("desc", "")), 26, UIKit.C_MUTED))
	cap.add_child(cv)
	bv.add_child(cap)
	banner.add_child(bv)
	content.add_child(banner)

	# UP 思念
	var featured: Array = p.get("featured", [])
	if featured.size() > 0:
		var frow := UIKit.hbox(14)
		for fid in featured:
			var c: Dictionary = Data.cards.get(fid, {})
			var cell := UIKit.vbox(6)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var box := UIKit.image_box(Data.texture("cards/" + str(fid)), Vector2(0, 300), 20, UIKit.rarity_color(5), 3)
			box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.add_child(box)
			cell.add_child(UIKit.label("%s · %s" % [Data.char_name(str(c.get("char", ""))), str(c.get("name", ""))], 24, UIKit.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
			frow.add_child(cell)
		content.add_child(frow)

	# 概率与保底
	var info := UIKit.panel(Color(1, 1, 1, 0.05), 24, 22, Color(1, 1, 1, 0.08), 2)
	var iv := UIKit.vbox(8)
	var pt := Gacha.pity(pool_id)
	var hard := int(p.get("hard_pity", 70))
	iv.add_child(UIKit.label("5★ 基础 %.0f%%（当前 %.1f%%）· 4★ %.0f%% · 10 抽必出 4★" % [
		float(p.get("rate5", 0.01)) * 100.0, Gacha.current_rate5(pool_id) * 100.0, float(p.get("rate4", 0.07)) * 100.0], 24, UIKit.C_MUTED))
	var prow := UIKit.hbox(12)
	prow.add_child(UIKit.label("距硬保底 %d 抽" % Gacha.pulls_to_hard_pity(pool_id), 26, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	var bar := UIKit.progress(int(pt.since5), hard, UIKit.C_GOLD, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prow.add_child(bar)
	if featured.size() > 0 and bool(pt.get("guaranteed", false)):
		prow.add_child(UIKit.pill("大保底生效中", UIKit.C_ROSE, 20))
	iv.add_child(prow)
	iv.add_child(UIKit.label("累计 %d 抽 · 每抽 150 钻或 1 张许愿券（优先用券）" % int(pt.total), 22, UIKit.C_MUTED))
	info.add_child(iv)
	content.add_child(info)

	# 按钮
	var brow := UIKit.hbox(14)
	var one := UIKit.button("许愿 ×1\n" + Gacha.cost_text(pool_id, 1), "ghost", 28, 120)
	one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	one.pressed.connect(func() -> void: _do_pull(1))
	var ten := UIKit.button("许愿 ×10\n" + Gacha.cost_text(pool_id, 10), "gold", 28, 120)
	ten.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ten.pressed.connect(func() -> void: _do_pull(10))
	brow.add_child(one)
	brow.add_child(ten)
	content.add_child(brow)
	var rules := UIKit.button("概率与规则说明", "dark", 24, 64)
	rules.pressed.connect(func() -> void:
		Router.alert("许愿规则", "· 5★ 基础概率 1%，60 抽后每抽 +10%，70 抽内必出 5★\n· 4★ 基础概率 7%，10 抽内必出 4★\n· 限定池：5★ 有 50% 为本期限定；若非限定，下一次 5★ 必为限定\n· 重复思念转化为星屑（3★ 5 / 4★ 20 / 5★ 100），可在商店兑换许愿券\n· 保底进度按卡池类型分别累计，不会清零"))
	content.add_child(rules)
	v.add_child(UIKit.scroll(content))
	add_child(page[0])


func _currency_row() -> Control:
	var h := UIKit.hbox(8)
	var ticket_kind := str(Gacha.pool(pool_id).get("ticket", "standard"))
	h.add_child(UIKit.currency("✦", Game.tickets(ticket_kind), UIKit.C_GOLD))
	h.add_child(UIKit.currency("◆", Game.diamonds(), UIKit.C_ACCENT))
	return h


func _do_pull(n: int) -> void:
	var r := Gacha.pull(pool_id, n)
	if not r.ok:
		Router.confirm("钻石不足", str(r.get("error", "")) + "\n去商店补充？", func() -> void: Router.push("Shop"), "去商店", "再想想")
		return
	_show_results(r.results, n)


func _show_results(results: Array, n: int) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.08, 0.96)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := UIKit.margin(30, 90, 30, 50)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := UIKit.vbox(20)
	var best := 3
	var new_count := 0
	for r in results:
		best = maxi(best, int(r.rarity))
		if bool(r.new):
			new_count += 1
	v.add_child(UIKit.label("许愿结果", 46, UIKit.rarity_color(best), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("本次最高 %s%s" % [UIKit.stars(best), "  · 新思念 ×%d" % new_count if new_count > 0 else ""], 26, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var grid := GridContainer.new()
	grid.columns = 5 if n > 1 else 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cells: Array = []
	for r in results:
		var c: Dictionary = Data.cards.get(r.card, {})
		var rarity := int(r.rarity)
		var cell := UIKit.vbox(6)
		var w := 186 if n > 1 else 520
		var box := UIKit.image_box(Data.texture("cards/" + str(r.card)), Vector2(w, int(w * 1.33)), 18, UIKit.rarity_color(rarity), 4 if rarity == 5 else 2)
		cell.add_child(box)
		cell.add_child(UIKit.label(UIKit.stars(rarity), 20 if n > 1 else 34, UIKit.rarity_color(rarity), HORIZONTAL_ALIGNMENT_CENTER, false))
		cell.add_child(UIKit.label(str(c.get("name", "")), 22 if n > 1 else 36, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, false))
		if n == 1:
			cell.add_child(UIKit.label(Data.char_name(str(c.get("char", ""))), 26, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER, false))
		if bool(r.new):
			var np := UIKit.pill("NEW", UIKit.C_ROSE, 18)
			np.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cell.add_child(np)
		else:
			cell.add_child(UIKit.label("重复 → 星屑", 18, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER, false))
		cell.modulate.a = 0.0
		grid.add_child(cell)
		cells.append(cell)
	v.add_child(grid)
	v.add_child(UIKit.spacer())
	var brow := UIKit.hbox(14)
	var again := UIKit.button("再许愿 ×%d" % n, "gold", 30, 100)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ok := UIKit.button("收下", "primary", 30, 100)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(again)
	brow.add_child(ok)
	v.add_child(brow)
	m.add_child(v)
	dim.add_child(m)
	Router.overlay.add_child(dim)
	ok.pressed.connect(func() -> void:
		dim.queue_free()
		rebuild())
	again.pressed.connect(func() -> void:
		dim.queue_free()
		rebuild()
		_do_pull(n))
	# 逐张翻出
	for i in cells.size():
		var cell: Control = cells[i]
		var tw := cell.create_tween()
		tw.tween_interval(0.12 * i + 0.1)
		tw.tween_property(cell, "modulate:a", 1.0, 0.25)
		tw.tween_callback(func() -> void: UIKit.pop(cell, 0.6, 0.35))
