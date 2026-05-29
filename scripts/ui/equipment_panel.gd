extends CenterContainer
class_name EquipmentPanelView

const PixelUi := preload("res://scripts/utils/pixel_ui_helper.gd")

const SLOT_ORDER := [
	"weapon",
	"helmet",
	"necklace",
	"ring",
	"armor",
	"shoes",
]

const SYNTH_SLOT_COUNT := 3
const SYNTH_BAG_BUTTON_SIZE := Vector2(106, 74)
const SYNTH_MATERIAL_SLOT_SIZE := Vector2(104, 74)
const SYNTH_RESULT_SLOT_SIZE := Vector2(150, 78)
const SYNTH_BUTTON_FONT_SIZE := 16
const SYNTH_BUTTON_MIN_FONT_SIZE := 9

var _gold_label: Label
var _synth_gold_label: Label
var _attr_summary_label: Label
var _slot_buttons: Dictionary = {}
var _inventory_grid: GridContainer
var _inventory_empty_label: Label
var _detail_popup: PopupPanel
var _detail_icon: TextureRect
var _detail_name_label: Label
var _detail_level_label: Label
var _detail_skill_text: RichTextLabel
var _detail_tip_label: Label
var _btn_equip: Button
var _btn_unequip: Button
var _btn_upgrade: Button
var _details_popup: AcceptDialog
var _details_label: Label

var _icon_cache: Dictionary = {}
var _preview_viewport: SubViewport
var _preview_sprite: AnimatedSprite2D
var _preview_state := "walk"
var _preview_timer := 0.0
var _current_detail_uid := -1

var _base_root: VBoxContainer
var _synthesis_root: VBoxContainer
var _is_synthesis_mode := false
var _synth_material_uids := [-1, -1, -1]
var _synth_target_def_id := ""
var _synth_target_quality := -1
var _synth_result_preview: Dictionary = {}
var _synth_result_slot: Button
var _synth_material_slots: Array[Button] = []
var _synth_status_label: Label
var _synth_compose_button: Button
var _synth_bag_grid: GridContainer
var _synth_bag_empty_label: Label
var _synth_fly_layer: Control
var _synth_toast: Label
var _synth_toast_timer := 0.0
var _synth_toast_duration := 1.9
var _synth_toast_base_top := 78.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for child in get_children():
		child.queue_free()
	_build_ui()
	_connect_signals()
	_refresh_all()
	set_process(true)


func _exit_tree() -> void:
	_set_main_menu_tabs_visible(true)


func _connect_signals() -> void:
	if EventBus:
		EventBus.equipment_changed.connect(_on_equipment_changed)
		EventBus.gold_changed.connect(_on_gold_changed)


