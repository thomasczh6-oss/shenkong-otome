extends "res://src/screens/BaseScreen.gd"
## 我的：改名、数据、设置、清档，以及开发用的「生图设置」与「AI 工坊」。

var preview_box: PanelContainer = null
var status_label: Label = null


func build() -> void:
	var page := UIKit.page("我的", func() -> void: Router.back())
	var v: VBoxContainer = page[1]
	var content := UIKit.vbox(20)
	_profile(content)
	_settings(content)
	_imagegen(content)
	_about(content)
	v.add_child(UIKit.scroll(content))
	add_child(page[0])


func _section(title: String) -> Label:
	return UIKit.label(title, 34, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)


func _profile(v: VBoxContainer) -> void:
	v.add_child(_section("观测员档案"))
	var panel := UIKit.panel(UIKit.C_PANEL, 24, 22, UIKit.C_LINE, 2)
	var pv := UIKit.vbox(12)
	var row := UIKit.hbox(12)
	var edit := UIKit.line_edit("你的名字", Game.player_name())
	edit.max_length = 10
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	var save := UIKit.button("改名", "primary", 26, 96)
	save.custom_minimum_size = Vector2(150, 96)
	save.pressed.connect(func() -> void:
		Game.set_player_name(edit.text)
		Router.toast("已改名为 " + Game.player_name()))
	row.add_child(save)
	pv.add_child(row)
	var owned := 0
	for id in Data.card_order:
		if Game.owns(id):
			owned += 1
	var total_aff := 0
	for cid in Data.char_order:
		total_aff += Game.affection(cid)
	var st: Dictionary = Game.s.stats
	pv.add_child(UIKit.label("钻石 %d · 金币 %d · 星屑 %d" % [Game.diamonds(), Game.gold(), Game.stardust()], 24, UIKit.C_MUTED))
	pv.add_child(UIKit.label("思念 %d/%d · 许愿 %d 次 · 战斗 %d 场（胜 %d）· 好感总计 %d" % [owned, Data.card_order.size(), int(st.pulls), int(st.battles), int(st.wins), total_aff], 24, UIKit.C_MUTED))
	for cid in Data.char_order:
		pv.add_child(UIKit.label("%s  ♥ Lv.%d %s（%d）" % [Data.char_name(cid), Game.affection_level(cid), Game.affection_name(cid), Game.affection(cid)], 24, UIKit.C_ROSE))
	panel.add_child(pv)
	v.add_child(panel)


