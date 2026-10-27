extends "res://src/screens/BaseScreen.gd"
## 轻量实时战斗：点击「攻击」出手，技能有冷却，敌人攻击前会预警、可「闪避」，
## 攻击积攒共鸣槽，满了可以和搭档释放「共鸣技」。参考《恋与深空》把战斗做轻、做爽的思路。

var enemy_id := ""
var partner_id := ""
var enemy: Dictionary = {}
var partner: Dictionary = {}
var stats: Dictionary = {}

var ehp := 0.0
var ehp_max := 1.0
var php := 0.0
var php_max := 1.0
var meter := 0.0
var attack_cd := 0.0
var skill_cd := 0.0
var dodge_cd := 0.0
var invuln := 0.0
var enemy_timer := 0.0
var telegraphing := false
var partner_timer := 0.0
var over := false
var elapsed := 0.0

var enemy_img: TextureRect
var enemy_box: Control
var enemy_bar: ProgressBar
var enemy_hp_label: Label
var player_bar: ProgressBar
var player_hp_label: Label
var meter_bar: ProgressBar
var warn_label: Label
var log_label: Label
var attack_btn: Button
var skill_btn: Button
var dodge_btn: Button
var res_btn: Button
var partner_img: TextureRect


func build() -> void:
	enemy_id = str(params.get("enemy", "tide_shade"))
	partner_id = str(params.get("partner", "shen_yan"))
	enemy = Data.enemy(enemy_id)
	partner = Data.character(partner_id)
	stats = Game.team_stats(partner_id)
	ehp_max = float(enemy.get("hp", 900))
	ehp = ehp_max
	php_max = float(stats.hp)
	php = php_max

	var bg := UIKit.image(Data.texture("backgrounds/battle_rift"))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.6, 0.62, 0.8)
	add_child(bg)
	add_child(UIKit.gradient_rect(Color(0.02, 0.03, 0.1, 0.2), Color(0.02, 0.03, 0.1, 0.9)))

	var m := UIKit.margin(36, 70, 36, 40)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(16)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 敌人
	var top := UIKit.hbox(12)
	top.add_child(UIKit.label(str(enemy.get("name", "潮影")) + ("  BOSS" if bool(enemy.get("boss", false)) else ""), 40, UIKit.C_DANGER, HORIZONTAL_ALIGNMENT_LEFT, false))
	top.add_child(UIKit.spacer(0, true))
	enemy_hp_label = UIKit.label("", 26, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_RIGHT, false)
	top.add_child(enemy_hp_label)
	v.add_child(top)
	enemy_bar = UIKit.progress(ehp, ehp_max, UIKit.C_DANGER, 20)
	v.add_child(enemy_bar)

	enemy_box = CenterContainer.new()
	enemy_box.custom_minimum_size = Vector2(0, 620)
	enemy_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_img = UIKit.image(Data.texture(str(enemy.get("img", "enemies/tide_shade"))), false)
	enemy_img.custom_minimum_size = Vector2(560, 560)
	enemy_box.add_child(enemy_img)
	v.add_child(enemy_box)
	warn_label = UIKit.label("", 30, UIKit.C_DANGER, HORIZONTAL_ALIGNMENT_CENTER, false)
	warn_label.custom_minimum_size = Vector2(0, 44)
	v.add_child(warn_label)
	v.add_child(UIKit.label(str(enemy.get("desc", "")), 24, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.spacer())

	# 我方
	var me := UIKit.hbox(16)
	var pbox := UIKit.image_box(Data.texture(Data.portrait_key(partner_id, "serious")), Vector2(150, 190), 22, Color(str(partner.get("color", "#4fd1c5"))), 3)
	partner_img = pbox.get_child(0)
	me.add_child(pbox)
	var mv := UIKit.vbox(8)
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UIKit.hbox(10)
	row.add_child(UIKit.label("%s × %s" % [Game.player_name(), str(partner.get("name", ""))], 30, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	row.add_child(UIKit.spacer(0, true))
	player_hp_label = UIKit.label("", 24, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_RIGHT, false)
	row.add_child(player_hp_label)
	mv.add_child(row)
	player_bar = UIKit.progress(php, php_max, UIKit.C_OK, 20)
	mv.add_child(player_bar)
	mv.add_child(UIKit.label("共鸣槽", 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT, false))
	meter_bar = UIKit.progress(0, 100, UIKit.C_ROSE, 16)
	mv.add_child(meter_bar)
	mv.add_child(UIKit.label("攻击 %d · 防御 %d · 战力 %d" % [stats.atk, stats.def, Game.power(partner_id)], 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT, false))
	me.add_child(mv)
	v.add_child(me)

	log_label = UIKit.label("潮影出现了！点击「攻击」出手，看到预警就「闪避」。", 24, UIKit.C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	log_label.custom_minimum_size = Vector2(0, 70)
	v.add_child(log_label)

	# 操作
	var grid := UIKit.hbox(10)
	attack_btn = UIKit.button("攻击", "primary", 32, 120)
	attack_btn.pressed.connect(_attack)
	var skill: Dictionary = partner.get("skill", {})
	skill_btn = UIKit.button(str(skill.get("name", "技能")), "dark", 30, 120)
	skill_btn.pressed.connect(_skill)
	dodge_btn = UIKit.button("闪避", "dark", 30, 120)
	dodge_btn.pressed.connect(_dodge)
	var res: Dictionary = partner.get("resonance", {})
	res_btn = UIKit.button(str(res.get("name", "共鸣")), "rose", 28, 120)
	res_btn.pressed.connect(_resonance)
	for b in [attack_btn, skill_btn, dodge_btn, res_btn]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	v.add_child(grid)
	m.add_child(v)
	add_child(m)
	_refresh()


func _process(delta: float) -> void:
	if over:
		return
	elapsed += delta
	attack_cd = maxf(0.0, attack_cd - delta)
	skill_cd = maxf(0.0, skill_cd - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	invuln = maxf(0.0, invuln - delta)

	# 敌人攻击节奏：预警 → 出手
	enemy_timer += delta
	var interval := float(enemy.get("attack_interval", 2.4))
	var tele := float(enemy.get("telegraph", 0.9))
	if not telegraphing and enemy_timer >= interval - tele:
		telegraphing = true
		warn_label.text = "⚠ %s 准备攻击！" % str(enemy.get("name", ""))
		enemy_img.modulate = Color(1.0, 0.45, 0.45)
	if enemy_timer >= interval:
		enemy_timer = 0.0
		telegraphing = false
		warn_label.text = ""
		enemy_img.modulate = Color(1, 1, 1)
		_enemy_attack()

	# 搭档自动助攻
	partner_timer += delta
	if partner_timer >= 3.0:
		partner_timer = 0.0
		var dmg := _damage(float(stats.atk) * 0.55, float(enemy.get("def", 10)))
		_hit_enemy(dmg, "%s 助攻" % str(partner.get("name", "")), UIKit.C_ACCENT)

	_refresh_buttons()


func _damage(atk: float, def: float) -> int:
	var base := atk * randf_range(0.9, 1.12) - def * 0.5
	return maxi(5, int(base))


func _attack() -> void:
	if over or attack_cd > 0.0:
		return
	attack_cd = 0.42
	var dmg := _damage(float(stats.atk), float(enemy.get("def", 10)))
	meter = minf(100.0, meter + 12.0)
	_hit_enemy(dmg, "普攻", UIKit.C_TEXT)


func _skill() -> void:
	if over or skill_cd > 0.0:
		return
	var skill: Dictionary = partner.get("skill", {})
	skill_cd = float(skill.get("cooldown", 6.0))
	var dmg := _damage(float(stats.atk) * float(skill.get("mult", 1.8)), float(enemy.get("def", 10)))
	meter = minf(100.0, meter + 20.0)
	_hit_enemy(dmg, str(skill.get("name", "技能")), UIKit.element_color(str(partner.get("element", ""))))


func _dodge() -> void:
	if over or dodge_cd > 0.0:
		return
	dodge_cd = 2.4
	invuln = 0.75
	log_label.text = "闪避！0.75 秒内无敌"
	var tw := create_tween()
	tw.tween_property(partner_img, "modulate", Color(1, 1, 1, 0.4), 0.1)
	tw.tween_property(partner_img, "modulate", Color(1, 1, 1, 1.0), 0.5)


func _resonance() -> void:
	if over or meter < 100.0:
		Router.toast("共鸣槽未满")
		return
	meter = 0.0
	var res: Dictionary = partner.get("resonance", {})
	var dmg := _damage(float(stats.atk) * float(res.get("mult", 3.0)), float(enemy.get("def", 10)) * 0.5)
	_flash(Color(str(partner.get("color", "#f2a7b5"))))
	_hit_enemy(dmg, "共鸣技 · " + str(res.get("name", "")), UIKit.C_ROSE)


func _hit_enemy(dmg: int, label: String, color: Color) -> void:
	ehp = maxf(0.0, ehp - dmg)
	log_label.text = "%s 造成 %d 伤害" % [label, dmg]
	_popup("-%d" % dmg, color, enemy_box)
	var tw := create_tween()
	tw.tween_property(enemy_img, "position:x", enemy_img.position.x + 14, 0.05)
	tw.tween_property(enemy_img, "position:x", enemy_img.position.x, 0.08)
	_refresh()
	if ehp <= 0.0:
		_finish(true)


func _enemy_attack() -> void:
	if invuln > 0.0:
		log_label.text = "闪避成功！"
		_popup("MISS", UIKit.C_OK, partner_img)
		return
	var dmg := _damage(float(enemy.get("atk", 60)), float(stats.def))
	php = maxf(0.0, php - dmg)
	log_label.text = "%s 攻击，你受到 %d 伤害" % [str(enemy.get("name", "")), dmg]
	_popup("-%d" % dmg, UIKit.C_DANGER, partner_img)
	_flash(Color(1, 0.3, 0.3, 0.35))
	_refresh()
	if php <= 0.0:
		_finish(false)


func _popup(text: String, color: Color, anchor: Control) -> void:
	var l := UIKit.label(text, 44, color, HORIZONTAL_ALIGNMENT_CENTER, false)
	add_child(l)
	var base := anchor.global_position + anchor.size / 2.0 + Vector2(randf_range(-60, 60), -40)
	l.global_position = base
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position:y", base.y - 120, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tw.chain().tween_callback(l.queue_free)


func _flash(color: Color) -> void:
	var f := ColorRect.new()
	f.color = color
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "modulate:a", 0.0, 0.35)
	tw.tween_callback(f.queue_free)


func _refresh() -> void:
	enemy_bar.value = ehp
	enemy_hp_label.text = "%d / %d" % [int(ehp), int(ehp_max)]
	player_bar.value = php
	player_hp_label.text = "%d / %d" % [int(php), int(php_max)]
	meter_bar.value = meter


func _refresh_buttons() -> void:
	meter_bar.value = meter
	attack_btn.disabled = attack_cd > 0.0
	skill_btn.disabled = skill_cd > 0.0
	var skill: Dictionary = partner.get("skill", {})
	skill_btn.text = str(skill.get("name", "技能")) + ("" if skill_cd <= 0.0 else " %.1f" % skill_cd)
	dodge_btn.disabled = dodge_cd > 0.0
	dodge_btn.text = "闪避" + ("" if dodge_cd <= 0.0 else " %.1f" % dodge_cd)
	res_btn.disabled = meter < 100.0


func _finish(win: bool) -> void:
	if over:
		return
	over = true
	Game.s.stats.battles = int(Game.s.stats.battles) + 1
	var reward: Dictionary = enemy.get("reward", {})
	if win:
		Game.s.stats.wins = int(Game.s.stats.wins) + 1
		Game.task_progress("battle")
		Game.grant(reward)
	else:
		Game.save()
	var panel := UIKit.panel(UIKit.C_PANEL, 32, 40, UIKit.C_LINE, 2)
	panel.custom_minimum_size = Vector2(880, 0)
	var v := UIKit.vbox(16)
	v.add_child(UIKit.label("胜利" if win else "失败", 56, UIKit.C_GOLD if win else UIKit.C_DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("用时 %.1f 秒" % elapsed, 26, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if win:
		v.add_child(UIKit.label("获得：" + UIKit.reward_text(reward), 30, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(UIKit.label("%s：「%s」" % [str(partner.get("name", "")), _win_line()], 28, UIKit.C_ROSE, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		v.add_child(UIKit.label("提升思念卡等级或好感度可以变强。", 26, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var ok := UIKit.button("继续", "primary", 34, 96)
	v.add_child(ok)
	panel.add_child(v)
	var dim := Router.modal(panel, false)
	ok.pressed.connect(func() -> void:
		dim.queue_free()
		Router.back({"win": win}))


func _win_line() -> String:
	match partner_id:
		"shen_yan":
			return "……没受伤吧。下次离我近一点。"
		"gu_ci":
			return "配合得很好。我就知道，你可以的。"
		"lu_zhuo":
			return "爽！下次还跟我组队，说定了。"
	return "干得漂亮。"