func _build_ui() -> void:
	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 12)
	frame.add_theme_constant_override("margin_top", 10)
	frame.add_theme_constant_override("margin_right", 12)
	frame.add_theme_constant_override("margin_bottom", 10)
	add_child(frame)

	_base_root = VBoxContainer.new()
	_base_root.add_theme_constant_override("separation", 8)
	frame.add_child(_base_root)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	_base_root.add_child(top_bar)

	var panel_title := Label.new()
	panel_title.text = "主角装备"
	panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top_bar.add_child(panel_title)

	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_bar.add_child(_gold_label)

	var upper := PanelContainer.new()
	upper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_base_root.add_child(upper)

	var upper_margin := MarginContainer.new()
	upper_margin.add_theme_constant_override("margin_left", 8)
	upper_margin.add_theme_constant_override("margin_top", 8)
	upper_margin.add_theme_constant_override("margin_right", 8)
	upper_margin.add_theme_constant_override("margin_bottom", 8)
	upper.add_child(upper_margin)

	var upper_vbox := VBoxContainer.new()
	upper_vbox.add_theme_constant_override("separation", 8)
	upper_margin.add_child(upper_vbox)

	var upper_content := HBoxContainer.new()
	upper_content.add_theme_constant_override("separation", 10)
	upper_vbox.add_child(upper_content)

	var preview_box := VBoxContainer.new()
	preview_box.custom_minimum_size = Vector2(120, 150)
	preview_box.add_theme_constant_override("separation", 6)
	upper_content.add_child(preview_box)

	var preview_title := Label.new()
	preview_title.text = "主角预览"
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_box.add_child(preview_title)

	var preview_container := SubViewportContainer.new()
	preview_container.custom_minimum_size = Vector2(120, 120)
	preview_container.stretch = true
	preview_box.add_child(preview_container)

	_preview_viewport = SubViewport.new()
	_preview_viewport.size = Vector2i(120, 120)
	_preview_viewport.transparent_bg = true
	_preview_viewport.disable_3d = true
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_container.add_child(_preview_viewport)

	var preview_root := Node2D.new()
	_preview_viewport.add_child(preview_root)

	_preview_sprite = AnimatedSprite2D.new()
	_preview_sprite.position = Vector2(60.0, 86.0)
	preview_root.add_child(_preview_sprite)
	_setup_preview_sprite()

	var slots_box := VBoxContainer.new()
	slots_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_box.add_theme_constant_override("separation", 6)
	upper_content.add_child(slots_box)

	var slots_title := Label.new()
	slots_title.text = "装备槽（点击查看详情）"
	slots_box.add_child(slots_title)

	var slots_grid := GridContainer.new()
	slots_grid.columns = 2
	slots_grid.add_theme_constant_override("h_separation", 6)
	slots_grid.add_theme_constant_override("v_separation", 6)
	slots_box.add_child(slots_grid)

	for slot in SLOT_ORDER:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(120, 56)
		btn.clip_text = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.pressed.connect(_on_slot_pressed.bind(slot))
		slots_grid.add_child(btn)
		_slot_buttons[slot] = btn

	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 8)
	upper_vbox.add_child(stats_row)

	_attr_summary_label = Label.new()
	_attr_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attr_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_row.add_child(_attr_summary_label)

	var detail_btn := Button.new()
	detail_btn.text = "详细信息"
	detail_btn.pressed.connect(_show_attr_popup)
	stats_row.add_child(detail_btn)

	var lower := PanelContainer.new()
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_base_root.add_child(lower)

	var lower_margin := MarginContainer.new()
	lower_margin.add_theme_constant_override("margin_left", 8)
	lower_margin.add_theme_constant_override("margin_top", 8)
	lower_margin.add_theme_constant_override("margin_right", 8)
	lower_margin.add_theme_constant_override("margin_bottom", 8)
	lower.add_child(lower_margin)

	var lower_vbox := VBoxContainer.new()
	lower_vbox.add_theme_constant_override("separation", 6)
	lower_margin.add_child(lower_vbox)

	var bag_title_row := HBoxContainer.new()
	bag_title_row.add_theme_constant_override("separation", 8)
	lower_vbox.add_child(bag_title_row)

	var bag_title := Label.new()
	bag_title.text = "背包（按品质/等级排序）"
	bag_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bag_title_row.add_child(bag_title)

	var synth_btn := Button.new()
	synth_btn.text = "合成"
	synth_btn.pressed.connect(_open_synthesis_view)
	bag_title_row.add_child(synth_btn)

	var bag_scroll := ScrollContainer.new()
	bag_scroll.custom_minimum_size = Vector2(0, 210)
	bag_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lower_vbox.add_child(bag_scroll)

	_inventory_grid = GridContainer.new()
	_inventory_grid.columns = 3
	_inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_grid.add_theme_constant_override("h_separation", 6)
	_inventory_grid.add_theme_constant_override("v_separation", 6)
	bag_scroll.add_child(_inventory_grid)

	_inventory_empty_label = Label.new()
	_inventory_empty_label.text = "暂无装备，击败怪物可掉落装备。"
	_inventory_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lower_vbox.add_child(_inventory_empty_label)

	_build_synthesis_ui(frame)
	_build_detail_popup()
	_build_attr_popup()
	PixelUi.apply_ui_font_tree(self)
	_apply_pixel_filter_tree(self)
	_set_synthesis_mode(false)


