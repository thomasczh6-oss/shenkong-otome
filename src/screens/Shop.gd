extends "res://src/screens/BaseScreen.gd"
## 商店（沙盒）：月卡、礼包、钻石、通行证、星屑兑换。所有购买都是模拟发放，不接真实支付。


func build() -> void:
	var page := UIKit.page("商店", func() -> void: Router.back(), _currency_row())
	var v: VBoxContainer = page[1]
	var content := UIKit.vbox(20)
	content.add_child(UIKit.label("原型为沙盒支付：点击即发放，正式版接入 Google Play / App Store 内购。", 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_month_card(content)
	_bundles(content)
	_pass(content)
	_diamonds(content)
	_exchange(content)
	v.add_child(UIKit.scroll(content))
	add_child(page[0])


func on_resume(_result: Variant) -> void:
	rebuild()


func _currency_row() -> Control:
	var h := UIKit.hbox(8)
	h.add_child(UIKit.currency("◆", Game.diamonds(), UIKit.C_ACCENT))
	h.add_child(UIKit.currency("★", Game.stardust(), UIKit.C_ROSE))
	return h


func _section(title: String) -> Label:
	return UIKit.label(title, 34, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)


func _buy(title: String, price: String, on_ok: Callable) -> void:
	Router.confirm("购买 " + title, "价格 %s（沙盒：直接发放，不会扣费）" % price, on_ok, "确认购买", "取消")


func _month_card(v: VBoxContainer) -> void:
	var mc: Dictionary = Data.shop.get("month_card", {})
	v.add_child(_section("月卡"))
	var panel := UIKit.panel(Color(UIKit.C_GOLD, 0.12), 26, 24, UIKit.C_GOLD, 2)
	var h := UIKit.hbox(14)
	var tv := UIKit.vbox(4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UIKit.label(str(mc.get("name", "月卡")), 32, UIKit.C_GOLD, HORIZONTAL_ALIGNMENT_LEFT, false))
	tv.add_child(UIKit.label(str(mc.get("desc", "")), 24, UIKit.C_MUTED))
	if Game.month_card_active():
		tv.add_child(UIKit.label("生效中 · 剩余 %d 天" % Game.month_card_days_left(), 22, UIKit.C_OK, HORIZONTAL_ALIGNMENT_LEFT, false))
	h.add_child(tv)
	var b := UIKit.button(("续费 " if Game.month_card_active() else "") + str(mc.get("price", "")), "gold", 28, 84)
	b.custom_minimum_size = Vector2(190, 84)
	b.pressed.connect(func() -> void:
		_buy(str(mc.get("name", "月卡")), str(mc.get("price", "")), func() -> void:
			Game.buy_month_card(int(mc.get("days", 30)), int(mc.get("instant", 300)))
			Router.toast("月卡已生效，立得 %d 钻" % int(mc.get("instant", 300)))
			rebuild()))
	h.add_child(b)
	panel.add_child(h)
	v.add_child(panel)


func _bundles(v: VBoxContainer) -> void:
	v.add_child(_section("礼包"))
	for bd in Data.shop.get("bundles", []):
		var id := str(bd.get("id", ""))
		var bought: Dictionary = Game.s.get("shop_bought", {})
		var once := bool(bd.get("once", false))
		var sold := once and bought.has(id)
		var panel := UIKit.panel(UIKit.C_PANEL, 24, 22, UIKit.C_LINE, 2)
		var h := UIKit.hbox(14)
		var tv := UIKit.vbox(4)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UIKit.label(str(bd.get("name", "")), 30, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
		tv.add_child(UIKit.label(UIKit.reward_text(bd.get("reward", {})), 24, UIKit.C_ACCENT))
		tv.add_child(UIKit.label(str(bd.get("desc", "")), 22, UIKit.C_MUTED))
		h.add_child(tv)
		var b := UIKit.button("已购买" if sold else str(bd.get("price", "")), "ghost" if sold else "primary", 28, 84)
		b.custom_minimum_size = Vector2(170, 84)
		b.disabled = sold
		b.pressed.connect(func() -> void:
			_buy(str(bd.get("name", "")), str(bd.get("price", "")), func() -> void:
				if not Game.s.has("shop_bought"):
					Game.s["shop_bought"] = {}
				Game.s.shop_bought[id] = true
				Game.grant(bd.get("reward", {}))
				Router.toast("已发放：" + UIKit.reward_text(bd.get("reward", {})))
				rebuild()))
		h.add_child(b)
		panel.add_child(h)
		v.add_child(panel)


func _pass(v: VBoxContainer) -> void:
	var ps: Dictionary = Data.shop.get("pass", {})
	var bp: Dictionary = Game.s.battle_pass
	var premium := bool(bp.get("premium", false))
	v.add_child(_section("通行证"))
	var panel := UIKit.panel(UIKit.C_PANEL, 24, 22, UIKit.C_LINE, 2)
	var pv := UIKit.vbox(10)
	var head := UIKit.hbox(12)
	var tv := UIKit.vbox(4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UIKit.label("%s · Lv.%d" % [str(ps.get("name", "通行证")), int(bp.level)], 30, UIKit.C_GOLD, HORIZONTAL_ALIGNMENT_LEFT, false))
	tv.add_child(UIKit.label(str(ps.get("desc", "")), 22, UIKit.C_MUTED))
	head.add_child(tv)
	if premium:
		head.add_child(UIKit.pill("高级已解锁", UIKit.C_GOLD, 20))
	else:
		var b := UIKit.button("解锁 " + str(ps.get("price", "")), "gold", 26, 76)
		b.custom_minimum_size = Vector2(190, 76)
		b.pressed.connect(func() -> void:
			_buy(str(ps.get("name", "通行证")), str(ps.get("price", "")), func() -> void:
				Game.s.battle_pass.premium = true
				Game.save()
				Router.toast("高级轨道已解锁")
				rebuild()))
		head.add_child(b)
	pv.add_child(head)
	var bar := UIKit.progress(int(bp.xp), Game.PASS_XP_PER_LEVEL, UIKit.C_GOLD, 14)
	pv.add_child(bar)
	pv.add_child(UIKit.label("经验 %d / %d · 完成每日任务和战斗获得经验" % [int(bp.xp), Game.PASS_XP_PER_LEVEL], 20, UIKit.C_MUTED))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for lv in range(1, Game.PASS_MAX_LEVEL + 1):
		var cell := UIKit.panel(Color(1, 1, 1, 0.05) if lv > int(bp.level) else Color(UIKit.C_GOLD, 0.12), 14, 8, Color(1, 1, 1, 0.08), 2)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := UIKit.vbox(4)
		cv.add_child(UIKit.label("Lv.%d" % lv, 18, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER, false))
		for prem in [false, true]:
			var r := Game.pass_reward(lv, prem)
			var claimable: bool = lv <= int(bp.level) and not Game.pass_claimed(lv, prem) and (not prem or premium)
			var txt := UIKit.reward_text(r).replace("回响许愿券", "回响券").replace("潮汐许愿券", "潮汐券")
			var b := UIKit.button(("✓ " if Game.pass_claimed(lv, prem) else "") + txt, "gold" if (prem and claimable) else ("primary" if claimable else "dark"), 16, 50)
			b.disabled = not claimable
			var captured_lv: int = lv
			var captured_prem: bool = prem
			b.pressed.connect(func() -> void:
				var got := Game.claim_pass(captured_lv, captured_prem)
				if got.size() > 0:
					Router.toast("领取：" + UIKit.reward_text(got))
					rebuild())
			cv.add_child(b)
		cell.add_child(cv)
		grid.add_child(cell)
	pv.add_child(grid)
	panel.add_child(pv)
	v.add_child(panel)


func _diamonds(v: VBoxContainer) -> void:
	v.add_child(_section("钻石"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for d in Data.shop.get("diamonds", []):
		var total := int(d.get("diamonds", 0)) + int(d.get("bonus", 0))
		var cell := UIKit.panel(UIKit.C_PANEL, 20, 16, UIKit.C_LINE, 2)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := UIKit.vbox(6)
		cv.add_child(UIKit.label("◆ %d" % int(d.get("diamonds", 0)), 30, UIKit.C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER, false))
		cv.add_child(UIKit.label("赠 %d" % int(d.get("bonus", 0)) if int(d.get("bonus", 0)) > 0 else " ", 20, UIKit.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, false))
		var b := UIKit.button(str(d.get("price", "")), "primary", 24, 64)
		b.pressed.connect(func() -> void:
			_buy("钻石 ×%d" % total, str(d.get("price", "")), func() -> void:
				Game.grant({"diamonds": total})
				Router.toast("钻石 +%d" % total)
				rebuild()))
		cv.add_child(b)
		cell.add_child(cv)
		grid.add_child(cell)
	v.add_child(grid)


func _exchange(v: VBoxContainer) -> void:
	var ex: Dictionary = Data.shop.get("exchange", {})
	var per := int(ex.get("stardust_per_ticket", 150))
	v.add_child(_section("星屑兑换"))
	var panel := UIKit.panel(UIKit.C_PANEL, 24, 22, UIKit.C_LINE, 2)
	var h := UIKit.hbox(14)
	var tv := UIKit.vbox(4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UIKit.label("★ 星屑 %d" % Game.stardust(), 30, UIKit.C_ROSE, HORIZONTAL_ALIGNMENT_LEFT, false))
	tv.add_child(UIKit.label(str(ex.get("desc", "")), 22, UIKit.C_MUTED))
	h.add_child(tv)
	var b := UIKit.button("兑换 1 张", "rose", 26, 76)
	b.custom_minimum_size = Vector2(170, 76)
	b.disabled = Game.stardust() < per
	b.pressed.connect(func() -> void:
		if Game.spend("stardust", per):
			Game.grant({"tickets_standard": 1})
			Router.toast("兑换成功：回响许愿券 +1")
			rebuild())
	h.add_child(b)
	panel.add_child(h)
	v.add_child(panel)
