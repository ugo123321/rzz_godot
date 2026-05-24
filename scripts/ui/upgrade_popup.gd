extends Control
class_name UpgradePopup

const EffectHelperScript := preload("res://scripts/utils/effect_helper.gd")

const PREVIEW_VIEWPORT_SIZE := Vector2i(72, 72)

signal upgrade_picked(index: int)

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var rarity_label: Label = $Panel/VBox/RarityLabel
@onready var cards: HBoxContainer = $Panel/VBox/Cards

var battle: Node
var upgrade_manager: UpgradeManager
var _fx: Dictionary = {}
var _anim_time := 0.0
var _draw_timer := 0.0


func setup(battle_node: Node, manager: UpgradeManager) -> void:
	battle = battle_node
	upgrade_manager = manager
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_layout()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 10)


func _apply_panel_layout() -> void:
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 14.0
	panel.offset_top = 14.0
	panel.offset_right = -14.0
	panel.offset_bottom = -14.0


func show_popup() -> void:
	visible = true
	_anim_time = 0.0
	_fx = GameConfig.get_upgrade_fx(upgrade_manager.rolled_rarity)
	_apply_panel_layout()
	call_deferred("_rebuild_cards")
	queue_redraw()


func hide_popup() -> void:
	visible = false
	for child in cards.get_children():
		child.queue_free()


func _process(delta: float) -> void:
	if not visible:
		return
	_anim_time += delta
	_draw_timer -= delta
	if _draw_timer <= 0.0:
		_draw_timer = 0.033
		queue_redraw()


func _draw() -> void:
	if not visible or _fx.is_empty():
		return
	var size := get_viewport_rect().size
	var pop_t := _ease_out(clampf(_anim_time / 0.45, 0.0, 1.0))
	var tier_color := Color(str(_fx.get("color_hex", "#ffffff")))

	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, float(_fx.get("overlay", 0.76)) * pop_t))

	var edge_glow := float(_fx.get("edge_glow", 0.0))
	if edge_glow > 0.0:
		var pulse := 1.0
		if int(_fx.get("pulse", 0)) != 0:
			pulse = 0.85 + sin(_anim_time * 8.0) * 0.15
		var center := size * 0.5
		var radius := maxf(size.x, size.y) * 0.72
		draw_circle(center, radius, Color(tier_color, edge_glow * 0.25 * pop_t * pulse))
		draw_arc(center, radius * 0.92, 0.0, TAU, 64, Color(tier_color, edge_glow * 0.45 * pop_t * pulse), 8.0)

	if int(_fx.get("rays", 0)) != 0:
		var center := size * 0.5
		for i in range(8):
			var ang := float(i) * TAU / 8.0 + _anim_time * 0.4
			var dir := Vector2(cos(ang), sin(ang))
			var p1 := center - dir * size.x * 0.1
			var p2 := center + dir * size.x * 0.55
			draw_line(p1, p2, Color(tier_color, 0.12 * pop_t), size.y * 0.12)

	var spark_count := int(_fx.get("spark_count", 0))
	if spark_count > 0:
		var seed := int(_anim_time * 8.0)
		for i in range(spark_count):
			var a := float((i * 47 + seed) % 360) / 360.0 * TAU
			var dist := float((i * 19 + seed) % 100) / 100.0
			var px := size.x * 0.5 + cos(a) * size.x * 0.38 * dist
			var py := size.y * 0.5 + sin(a) * size.y * 0.32 * dist
			var sz := 2.0 + float(i % 3)
			draw_rect(Rect2(px, py, sz, sz), Color(tier_color, 0.25 + float(i % 4) * 0.12))


func _calc_card_metrics(choice_count: int) -> Dictionary:
	var vp := get_viewport_rect().size
	var panel_w := vp.x - 28.0
	var panel_h := vp.y - 28.0
	var n := maxi(1, choice_count)
	var sep := 10.0
	var inner_pad := 16.0
	var card_w: float = floor((panel_w - inner_pad * 2.0 - sep * float(n - 1)) / float(n))
	card_w = clampf(card_w, 92.0, 150.0)
	var card_h: float = clampf(panel_h * 0.48, 108.0, 140.0)
	return {
		"card_size": Vector2(card_w, card_h),
		"preview_h": clampf(card_h * 0.38, 48.0, 56.0),
		"name_font": 13 if card_w < 120.0 else 14,
		"desc_font": 10 if card_w < 120.0 else 11,
	}