func _build_synthesis_ui(parent: Control) -> void:
	_synthesis_root = VBoxContainer.new()
	_synthesis_root.visible = false
	_synthesis_root.add_theme_constant_override("separation", 8)
	parent.add_child(_synthesis_root)

	var top_row := HBoxContainer.new()
	_synthesis_root.add_child(top_row)

	var title := Label.new()
	title.text = "装备合成"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title)

	_synth_gold_label = Label.new()
	_synth_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(_synth_gold_label)

	var top_panel := PanelContainer.new()
	_synthesis_root.add_child(top_panel)
	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 8)
	top_margin.add_theme_constant_override("margin_top", 8)
	top_margin.add_theme_constant_override("margin_right", 8)
	top_margin.add_theme_constant_override("margin_bottom", 8)
	top_panel.add_child(top_margin)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 8)
	top_margin.add_child(top_vbox)

	var result_wrap := HBoxContainer.new()
	result_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	top_vbox.add_child(result_wrap)

	_synth_result_slot = _create_synth_slot_button(SYNTH_RESULT_SLOT_SIZE)
	_synth_result_slot.disabled = true
	result_wrap.add_child(_synth_result_slot)

	var material_row := HBoxContainer.new()
	material_row.alignment = BoxContainer.ALIGNMENT_CENTER
	material_row.add_theme_constant_override("separation", 8)
	top_vbox.add_child(material_row)

	_synth_material_slots.clear()
	for i in range(SYNTH_SLOT_COUNT):
		var slot_btn := _create_synth_slot_button(SYNTH_MATERIAL_SLOT_SIZE)
		slot_btn.pressed.connect(_on_synth_material_slot_pressed.bind(i))
		material_row.add_child(slot_btn)
		_synth_material_slots.append(slot_btn)

	_synth_status_label = Label.new()
	_synth_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_synth_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_vbox.add_child(_synth_status_label)

	var mid_panel := PanelContainer.new()
	_synthesis_root.add_child(mid_panel)
	var mid_margin := MarginContainer.new()
	mid_margin.add_theme_constant_override("margin_left", 8)
	mid_margin.add_theme_constant_override("margin_top", 8)
	mid_margin.add_theme_constant_override("margin_right", 8)
	mid_margin.add_theme_constant_override("margin_bottom", 8)
	mid_panel.add_child(mid_margin)
	var mid_center := CenterContainer.new()
	mid_margin.add_child(mid_center)

	_synth_compose_button = Button.new()
	_synth_compose_button.custom_minimum_size = Vector2(170, 46)
	_synth_compose_button.text = "合成"
	_synth_compose_button.pressed.connect(_on_synth_compose_pressed)
	mid_center.add_child(_synth_compose_button)

	var bag_panel := PanelContainer.new()
	bag_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_synthesis_root.add_child(bag_panel)
	var bag_margin := MarginContainer.new()
	bag_margin.add_theme_constant_override("margin_left", 8)
	bag_margin.add_theme_constant_override("margin_top", 8)
	bag_margin.add_theme_constant_override("margin_right", 8)
	bag_margin.add_theme_constant_override("margin_bottom", 8)
	bag_panel.add_child(bag_margin)

	var bag_vbox := VBoxContainer.new()
	bag_vbox.add_theme_constant_override("separation", 6)
	bag_margin.add_child(bag_vbox)

	var bag_title := Label.new()
	bag_title.text = "背包（点击装备放入素材槽）"
	bag_vbox.add_child(bag_title)

	var bag_scroll := ScrollContainer.new()
	bag_scroll.custom_minimum_size = Vector2(0, 220)
	bag_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bag_vbox.add_child(bag_scroll)

	_synth_bag_grid = GridContainer.new()
	_synth_bag_grid.columns = 3
	_synth_bag_grid.add_theme_constant_override("h_separation", 6)
	_synth_bag_grid.add_theme_constant_override("v_separation", 6)
	_synth_bag_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_scroll.add_child(_synth_bag_grid)

	_synth_bag_empty_label = Label.new()
	_synth_bag_empty_label.text = "背包暂无可用于合成的装备。"
	_synth_bag_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bag_vbox.add_child(_synth_bag_empty_label)

	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_synthesis_root.add_child(bottom_row)
	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.custom_minimum_size = Vector2(130, 40)
	back_btn.pressed.connect(_close_synthesis_view)
	bottom_row.add_child(back_btn)

	_synth_toast = Label.new()
	_synth_toast.visible = false
	_synth_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_synth_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_synth_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_synth_toast.offset_left = -186.0
	_synth_toast.offset_top = _synth_toast_base_top
	_synth_toast.offset_right = 186.0
	_synth_toast.offset_bottom = _synth_toast_base_top + 42.0
	_synth_toast.modulate = Color("#fff4be")
	_synth_toast.add_theme_font_size_override("font_size", 16)
	_synth_toast.add_theme_color_override("font_color", Color("#fff4be"))
	_synth_toast.add_theme_color_override("font_outline_color", Color("#5a3310"))
	_synth_toast.add_theme_constant_override("outline_size", 2)
	_synth_toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	_synth_toast.add_theme_constant_override("shadow_offset_x", 0)
	_synth_toast.add_theme_constant_override("shadow_offset_y", 1)
	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color(0.16, 0.10, 0.03, 0.9)
	toast_style.border_color = Color("#ffd166")
	toast_style.set_border_width_all(2)
	toast_style.set_corner_radius_all(6)
	_synth_toast.add_theme_stylebox_override("normal", toast_style)
	parent.add_child(_synth_toast)

	_synth_fly_layer = Control.new()
	_synth_fly_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_synth_fly_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(_synth_fly_layer)


func _create_synth_slot_button(min_size: Vector2) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = min_size
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.clip_text = true
	btn.text = "空"
	return btn


func _apply_button_text_fit(
	btn: Button,
	text: String,
	box_size: Vector2,
	base_font_size: int = SYNTH_BUTTON_FONT_SIZE,
	min_font_size: int = SYNTH_BUTTON_MIN_FONT_SIZE
) -> void:
	btn.text = text
	btn.clip_text = true
	btn.custom_minimum_size = box_size

	var font := btn.get_theme_font("font")
	if font == null:
		font = PixelUi.get_ui_font()

	var content_padding := 6.0
	var text_width := box_size.x - content_padding * 2.0
	if btn.icon != null:
		var icon_max_w := float(btn.get_theme_constant("icon_max_width", "Button"))
		if icon_max_w <= 0.0:
			icon_max_w = 32.0
		var h_sep := float(btn.get_theme_constant("h_separation", "Button"))
		text_width -= icon_max_w + h_sep
	text_width = maxf(text_width, 12.0)

	var text_height := box_size.y - content_padding * 2.0
	var font_size := base_font_size
	while font_size > min_font_size:
		var text_size := font.get_multiline_string_size(
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			text_width,
			font_size
		)
		if text_size.x <= text_width + 0.5 and text_size.y <= text_height + 0.5:
			break
		font_size -= 1
	btn.add_theme_font_size_override("font_size", maxi(font_size, min_font_size))


