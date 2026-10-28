extends "res://src/screens/BaseScreen.gd"
## 主线章节列表：章节 → 小节，按顺序解锁，已完成可重温。


func build() -> void:
	var page := UIKit.page("主线剧情", func() -> void: Router.back())
	var v: VBoxContainer = page[1]
	var list := UIKit.vbox(24)
	for ch in Data.chapters:
		list.add_child(_chapter_card(ch))
	v.add_child(UIKit.scroll(list))
	add_child(page[0])


func on_resume(_result: Variant) -> void:
	rebuild()


func _chapter_card(ch: Dictionary) -> Control:
	var ch_id := str(ch.id)
	var unlocked := Game.chapter_unlocked(ch_id)
	var req := str(ch.get("requires", ""))
	if not unlocked and req != "":
		var p := Game.chapter_progress(req)
		if p[0] >= p[1] and p[1] > 0:
			Game.unlock_chapter(ch_id)
			unlocked = true
	var panel := UIKit.panel(UIKit.C_PANEL, 28, 0, UIKit.C_LINE, 2)
	panel.clip_contents = true
	var v := UIKit.vbox(0)
	var cover := UIKit.image(Data.texture(str(ch.get("cover", ""))))
	cover.custom_minimum_size = Vector2(0, 260)
	if not unlocked:
		cover.modulate = Color(0.5, 0.5, 0.6)
	v.add_child(cover)
	var body := UIKit.margin(26, 20, 26, 24)
	var bv := UIKit.vbox(12)
	var prog := Game.chapter_progress(ch_id)
	var title_row := UIKit.hbox(12)
	title_row.add_child(UIKit.label(str(ch.title), 40, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	title_row.add_child(UIKit.spacer(0, true))
	title_row.add_child(UIKit.pill("%d / %d" % [prog[0], prog[1]] if unlocked else "未解锁", UIKit.C_ACCENT if unlocked else UIKit.C_MUTED, 24))
	bv.add_child(title_row)
	bv.add_child(UIKit.label(str(ch.get("summary", "")), 26, UIKit.C_MUTED))
	if unlocked:
		var prev_done := true
		for sc in ch.get("scenes", []):
			var sc_id := str(sc.id)
			var done := Game.scene_done(ch_id, sc_id)
			var available := prev_done
			var text := str(sc.title)
			var kind := "ghost"
			if done:
				text += "   ✓ 重温"
			elif available:
				kind = "primary"
			else:
				text += "  · 未解锁"
			var b := UIKit.button(text, kind, 30, 88)
			b.disabled = not available
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var reward: Dictionary = sc.get("reward", {})
			if not done and available and reward.size() > 0:
				b.text += "    奖励 " + UIKit.reward_text(reward)
			b.pressed.connect(func() -> void: Router.push("Story", {"chapter": ch_id, "scene": sc_id}))
			bv.add_child(b)
			prev_done = done
	else:
		bv.add_child(UIKit.label("完成前一章后解锁。", 26, UIKit.C_MUTED))
	body.add_child(bv)
	v.add_child(body)
	panel.add_child(v)
	return panel
