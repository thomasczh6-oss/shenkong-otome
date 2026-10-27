extends "res://src/screens/BaseScreen.gd"
## 日常：消息 / 电话 / 瞬间 / 签到任务。

const TABS := ["消息", "电话", "瞬间", "签到任务"]

var tab := 0


func build() -> void:
	Audio.play_bgm("daily")
	tab = int(params.get("tab", tab))
	var page := UIKit.page("日常", func() -> void: Router.back())
	var v: VBoxContainer = page[1]
	var tabs := UIKit.hbox(8)
	for i in TABS.size():
		var b := UIKit.button(TABS[i], "primary" if i == tab else "ghost", 26, 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx: int = i
		b.pressed.connect(func() -> void: set_tab(idx))
		tabs.add_child(b)
	v.add_child(tabs)
	var content := UIKit.vbox(18)
	match tab:
		0:
			_messages(content)
		1:
			_calls(content)
		2:
			_moments(content)
		_:
			_signin(content)
	v.add_child(UIKit.scroll(content))
	add_child(page[0])


func set_tab(i: int) -> void:
	tab = i
	params["tab"] = i
	rebuild()


func on_resume(_result: Variant) -> void:
	rebuild()


func _avatar_row(cid: String, title: String, sub: String, right: Control = null) -> PanelContainer:
	var ch := Data.character(cid)
	var panel := UIKit.panel(UIKit.C_PANEL, 24, 18, UIKit.C_LINE, 2)
	var h := UIKit.hbox(16)
	h.add_child(UIKit.image_box(Data.texture(Data.portrait_key(cid, "smile")), Vector2(110, 110), 55, Color(str(ch.get("color", "#4fd1c5"))), 3))
	var tv := UIKit.vbox(4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UIKit.label(title, 30, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	tv.add_child(UIKit.label(sub, 24, UIKit.C_MUTED))
	h.add_child(tv)
	if right != null:
		h.add_child(right)
	panel.add_child(h)
	return panel


# ---------------- 消息 ----------------

func _messages(v: VBoxContainer) -> void:
	for cid in Data.char_order:
		var chat: Dictionary = Data.chats.get(cid, {})
		var steps: Array = chat.get("steps", [])
		var st := Game.chat_state(cid)
		var preview := "暂无消息"
		var log: Array = st.get("log", [])
		if log.size() > 0:
			preview = str(log.back().get("text", ""))
		elif steps.size() > 0 and steps[0].has("him"):
			preview = str(steps[0].him)
		var unread := int(st.get("index", 0)) < steps.size()
		var right: Control = UIKit.pill("新消息", UIKit.C_ROSE, 20) if unread else null
		var row := _avatar_row(cid, Data.char_name(cid), preview, right)
		row.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed:
				Router.push("Chat", {"char": cid}))
		v.add_child(row)
	v.add_child(UIKit.label("回复消息会提升好感；每天的对话会在次日继续。", 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))


# ---------------- 电话 ----------------

func _calls(v: VBoxContainer) -> void:
	for cid in Data.char_order:
		var call: Dictionary = Data.calls.get(cid, {})
		var need := int(call.get("unlock_level", 3))
		var lv := Game.affection_level(cid)
		var ok := lv >= need
		var b := UIKit.button("拨打" if ok else "Lv.%d 解锁" % need, "primary" if ok else "ghost", 26, 72)
		b.custom_minimum_size = Vector2(170, 72)
		b.disabled = not ok
		b.pressed.connect(func() -> void: Router.push("Call", {"char": cid}))
		v.add_child(_avatar_row(cid, "%s · %s" % [Data.char_name(cid), str(call.get("title", "电话"))], "当前好感 Lv.%d %s" % [lv, Game.affection_name(cid)], b))
	v.add_child(UIKit.label("好感达到 Lv.3 后可以接到他的电话。", 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))


# ---------------- 瞬间 ----------------

func _moments(v: VBoxContainer) -> void:
	for mo in Data.moments:
		var cid := str(mo.get("char", ""))
		var mid := str(mo.get("id", ""))
		var ch := Data.character(cid)
		var panel := UIKit.panel(UIKit.C_PANEL, 24, 20, UIKit.C_LINE, 2)
		var pv := UIKit.vbox(12)
		var head := UIKit.hbox(12)
		head.add_child(UIKit.image_box(Data.texture(Data.portrait_key(cid, "smile")), Vector2(76, 76), 38, Color(str(ch.get("color", "#4fd1c5"))), 2))
		var hv := UIKit.vbox(0)
		hv.add_child(UIKit.label(Data.char_name(cid), 28, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
		hv.add_child(UIKit.label(str(mo.get("time", "")), 20, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT, false))
		head.add_child(hv)
		pv.add_child(head)
		pv.add_child(UIKit.label(str(mo.get("text", "")), 28, UIKit.C_TEXT))
		var img := UIKit.image_box(Data.texture(str(mo.get("img", ""))), Vector2(0, 440), 18)
		img.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pv.add_child(img)
		var liked := Game.moment_liked(mid)
		var like := UIKit.button("♥ %d" % (int(mo.get("likes", 0)) + (1 if liked else 0)), "rose" if liked else "ghost", 24, 60)
		like.custom_minimum_size = Vector2(150, 60)
		like.pressed.connect(func() -> void:
			if not Game.moment_liked(mid):
				Game.like_moment(mid)
				Game.add_affection(cid, 2)
				Router.toast("♥ %s 好感 +2" % Data.char_name(cid))
				rebuild())
		var actions := UIKit.hbox(10)
		actions.add_child(like)
		pv.add_child(actions)
		var commented: Dictionary = Game.s.moments.get("commented", {})
		if commented.has(mid):
			var cm: Dictionary = commented[mid]
			pv.add_child(UIKit.label("你：" + str(cm.get("text", "")), 24, UIKit.C_ACCENT))
			pv.add_child(UIKit.label("%s 回复你：%s" % [Data.char_name(cid), str(cm.get("reply", ""))], 24, UIKit.C_ROSE))
		else:
			pv.add_child(UIKit.label("评论：", 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT, false))
			for opt in mo.get("comments", []):
				var ob := UIKit.button(str(opt.get("text", "")), "dark", 24, 64)
				ob.alignment = HORIZONTAL_ALIGNMENT_LEFT
				ob.pressed.connect(func() -> void:
					if not Game.s.moments.has("commented"):
						Game.s.moments["commented"] = {}
					Game.s.moments.commented[mid] = {"text": str(opt.get("text", "")), "reply": str(opt.get("reply", ""))}
					Game.add_affection(cid, int(opt.get("aff", 2)))
					Game.task_progress("chat")
					Router.toast("♥ %s 好感 +%d" % [Data.char_name(cid), int(opt.get("aff", 2))])
					rebuild())
				pv.add_child(ob)
		panel.add_child(pv)
		v.add_child(panel)


# ---------------- 签到 / 任务 ----------------

func _signin(v: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.C_PANEL, 24, 22, UIKit.C_LINE, 2)
	var pv := UIKit.vbox(12)
	var head := UIKit.hbox(10)
	head.add_child(UIKit.label("每日签到", 32, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	head.add_child(UIKit.spacer(0, true))
	head.add_child(UIKit.label("已连续 %d 天" % int(Game.s.signin.get("streak", 0)), 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_RIGHT, false))
	pv.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 8)
	var today_i := Game.signin_day()
	for i in Game.SIGNIN_REWARDS.size():
		var claimed := i < today_i or (i == today_i and not Game.can_signin())
		var is_today := i == today_i and Game.can_signin()
		var cell := UIKit.panel(Color(UIKit.C_ACCENT, 0.2) if is_today else Color(1, 1, 1, 0.05), 14, 8, UIKit.C_ACCENT if is_today else Color(1, 1, 1, 0.08), 2)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := UIKit.vbox(2)
		cv.add_child(UIKit.label("第%d天" % (i + 1), 18, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER, false))
		cv.add_child(UIKit.label(UIKit.reward_text(Game.SIGNIN_REWARDS[i]).replace("×", "\n×"), 18, UIKit.C_TEXT if not claimed else UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER, false))
		cv.add_child(UIKit.label("✓" if claimed else " ", 18, UIKit.C_OK, HORIZONTAL_ALIGNMENT_CENTER, false))
		cell.add_child(cv)
		grid.add_child(cell)
	pv.add_child(grid)
	var sb := UIKit.button("签到领取" if Game.can_signin() else "今日已签到", "primary" if Game.can_signin() else "ghost", 28, 84)
	sb.disabled = not Game.can_signin()
	sb.pressed.connect(func() -> void:
		var r := Game.do_signin()
		Router.toast("签到成功：" + UIKit.reward_text(r))
		rebuild())
	pv.add_child(sb)
	panel.add_child(pv)
	v.add_child(panel)

	# 月卡
	if Game.month_card_active():
		var mc := UIKit.panel(Color(UIKit.C_GOLD, 0.12), 24, 22, UIKit.C_GOLD, 2)
		var mh := UIKit.hbox(12)
		var mv := UIKit.vbox(2)
		mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mv.add_child(UIKit.label("潮汐月卡 · 剩余 %d 天" % Game.month_card_days_left(), 28, UIKit.C_GOLD, HORIZONTAL_ALIGNMENT_LEFT, false))
		mv.add_child(UIKit.label("每日可领 100 钻", 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT, false))
		mh.add_child(mv)
		var cb := UIKit.button("领取" if Game.month_card_claimable() else "已领取", "gold" if Game.month_card_claimable() else "ghost", 26, 72)
		cb.custom_minimum_size = Vector2(150, 72)
		cb.disabled = not Game.month_card_claimable()
		cb.pressed.connect(func() -> void:
			Game.claim_month_card()
			Router.toast("月卡：钻石 +100")
			rebuild())
		mh.add_child(cb)
		mc.add_child(mh)
		v.add_child(mc)

	# 任务
	var tp := UIKit.panel(UIKit.C_PANEL, 24, 22, UIKit.C_LINE, 2)
	var tv := UIKit.vbox(10)
	tv.add_child(UIKit.label("每日任务", 32, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	for task in Game.DAILY_TASKS:
		var st := Game.task_state(task)
		var row := UIKit.hbox(12)
		var lv := UIKit.vbox(2)
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lv.add_child(UIKit.label(str(task.name), 26, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
		lv.add_child(UIKit.label("%d/%d · %s" % [st.progress, st.goal, UIKit.reward_text(task.reward)], 20, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT, false))
		row.add_child(lv)
		var b := UIKit.button("已领取" if st.claimed else ("领取" if st.done else "未完成"), "primary" if (st.done and not st.claimed) else "ghost", 24, 64)
		b.custom_minimum_size = Vector2(140, 64)
		b.disabled = not st.done or st.claimed
		var captured: Dictionary = task
		b.pressed.connect(func() -> void:
			var r := Game.claim_task(captured)
			if r.size() > 0:
				Router.toast("领取：" + UIKit.reward_text(r))
			rebuild())
		row.add_child(b)
		tv.add_child(row)
	var bp: Dictionary = Game.s.battle_pass
	tv.add_child(UIKit.divider())
	var prow := UIKit.hbox(12)
	prow.add_child(UIKit.label("星海通行证 Lv.%d" % int(bp.level), 24, UIKit.C_GOLD, HORIZONTAL_ALIGNMENT_LEFT, false))
	var bar := UIKit.progress(int(bp.xp), Game.PASS_XP_PER_LEVEL, UIKit.C_GOLD, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prow.add_child(bar)
	var pb := UIKit.button("查看", "ghost", 22, 56)
	pb.pressed.connect(func() -> void: Router.push("Shop", {"section": "pass"}))
	prow.add_child(pb)
	tv.add_child(prow)
	tp.add_child(tv)
	v.add_child(tp)