func _setup_preview_sprite() -> void:
	if _preview_sprite == null:
		return
	var folder := str(GameConfig.get_player_value("character_folder", "Swordsman"))
	var prefix := str(GameConfig.get_player_value("sprite_prefix", "Swordsman"))
	_preview_sprite.sprite_frames = SpriteHelper.build_character_frames(folder, prefix)
	SpriteHelper.apply_pixel_art(_preview_sprite)
	if _preview_sprite.sprite_frames != null:
		var scale_val := float(GameConfig.get_player_value("sprite_scale", 1.0))
		_preview_sprite.scale = Vector2.ONE * SpriteHelper.pixel_scale(scale_val)
		if _preview_sprite.sprite_frames.has_animation(SpriteHelper.ANIM_WALK):
			_preview_sprite.play(SpriteHelper.ANIM_WALK)
		elif _preview_sprite.sprite_frames.has_animation(SpriteHelper.ANIM_IDLE):
			_preview_sprite.play(SpriteHelper.ANIM_IDLE)
	_preview_state = "walk"
	_preview_timer = randf_range(1.8, 3.2)


func _build_detail_popup() -> void:
	_detail_popup = PopupPanel.new()
	_detail_popup.size = Vector2i(340, 360)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.165, 0.141, 0.125, 1.0)
	panel_style.border_color = Color("#c8b080")
	panel_style.set_border_width_all(2)
	_detail_popup.add_theme_stylebox_override("panel", panel_style)
	add_child(_detail_popup)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_detail_popup.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	vbox.add_child(head)

	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(46, 46)
	_detail_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(_detail_icon)

	var head_text := VBoxContainer.new()
	head_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_text)

	_detail_name_label = Label.new()
	head_text.add_child(_detail_name_label)

	_detail_level_label = Label.new()
	head_text.add_child(_detail_level_label)

	_detail_skill_text = RichTextLabel.new()
	_detail_skill_text.bbcode_enabled = true
	_detail_skill_text.custom_minimum_size = Vector2(0, 175)
	_detail_skill_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_skill_text.scroll_active = true
	vbox.add_child(_detail_skill_text)

	_detail_tip_label = Label.new()
	_detail_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(_detail_tip_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	vbox.add_child(action_row)

	_btn_equip = Button.new()
	_btn_equip.text = "穿戴"
	_btn_equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_equip.pressed.connect(_on_detail_equip)
	action_row.add_child(_btn_equip)

	_btn_unequip = Button.new()
	_btn_unequip.text = "卸下"
	_btn_unequip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_unequip.pressed.connect(_on_detail_unequip)
	action_row.add_child(_btn_unequip)

	_btn_upgrade = Button.new()
	_btn_upgrade.text = "升级"
	_btn_upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_upgrade.pressed.connect(_on_detail_upgrade)
	action_row.add_child(_btn_upgrade)


func _build_attr_popup() -> void:
	_details_popup = AcceptDialog.new()
	_details_popup.title = "主角详细属性"
	_details_popup.size = Vector2i(320, 300)
	add_child(_details_popup)
	_details_label = Label.new()
	_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_details_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_details_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details_popup.add_child(_details_label)


func _apply_pixel_filter_tree(root: Node) -> void:
	if root is CanvasItem:
		(root as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for child in root.get_children():
		_apply_pixel_filter_tree(child)


func _set_synthesis_mode(enable: bool) -> void:
	_is_synthesis_mode = enable
	_base_root.visible = not enable
	_synthesis_root.visible = enable
	_set_main_menu_tabs_visible(not enable)
	if not enable:
		_synth_toast.visible = false
		_synth_toast_timer = 0.0
	if enable:
		_detail_popup.hide()
		_current_detail_uid = -1
		_refresh_synthesis_view()


func _open_synthesis_view() -> void:
	_synth_material_uids = [-1, -1, -1]
	_synth_target_def_id = ""
	_synth_target_quality = -1
	_synth_result_preview = {}
	_synth_status_label.text = "将 3 个相同装备放入素材槽即可合成。"
	_set_synthesis_mode(true)


func _close_synthesis_view() -> void:
	_set_synthesis_mode(false)
	_refresh_all()


func _set_main_menu_tabs_visible(visible: bool) -> void:
	var bottom_bar := get_node_or_null("../../BottomBar") as Control
	if bottom_bar != null:
		bottom_bar.visible = visible
	var content := get_parent() as Control
	if content != null:
		content.offset_bottom = -88.0 if visible else 0.0


func _on_equipment_changed() -> void:
	_refresh_all()


func _on_gold_changed(_value: int) -> void:
	_refresh_gold()
	if _current_detail_uid >= 0 and _detail_popup.visible:
		_open_item_detail(_current_detail_uid)


func _refresh_all() -> void:
	_refresh_gold()
	_refresh_slots()
	_refresh_attributes()
	_refresh_inventory()
	if _is_synthesis_mode:
		_refresh_synthesis_view()


func _refresh_gold() -> void:
	var text := "金币：%d" % int(LobbyState.gold)
	if _gold_label:
		_gold_label.text = text
	if _synth_gold_label:
		_synth_gold_label.text = text


func _refresh_slots() -> void:
	for slot in SLOT_ORDER:
		var btn := _slot_buttons.get(slot, null) as Button
		if btn == null:
			continue
		var item := LobbyState.get_equipped_item(slot)
		if item.is_empty():
			btn.icon = null
			btn.text = "%s\n(空)" % LobbyState.get_slot_display_name(slot)
			btn.modulate = Color(1, 1, 1, 1)
			continue
		var quality := int(item.get("quality", 0))
		btn.icon = _get_item_icon(item)
		btn.text = "%s  Lv.%d" % [LobbyState.get_item_name(item), int(item.get("level", 1))]
		btn.modulate = LobbyState.get_quality_color(quality)


func _refresh_attributes() -> void:
	var attrs := LobbyState.get_player_preview_attributes()
	_attr_summary_label.text = "攻击: %d    生命: %d    战力: %d" % [
		int(round(float(attrs.get("attack", 0.0)))),
		int(attrs.get("hp", 0)),
		int(attrs.get("battle_power", 0)),
	]


func _refresh_inventory() -> void:
	for child in _inventory_grid.get_children():
		child.queue_free()
	var inventory := LobbyState.get_inventory_sorted()
	_inventory_empty_label.visible = inventory.is_empty()
	for item in inventory:
		var uid := int(item.get("uid", -1))
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(106, 74)
		btn.icon = _get_item_icon(item)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		var quality := int(item.get("quality", 0))
		var name := LobbyState.get_item_name(item)
		btn.text = "%s Lv.%d" % [
			name,
			int(item.get("level", 1)),
		]
		btn.modulate = LobbyState.get_quality_color(quality)
		btn.pressed.connect(_open_item_detail.bind(uid))
		_inventory_grid.add_child(btn)


func _get_item_icon(item: Dictionary) -> Texture2D:
	var path := LobbyState.get_item_icon_path(item)
	if path.is_empty():
		return null
	if _icon_cache.has(path):
		return _icon_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	_icon_cache[path] = tex
	return tex


func _on_slot_pressed(slot: String) -> void:
	var item := LobbyState.get_equipped_item(slot)
	if item.is_empty():
		return
	_open_item_detail(int(item.get("uid", -1)))


func _open_item_detail(uid: int) -> void:
	var item := LobbyState.get_item_by_uid(uid)
	if item.is_empty():
		return
	_current_detail_uid = uid
	_detail_icon.texture = _get_item_icon(item)
	var quality := int(item.get("quality", 0))
	var quality_color := LobbyState.get_quality_color(quality)
	_detail_name_label.text = LobbyState.get_item_name(item)
	_detail_name_label.self_modulate = quality_color
	_detail_level_label.text = "等级 Lv.%d   部位: %s" % [
		int(item.get("level", 1)),
		LobbyState.get_slot_display_name(str(item.get("slot", ""))),
	]

	var lines: PackedStringArray = []
	for entry in LobbyState.get_item_skill_entries(item):
		var unlocked := bool(entry.get("unlocked", false))
		var quality_tier := int(entry.get("quality", LobbyState.QUALITY_COMMON))
		var text := str(entry.get("text", ""))
		var ball := _make_quality_pixel_ball(quality_tier, unlocked)
		if unlocked:
			lines.append("%s [color=#d6f7d2]%s[/color]" % [ball, text])
		else:
			lines.append("%s [color=#7a7a7a]%s[/color]" % [ball, text])
	_detail_skill_text.text = "\n".join(lines)

	var equipped := LobbyState.is_item_equipped(uid)
	_btn_equip.visible = not equipped
	_btn_unequip.visible = equipped
	_btn_upgrade.visible = equipped
	if equipped:
		var cost := LobbyState.get_upgrade_cost(item)
		_btn_upgrade.text = "升级（%d 金币）" % cost
		_btn_upgrade.disabled = int(LobbyState.gold) < cost
		_detail_tip_label.text = "升级仅提升白色技能数值，并提升战力。"
	else:
		_detail_tip_label.text = "可穿戴到对应部位。"
	_detail_popup.popup_centered()


func _on_detail_equip() -> void:
	if _current_detail_uid < 0:
		return
	if LobbyState.equip_item(_current_detail_uid):
		_detail_popup.hide()
		_current_detail_uid = -1


func _on_detail_unequip() -> void:
	if _current_detail_uid < 0:
		return
	var item := LobbyState.get_item_by_uid(_current_detail_uid)
	if item.is_empty():
		return
	var slot := str(item.get("slot", ""))
	if LobbyState.unequip_slot(slot):
		_detail_popup.hide()
		_current_detail_uid = -1


func _on_detail_upgrade() -> void:
	if _current_detail_uid < 0:
		return
	var upgraded := LobbyState.upgrade_item(_current_detail_uid)
	if upgraded.is_empty():
		_detail_tip_label.text = "金币不足，无法升级。"
		return
	_open_item_detail(_current_detail_uid)


func _build_active_effect_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for slot in SLOT_ORDER:
		var item := LobbyState.get_equipped_item(slot)
		if item.is_empty():
			continue
		var item_name := LobbyState.get_item_name(item)
		for entry in LobbyState.get_item_skill_entries(item):
			if not bool(entry.get("unlocked", false)):
				continue
			if int(entry.get("quality", LobbyState.QUALITY_COMMON)) <= LobbyState.QUALITY_COMMON:
				continue
			lines.append("- %s: %s" % [
				item_name,
				str(entry.get("text", "")),
			])
	if lines.is_empty():
		lines.append("（暂无，穿戴稀有及以上装备可激活）")
	return lines


func _show_attr_popup() -> void:
	var attrs := LobbyState.get_player_preview_attributes()
	var effect_lines := _build_active_effect_lines()
	_details_label.text = "攻击力: %d（装备加成 %+d）\n最大生命: %d（装备加成 %+d）\n暴击率: %.1f%%（装备加成 %+0.1f%%）\n战斗力: %d\n\n当前装备特效：\n%s\n\n说明：战斗力会随装备等级与品质提升。装备品质越高，解锁并叠加更多技能。" % [
		int(round(float(attrs.get("attack", 0.0)))),
		int(round(float(attrs.get("equip_attack", 0.0)))),
		int(attrs.get("hp", 0)),
		int(attrs.get("equip_hp", 0)),
		float(attrs.get("crit_rate", 0.0)) * 100.0,
		float(attrs.get("equip_crit_rate", 0.0)) * 100.0,
		int(attrs.get("battle_power", 0)),
		"\n".join(effect_lines),
	]
	_details_popup.popup_centered()


func _refresh_synthesis_view() -> void:
	_rebuild_synth_target_from_materials()
	_recompute_synth_result_preview()
	_refresh_synthesis_slots()
	_refresh_synthesis_bag()
	_refresh_synthesis_compose_state()


func _refresh_synthesis_slots() -> void:
	_refresh_synthesis_result_slot()
	for i in range(SYNTH_SLOT_COUNT):
		var slot_btn := _synth_material_slots[i]
		var uid := int(_synth_material_uids[i])
		if uid >= 0:
			var item := LobbyState.get_item_by_uid(uid)
			if item.is_empty():
				_synth_material_uids[i] = -1
				_refresh_synthesis_slots()
				return
			slot_btn.icon = _get_item_icon(item)
			slot_btn.modulate = LobbyState.get_quality_color(int(item.get("quality", 0)))
			_apply_button_text_fit(
				slot_btn,
				"%s Lv.%d" % [
					LobbyState.get_item_name(item),
					int(item.get("level", 1)),
				],
				SYNTH_MATERIAL_SLOT_SIZE
			)
			continue
		if _has_synth_target():
			var ghost_item := {
				"def_id": _synth_target_def_id,
			}
			slot_btn.icon = _get_item_icon(ghost_item)
			slot_btn.modulate = Color(1, 1, 1, 0.35)
			_apply_button_text_fit(slot_btn, "需要同款同品质", SYNTH_MATERIAL_SLOT_SIZE)
		else:
			slot_btn.icon = null
			slot_btn.modulate = Color(1, 1, 1, 1)
			_apply_button_text_fit(slot_btn, "素材槽", SYNTH_MATERIAL_SLOT_SIZE)


func _refresh_synthesis_result_slot() -> void:
	if _synth_result_preview.is_empty():
		_synth_result_slot.icon = null
		_synth_result_slot.modulate = Color(1, 1, 1, 1)
		_apply_button_text_fit(_synth_result_slot, "合成结果", SYNTH_RESULT_SLOT_SIZE)
		return
	_synth_result_slot.icon = _get_item_icon(_synth_result_preview)
	_synth_result_slot.modulate = LobbyState.get_quality_color(int(_synth_result_preview.get("quality", 0)))
	_apply_button_text_fit(
		_synth_result_slot,
		"%s Lv.%d" % [
			LobbyState.get_item_name(_synth_result_preview),
			int(_synth_result_preview.get("level", 1)),
		],
		SYNTH_RESULT_SLOT_SIZE
	)


func _refresh_synthesis_bag() -> void:
	for child in _synth_bag_grid.get_children():
		child.queue_free()
	var inventory := LobbyState.get_inventory_sorted()
	_synth_bag_empty_label.visible = inventory.is_empty()
	var has_empty_slot := _first_empty_synth_slot() >= 0
	for item in inventory:
		var uid := int(item.get("uid", -1))
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.icon = _get_item_icon(item)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		var quality := int(item.get("quality", 0))
		var already_selected := _is_uid_in_synth_materials(uid)
		var label_text := "%s Lv.%d" % [
			LobbyState.get_item_name(item),
			int(item.get("level", 1)),
		]
		if already_selected:
			label_text = "已放入\nLv.%d" % int(item.get("level", 1))
		_apply_button_text_fit(btn, label_text, SYNTH_BAG_BUTTON_SIZE)
		var compatible := has_empty_slot and (not already_selected) and _is_item_compatible_for_current_target(item)
		if compatible:
			btn.modulate = LobbyState.get_quality_color(quality)
			btn.disabled = false
			btn.pressed.connect(_on_synth_bag_item_pressed.bind(uid, btn))
		else:
			btn.modulate = Color(0.46, 0.46, 0.46, 1.0)
			btn.disabled = true
		_synth_bag_grid.add_child(btn)


func _refresh_synthesis_compose_state() -> void:
	var can_compose := not _synth_result_preview.is_empty()
	_synth_compose_button.disabled = not can_compose
	if can_compose:
		_synth_compose_button.text = "合成"
		_synth_compose_button.modulate = Color("#ffd15a")
		_synth_status_label.text = "素材满足条件，可进行合成。"
	else:
		_synth_compose_button.text = "合成"
		_synth_compose_button.modulate = Color(0.6, 0.6, 0.6, 1.0)
		if _synth_target_quality >= LobbyState.QUALITY_LEGENDARY:
			_synth_status_label.text = "传奇品质已满级，无法继续合成。"
		elif _synth_filled_count() >= SYNTH_SLOT_COUNT:
			_synth_status_label.text = "合成失败：需要 3 件不同条目，且为同装备同品质。"
		elif _has_synth_target():
			var count := _synth_filled_count()
			_synth_status_label.text = "已放入 %d/3，继续放入相同装备 + 相同品质。" % count
		else:
			_synth_status_label.text = "将 3 个相同装备放入素材槽即可合成。"


func _on_synth_bag_item_pressed(uid: int, source_btn: Button) -> void:
	var item := LobbyState.get_item_by_uid(uid)
	if item.is_empty():
		return
	if _is_uid_in_synth_materials(uid):
		return
	if not _is_item_compatible_for_current_target(item):
		return
	var slot_idx := _first_empty_synth_slot()
	if slot_idx < 0:
		return
	_synth_material_uids[slot_idx] = uid
	_rebuild_synth_target_from_materials()
	_play_synth_fly_icon(item, source_btn, _synth_material_slots[slot_idx])
	_refresh_synthesis_view()


func _on_synth_material_slot_pressed(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= SYNTH_SLOT_COUNT:
		return
	if int(_synth_material_uids[slot_idx]) < 0:
		return
	_synth_material_uids[slot_idx] = -1
	_rebuild_synth_target_from_materials()
	_recompute_synth_result_preview()
	_refresh_synthesis_view()


func _on_synth_compose_pressed() -> void:
	if _synth_result_preview.is_empty():
		return
	var uids := []
	for uid in _synth_material_uids:
		uids.append(int(uid))
	var result := LobbyState.compose_three_items(uids)
	if result.is_empty():
		_synth_status_label.text = "合成失败，请检查素材。"
		_refresh_synthesis_view()
		return
	_synth_material_uids = [-1, -1, -1]
	_synth_target_def_id = ""
	_synth_target_quality = -1
	_synth_result_preview = {}
	_synth_status_label.text = "合成成功：%s Lv.%d" % [
		LobbyState.get_item_name(result),
		int(result.get("level", 1)),
	]
	_show_synth_toast("合成成功！获得 %s Lv.%d" % [
		LobbyState.get_item_name(result),
		int(result.get("level", 1)),
	])
	_refresh_all()


func _rebuild_synth_target_from_materials() -> void:
	_synth_target_def_id = ""
	_synth_target_quality = -1
	for uid in _synth_material_uids:
		var item := LobbyState.get_item_by_uid(int(uid))
		if item.is_empty():
			continue
		_synth_target_def_id = str(item.get("def_id", ""))
		_synth_target_quality = int(item.get("quality", 0))
		return


func _recompute_synth_result_preview() -> void:
	_synth_result_preview.clear()
	if not LobbyState.can_compose_three(_synth_material_uids):
		return
	var first_item := LobbyState.get_item_by_uid(int(_synth_material_uids[0]))
	if first_item.is_empty():
		return
	var max_level := 1
	for uid in _synth_material_uids:
		var item := LobbyState.get_item_by_uid(int(uid))
		max_level = maxi(max_level, int(item.get("level", 1)))
	_synth_result_preview = {
		"def_id": str(first_item.get("def_id", "")),
		"quality": mini(LobbyState.QUALITY_LEGENDARY, int(first_item.get("quality", 0)) + 1),
		"level": max_level,
	}


func _has_synth_target() -> bool:
	return not _synth_target_def_id.is_empty() and _synth_target_quality >= 0


func _first_empty_synth_slot() -> int:
	for i in range(SYNTH_SLOT_COUNT):
		if int(_synth_material_uids[i]) < 0:
			return i
	return -1


func _synth_filled_count() -> int:
	var count := 0
	for uid in _synth_material_uids:
		if int(uid) >= 0:
			count += 1
	return count


func _is_item_compatible_for_current_target(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	var quality := int(item.get("quality", 0))
	if quality >= LobbyState.QUALITY_LEGENDARY:
		return false
	if not _has_synth_target():
		return true
	return str(item.get("def_id", "")) == _synth_target_def_id and quality == _synth_target_quality


func _is_uid_in_synth_materials(uid: int) -> bool:
	for mat_uid in _synth_material_uids:
		if int(mat_uid) == uid:
			return true
	return false


func _make_quality_pixel_ball(quality: int, unlocked: bool) -> String:
	var base := LobbyState.get_quality_color(quality)
	var fill := base if unlocked else base.lightened(0.45)
	return "[color=%s]●[/color]" % fill.to_html()


func _show_synth_toast(text: String) -> void:
	if _synth_toast == null:
		return
	_synth_toast.text = text
	_synth_toast.visible = true
	_synth_toast.modulate = Color("#fff4be")
	_synth_toast.scale = Vector2(0.86, 0.86)
	_synth_toast.offset_top = _synth_toast_base_top + 10.0
	_synth_toast.offset_bottom = _synth_toast_base_top + 52.0
	_synth_toast_timer = _synth_toast_duration
	var tween := create_tween()
	tween.tween_property(_synth_toast, "scale", Vector2(1.04, 1.04), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_synth_toast, "scale", Vector2(1.0, 1.0), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _play_synth_fly_icon(item: Dictionary, from_btn: Control, to_btn: Control) -> void:
	var icon := _get_item_icon(item)
	if icon == null or from_btn == null or to_btn == null or _synth_fly_layer == null:
		return
	var fly := TextureRect.new()
	fly.texture = icon
	fly.custom_minimum_size = Vector2(26, 26)
	fly.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	fly.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_synth_fly_layer.add_child(fly)

	var from_center := from_btn.get_global_rect().position + from_btn.size * 0.5
	var to_center := to_btn.get_global_rect().position + to_btn.size * 0.5
	var layer_origin := _synth_fly_layer.get_global_rect().position
	var from_local := from_center - layer_origin
	var to_local := to_center - layer_origin
	fly.position = from_local - fly.custom_minimum_size * 0.5

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fly, "position", to_local - fly.custom_minimum_size * 0.5, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(fly, "scale", Vector2(0.82, 0.82), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(fly, "modulate:a", 0.8, 0.24)
	tween.finished.connect(fly.queue_free, CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	_update_synth_toast(delta)
	if _preview_sprite == null or _preview_sprite.sprite_frames == null:
		return
	_preview_timer -= delta
	if _preview_state == "attack":
		if not _preview_sprite.is_playing():
			_preview_state = "walk"
			_play_preview_walk()
			_preview_timer = randf_range(1.8, 3.2)
		return
	if _preview_timer > 0.0:
		return
	if randf() < 0.24 and _preview_sprite.sprite_frames.has_animation(SpriteHelper.ANIM_ATTACK):
		_preview_state = "attack"
		_preview_sprite.play(SpriteHelper.ANIM_ATTACK)
		_preview_timer = _preview_anim_duration(SpriteHelper.ANIM_ATTACK, 0.55)
	else:
		_play_preview_walk()
		_preview_timer = randf_range(1.8, 3.2)


func _update_synth_toast(delta: float) -> void:
	if _synth_toast == null or not _synth_toast.visible:
		return
	_synth_toast_timer -= delta
	if _synth_toast_timer <= 0.0:
		_synth_toast.visible = false
		return
	var life_t := clampf(_synth_toast_timer / _synth_toast_duration, 0.0, 1.0)
	var alpha := life_t
	if life_t > 0.65:
		alpha = clampf((1.0 - life_t) / 0.35, 0.0, 1.0)
	alpha = maxf(alpha, life_t)
	var rise := (1.0 - life_t) * 16.0
	_synth_toast.offset_top = _synth_toast_base_top - rise
	_synth_toast.offset_bottom = _synth_toast_base_top + 42.0 - rise
	_synth_toast.modulate.a = alpha


func _play_preview_walk() -> void:
	if _preview_sprite == null or _preview_sprite.sprite_frames == null:
		return
	if _preview_sprite.sprite_frames.has_animation(SpriteHelper.ANIM_WALK):
		_preview_sprite.play(SpriteHelper.ANIM_WALK)
	elif _preview_sprite.sprite_frames.has_animation(SpriteHelper.ANIM_IDLE):
		_preview_sprite.play(SpriteHelper.ANIM_IDLE)


func _preview_anim_duration(anim_name: String, fallback: float) -> float:
	if _preview_sprite == null or _preview_sprite.sprite_frames == null:
		return fallback
	if not _preview_sprite.sprite_frames.has_animation(anim_name):
		return fallback
	var frame_count := _preview_sprite.sprite_frames.get_frame_count(anim_name)
	if frame_count <= 0:
		return fallback
	var speed := _preview_sprite.sprite_frames.get_animation_speed(anim_name)
	if speed <= 0.0:
		return fallback
	var total := 0.0
	for i in range(frame_count):
		total += _preview_sprite.sprite_frames.get_frame_duration(anim_name, i)
	return maxf(0.12, total / speed)