func _create_preview_widget(preview_frames: SpriteFrames) -> Control:
	var box := CenterContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if preview_frames == null:
		return box

	var scale: float = EffectHelperScript.preview_scale(preview_frames)
	var viewport := SubViewport.new()
	viewport.size = PREVIEW_VIEWPORT_SIZE
	viewport.transparent_bg = true
	viewport.handle_input_locally = false

	var holder := SubViewportContainer.new()
	holder.custom_minimum_size = Vector2(PREVIEW_VIEWPORT_SIZE)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(viewport)

	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = preview_frames
	anim.animation = EffectHelperScript.ANIM_PREVIEW
	anim.centered = true
	anim.position = Vector2(PREVIEW_VIEWPORT_SIZE) * 0.5
	anim.scale = Vector2.ONE * scale
	anim.play()
	SpriteHelper.apply_pixel_art(anim)
	viewport.add_child(anim)

	box.add_child(holder)
	return box


func _rebuild_cards() -> void:
	for child in cards.get_children():
		child.queue_free()

	title_label.text = "升级！选择一个强化"
	rarity_label.text = str(_fx.get("name_cn", "普通"))
	rarity_label.modulate = Color(str(_fx.get("color_hex", "#ffffff")))

	var choice_count := upgrade_manager.choices.size()
	var metrics: Dictionary = _calc_card_metrics(choice_count)
	var card_size: Vector2 = metrics["card_size"]
	var preview_h: float = metrics["preview_h"]
	var name_font: int = metrics["name_font"]
	var desc_font: int = metrics["desc_font"]
	var card_glow := float(_fx.get("card_glow", 0.12))

	for i in range(choice_count):
		var upgrade: Dictionary = upgrade_manager.choices[i]
		var btn := Button.new()
		btn.custom_minimum_size = card_size
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_stretch_ratio = 1.0
		btn.text = ""

		var vbox := VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.add_theme_constant_override("separation", 4)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vbox)

		var preview_frames: SpriteFrames = EffectHelperScript.build_upgrade_preview_frames(upgrade)
		var preview_box := _create_preview_widget(preview_frames)
		preview_box.custom_minimum_size = Vector2(0, preview_h)
		if preview_frames == null:
			var icon := Label.new()
			icon.text = str(upgrade.get("icon", "?"))
			icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			icon.add_theme_font_size_override("font_size", 26)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			preview_box.add_child(icon)
		vbox.add_child(preview_box)

		var stack := 0
		if battle and battle.player:
			stack = battle.player.get_upgrade_level(str(upgrade.get("id", "")))

		var name_label := Label.new()
		name_label.text = str(upgrade.get("name_cn", ""))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.add_theme_font_size_override("font_size", name_font)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = str(upgrade.get("desc_cn", ""))
		if stack > 0:
			desc_label.text += "\nLv.%d" % (stack + 1)
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", desc_font)
		desc_label.modulate = Color(0.82, 0.82, 0.82)
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(desc_label)

		var rarity_color := Color(
			str(GameConfig.get_upgrade_fx(str(upgrade.get("rarity", "white"))).get("color_hex", "#ffffff"))
		)
		name_label.modulate = rarity_color
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.12, 0.24, 0.96)
		style.border_color = rarity_color
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.shadow_color = Color(rarity_color, card_glow * 0.6)
		style.shadow_size = int(4 + card_glow * 8)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.modulate.a = 0.0

		var idx := i
		btn.pressed.connect(func(): _pick(idx))
		cards.add_child(btn)

		var tween := create_tween()
		tween.tween_interval(0.08 * float(i))
		tween.tween_property(btn, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pick(index: int) -> void:
	if not upgrade_manager.can_interact():
		return
	var player: BattlePlayer = battle.player
	var upgrade := upgrade_manager.select_upgrade(index, player)
	if upgrade.is_empty():
		return
	hide_popup()
	upgrade_picked.emit(index)


func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)