func _settings(v: VBoxContainer) -> void:
	v.add_child(_section("设置"))
	var panel := UIKit.panel(UIKit.C_PANEL, 24, 22, UIKit.C_LINE, 2)
	var pv := UIKit.vbox(12)
	var row := UIKit.hbox(10)
	row.add_child(UIKit.label("文字速度", 26, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	var cur := float(Game.s.settings.get("text_speed", 1.0))
	for pair in [["慢", 0.7], ["中", 1.0], ["快", 1.6]]:
		var b := UIKit.button(str(pair[0]), "primary" if absf(cur - float(pair[1])) < 0.01 else "ghost", 24, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val: float = pair[1]
		b.pressed.connect(func() -> void:
			Game.s.settings.text_speed = val
			Game.save()
			rebuild())
		row.add_child(b)
	pv.add_child(row)
	for spec in [["音乐", "bgm_volume", 0.7], ["配音", "voice_volume", 1.0]]:
		var vrow := UIKit.hbox(10)
		vrow.add_child(UIKit.label(str(spec[0]) + "音量", 26, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
		var key: String = spec[1]
		var now := float(Game.s.settings.get(key, spec[2]))
		for pair in [["关", 0.0], ["低", 0.4], ["中", 0.7], ["高", 1.0]]:
			var b := UIKit.button(str(pair[0]), "primary" if absf(now - float(pair[1])) < 0.01 else "ghost", 24, 64)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var val: float = pair[1]
			b.pressed.connect(func() -> void:
				Game.s.settings[key] = val
				Game.save()
				Audio.apply_volume()
				rebuild())
			vrow.add_child(b)
		pv.add_child(vrow)
	var reset := UIKit.button("清除存档，重新开始", "danger", 26, 84)
	reset.pressed.connect(func() -> void:
		Router.confirm("清除存档？", "所有进度、思念和好感都会清空，无法恢复。", func() -> void:
			Game.reset()
			Router.go("Title"), "清除", "取消"))
	pv.add_child(reset)
	panel.add_child(pv)
	v.add_child(panel)


func _imagegen(v: VBoxContainer) -> void:
	v.add_child(_section("生图设置（开发用）"))
	var panel := UIKit.panel(UIKit.C_PANEL, 24, 22, UIKit.C_LINE, 2)
	var pv := UIKit.vbox(12)
	pv.add_child(UIKit.label("调用方式与 drma 项目一致：OpenAI 兼容网关（image 2）或 drma 后端 t2i。正式版请改为服务端生成，不要把密钥打进包里。", 22, UIKit.C_MUTED))
	var brow := UIKit.hbox(10)
	for be in ["openai", "drma"]:
		var b := UIKit.button("OpenAI 兼容网关" if be == "openai" else "drma 后端", "primary" if str(ImageGen.cfg.backend) == be else "ghost", 24, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var captured: String = be
		b.pressed.connect(func() -> void:
			ImageGen.cfg.backend = captured
			ImageGen.save_cfg()
			rebuild())
		brow.add_child(b)
	pv.add_child(brow)
	var fields: Array = []
	if str(ImageGen.cfg.backend) == "drma":
		fields = [["drma_base", "后端地址"], ["drma_token", "测试账号 token"]]
	else:
		fields = [["openai_base", "网关地址（…/v1）"], ["openai_key", "API key"], ["openai_model", "模型（gpt-image-2）"], ["openai_quality", "质量 low / medium / high"]]
	var edits: Dictionary = {}
	for f in fields:
		var e := UIKit.line_edit(str(f[1]), str(ImageGen.cfg.get(f[0], "")))
		if str(f[0]).ends_with("key") or str(f[0]).ends_with("token"):
			e.secret = true
		edits[f[0]] = e
		pv.add_child(e)
	var save := UIKit.button("保存配置", "primary", 26, 80)
	save.pressed.connect(func() -> void:
		for k in edits.keys():
			ImageGen.cfg[k] = edits[k].text.strip_edges()
		ImageGen.save_cfg()
		Router.toast("已保存"))
	pv.add_child(save)
	panel.add_child(pv)
	v.add_child(panel)

	# AI 工坊
	v.add_child(_section("AI 工坊"))
	var wp := UIKit.panel(UIKit.C_PANEL, 24, 22, UIKit.C_LINE, 2)
	var wv := UIKit.vbox(12)
	wv.add_child(UIKit.label("输入资源 key（如 backgrounds/harbor_night、characters/shen_yan/calm、cards/shen_yan_5_1）和提示词，生成后立即替换游戏内对应图片。", 22, UIKit.C_MUTED))
	var key_edit := UIKit.line_edit("资源 key", "backgrounds/harbor_night")
	wv.add_child(key_edit)
	var prompt_edit := TextEdit.new()
	prompt_edit.custom_minimum_size = Vector2(0, 220)
	prompt_edit.placeholder_text = "提示词（留空则用 assets/manifest.json 里的）"
	prompt_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	prompt_edit.add_theme_font_size_override("font_size", 26)
	prompt_edit.add_theme_stylebox_override("normal", UIKit.sb(Color(1, 1, 1, 0.06), 20, UIKit.C_LINE, 2, 16))
	prompt_edit.add_theme_stylebox_override("focus", UIKit.sb(Color(1, 1, 1, 0.08), 20, UIKit.C_ACCENT, 2, 16))
	wv.add_child(prompt_edit)
	var fill := UIKit.button("从清单填入提示词", "ghost", 22, 56)
	fill.pressed.connect(func() -> void:
		var p := Data.prompt_for(key_edit.text.strip_edges())
		prompt_edit.text = p if p != "" else "（清单里没有这个 key）")
	wv.add_child(fill)
	var ratio_row := UIKit.hbox(10)
	var ratio := "9:16"
	var ratio_btns: Array = []
	for r in ["9:16", "3:4", "1:1", "16:9"]:
		var b := UIKit.button(r, "primary" if r == ratio else "ghost", 22, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ratio_row.add_child(b)
		ratio_btns.append(b)
	for i in ratio_btns.size():
		var btn: Button = ratio_btns[i]
		btn.pressed.connect(func() -> void:
			ratio = btn.text
			for j in ratio_btns.size():
				var other: Button = ratio_btns[j]
				other.add_theme_stylebox_override("normal", UIKit.sb(UIKit.C_ACCENT if other == btn else Color(1, 1, 1, 0.06), 28, UIKit.C_LINE, 0 if other == btn else 2))
				other.add_theme_color_override("font_color", UIKit.C_BG if other == btn else UIKit.C_TEXT))
	wv.add_child(ratio_row)
	status_label = UIKit.label("未配置密钥时无法生成；配置后点「生成」。" if not ImageGen.configured() else "已配置，可以生成。", 22, UIKit.C_MUTED)
	wv.add_child(status_label)
	preview_box = UIKit.image_box(Data.texture(key_edit.text), Vector2(0, 600), 20, UIKit.C_LINE, 2)
	preview_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wv.add_child(preview_box)
	var gen := UIKit.button("生成并替换", "gold", 28, 90)
	gen.disabled = not ImageGen.configured()
	gen.pressed.connect(func() -> void:
		var key := key_edit.text.strip_edges()
		var prompt := prompt_edit.text.strip_edges()
		if prompt == "":
			prompt = Data.prompt_for(key)
		if key == "" or prompt == "":
			Router.toast("需要 key 和提示词")
			return
		gen.disabled = true
		status_label.text = "生成中…"
		var r: Dictionary = await ImageGen.generate_to(key, prompt, ratio)
		if not is_instance_valid(self):
			return
		gen.disabled = false
		if r.ok:
			status_label.text = "已生成并保存到 " + str(r.path)
			var img: TextureRect = preview_box.get_child(0)
			img.texture = r.texture
		else:
			status_label.text = "失败：" + str(r.get("msg", "")))
	wv.add_child(gen)
	wp.add_child(wv)
	v.add_child(wp)
	if not ImageGen.progress.is_connected(_on_progress):
		ImageGen.progress.connect(_on_progress)


func _on_progress(msg: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = msg


func _exit_tree() -> void:
	if ImageGen.progress.is_connected(_on_progress):
		ImageGen.progress.disconnect(_on_progress)


func _about(v: VBoxContainer) -> void:
	v.add_child(_section("关于"))
	var panel := UIKit.panel(UIKit.C_PANEL, 24, 22, UIKit.C_LINE, 2)
	var pv := UIKit.vbox(6)
	pv.add_child(UIKit.label("深与空恋 · 原型 0.1", 28, UIKit.C_TEXT))
	pv.add_child(UIKit.label("Godot 4.4 · 竖屏 1080×1920 · 剧情 / 好感 / 许愿 / 思念 / 战斗 / 日常 / 商店", 22, UIKit.C_MUTED))
	pv.add_child(UIKit.label("美术由 image 2 生成（tools/gen_assets.py），当前为占位图。", 22, UIKit.C_MUTED))
	panel.add_child(pv)
	v.add_child(panel)
