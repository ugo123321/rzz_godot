@tool
extends Control
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
const SYNTH_BUTTON_FONT_SIZE := 16
const SYNTH_BUTTON_MIN_FONT_SIZE := 9
const INVENTORY_COLUMNS := 5
const INVENTORY_VISIBLE_ROWS := 4
const INVENTORY_BASE_SLOTS := INVENTORY_COLUMNS * INVENTORY_VISIBLE_ROWS
const INVENTORY_SLOT_TEX := preload("res://assets/ui/equipment/equipment_slot02.png")
const BAG_SLOT_SCENE := preload("res://scenes/ui/bag_slot.tscn")

## 装备页主角预览缩放（与战斗 sprite_scale 独立）。选 EquipmentPanel 根节点调节；步进 0.1。
@export_range(0.5, 8.0, 0.1, "or_greater") var preview_sprite_scale: float = 2.0:
	set(value):
		preview_sprite_scale = value
		if is_node_ready() or Engine.is_editor_hint():
			_apply_preview_sprite_scale()

const SLOT_BUTTON_NODES := {
	"weapon": &"SlotWeapon",
	"helmet": &"SlotHelmet",
	"necklace": &"SlotNecklace",
	"ring": &"SlotRing",
	"armor": &"SlotArmor",
	"shoes": &"SlotShoes",
}

@onready var _margin_frame: MarginContainer = $Frame/RootMargin
@onready var _main_vbox: VBoxContainer = $Frame/RootMargin/BaseRoot
@onready var _inventory_grid: GridContainer = $Frame/RootMargin/BaseRoot/BagScroll/InventoryGrid
@onready var _inventory_empty_label: Label = $Frame/RootMargin/BaseRoot/InventoryEmptyLabel
@onready var _battle_power_label: Label = $Frame/RootMargin/BaseRoot/UpperArea/StatsBlock/PowerRow/BattlePowerLabel
@onready var _attack_label: Label = $Frame/RootMargin/BaseRoot/UpperArea/StatsBlock/SubStatsRow/AttackBox/Row/AttackLabel
@onready var _hp_label: Label = $Frame/RootMargin/BaseRoot/UpperArea/StatsBlock/SubStatsRow/HpBox/Row/HpLabel
@onready var _preview_viewport: SubViewport = $Frame/RootMargin/BaseRoot/UpperArea/CharacterRow/PreviewWrap/PreviewContainer/PreviewViewport
@onready var _preview_sprite: AnimatedSprite2D = %PreviewSprite

@onready var _synthesis_root: VBoxContainer = $Frame/SynthesisRoot
@onready var _synth_gold_label: Label = $Frame/SynthesisRoot/TopRow/SynthGoldLabel
@onready var _synth_result_slot: Button = $Frame/SynthesisRoot/TopPanel/TopMargin/TopVBox/ResultWrap/SynthResultSlot
@onready var _synth_status_label: Label = $Frame/SynthesisRoot/TopPanel/TopMargin/TopVBox/SynthStatusLabel
@onready var _synth_compose_button: Button = $Frame/SynthesisRoot/MidPanel/MidMargin/MidCenter/SynthComposeButton
@onready var _synth_bag_grid: GridContainer = $Frame/SynthesisRoot/BagPanel/BagMargin/BagVBox/SynthBagScroll/SynthBagGrid
@onready var _synth_bag_empty_label: Label = $Frame/SynthesisRoot/BagPanel/BagMargin/BagVBox/SynthBagEmptyLabel
@onready var _synth_fly_layer: Control = $Frame/SynthFlyLayer
@onready var _synth_toast: Label = $Frame/SynthToast

@onready var _detail_popup: PopupPanel = $DetailPopup
@onready var _detail_icon: TextureRect = $DetailPopup/Margin/VBox/Head/DetailIcon
@onready var _detail_name_label: Label = $DetailPopup/Margin/VBox/Head/HeadText/DetailNameLabel
@onready var _detail_level_label: Label = $DetailPopup/Margin/VBox/Head/HeadText/DetailLevelLabel
@onready var _detail_skill_text: RichTextLabel = $DetailPopup/Margin/VBox/DetailSkillText
@onready var _detail_tip_label: Label = $DetailPopup/Margin/VBox/DetailTipLabel
@onready var _btn_equip: Button = $DetailPopup/Margin/VBox/ActionRow/BtnEquip
@onready var _btn_unequip: Button = $DetailPopup/Margin/VBox/ActionRow/BtnUnequip
@onready var _btn_upgrade: Button = $DetailPopup/Margin/VBox/ActionRow/BtnUpgrade
@onready var _details_popup: AcceptDialog = $DetailsPopup
@onready var _details_label: Label = $DetailsPopup/DetailsLabel

var _synth_material_slots: Array[Button] = []

var _icon_cache: Dictionary = {}
var _preview_state := "walk"
var _preview_timer := 0.0
var _current_detail_uid := -1
var _slot_buttons: Dictionary = {}

var _is_synthesis_mode := false
var _synth_material_uids := [-1, -1, -1]
var _synth_target_def_id := ""
var _synth_target_quality := -1
var _synth_result_preview: Dictionary = {}
var _synth_toast_timer := 0.0
var _synth_toast_duration := 1.9
var _synth_toast_base_top := 78.0
var _bag_slot_uids: Array[int] = []


func _should_fill_parent() -> bool:
	var parent_node := get_parent()
	return parent_node is MarginContainer and parent_node.name == "Content"


func _ui_scale() -> float:
	return GameConfig.get_ui_layout_scale()


func _scaled(v: float) -> float:
	return v * _ui_scale()


func _synth_bag_button_size() -> Vector2:
	return Vector2(_scaled(123.0), _scaled(68.0))


func _synth_material_slot_size() -> Vector2:
	return Vector2(_scaled(94.0), _scaled(68.0))


func _synth_result_slot_size() -> Vector2:
	return Vector2(_scaled(138.0), _scaled(72.0))


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if Engine.is_editor_hint():
		call_deferred("_setup_preview_sprite")
		return
	_setup_scene_ui()
	_connect_signals()
	_refresh_all()
	set_process(true)


func _exit_tree() -> void:
	_set_main_menu_tabs_visible(true)


func _connect_signals() -> void:
	if EventBus:
		EventBus.equipment_changed.connect(_on_equipment_changed)
		EventBus.gold_changed.connect(_on_gold_changed)


func _setup_scene_ui() -> void:
	# 嵌入主菜单 Content 时铺满可用区域；单独打开场景时保持 688x1034，与运行时一致。
	if _should_fill_parent():
		set_anchors_preset(Control.PRESET_FULL_RECT)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL

	_synth_material_slots = [
		$Frame/SynthesisRoot/TopPanel/TopMargin/TopVBox/MaterialRow/SynthMaterialSlot0,
		$Frame/SynthesisRoot/TopPanel/TopMargin/TopVBox/MaterialRow/SynthMaterialSlot1,
		$Frame/SynthesisRoot/TopPanel/TopMargin/TopVBox/MaterialRow/SynthMaterialSlot2,
	]
	for i in range(SYNTH_SLOT_COUNT):
		var slot_btn := _synth_material_slots[i]
		if slot_btn == null:
			continue
		slot_btn.pressed.connect(_on_synth_material_slot_pressed.bind(i))

	_bind_slot_buttons()
	_setup_inventory_slots()
	_setup_preview_sprite()

	PixelUi.apply_ui_font_tree(self)
	_apply_pixel_filter_tree(self)
	_set_synthesis_mode(false)


func _bind_slot_buttons() -> void:
	_slot_buttons.clear()
	for slot in SLOT_ORDER:
		var node_name: StringName = SLOT_BUTTON_NODES.get(slot, &"")
		var btn := find_child(str(node_name), true, false) as TextureButton
		if btn == null:
			continue
		_slot_buttons[slot] = btn
		btn.pressed.connect(_on_slot_pressed.bind(slot))


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
	var sprite := _get_preview_sprite()
	if sprite == null:
		return
	var folder := str(GameConfig.get_player_value("character_folder", "Swordsman"))
	var prefix := str(GameConfig.get_player_value("sprite_prefix", "Swordsman"))
	sprite.sprite_frames = SpriteHelper.build_character_frames(folder, prefix)
	SpriteHelper.apply_pixel_art(sprite)
	if sprite.sprite_frames != null:
		if sprite.sprite_frames.has_animation(SpriteHelper.ANIM_WALK):
			sprite.play(SpriteHelper.ANIM_WALK)
		elif sprite.sprite_frames.has_animation(SpriteHelper.ANIM_IDLE):
			sprite.play(SpriteHelper.ANIM_IDLE)
	_apply_preview_sprite_scale()
	if not Engine.is_editor_hint():
		_preview_state = "walk"
		_preview_timer = randf_range(1.8, 3.2)


func _get_preview_sprite() -> AnimatedSprite2D:
	if _preview_sprite != null:
		return _preview_sprite
	if not is_inside_tree():
		return null
	return get_node_or_null("%PreviewSprite") as AnimatedSprite2D


func _apply_preview_sprite_scale() -> void:
	var sprite := _get_preview_sprite()
	if sprite == null or sprite.sprite_frames == null:
		return
	var s := maxf(0.1, preview_sprite_scale)
	sprite.scale = Vector2.ONE * s


func _apply_pixel_filter_tree(root: Node) -> void:
	if root is CanvasItem:
		(root as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for child in root.get_children():
		_apply_pixel_filter_tree(child)


func _on_synthesis_pressed() -> void:
	_open_synthesis_view()


func _set_synthesis_mode(enable: bool) -> void:
	_is_synthesis_mode = enable
	if _margin_frame != null:
		_margin_frame.visible = not enable
	if _synthesis_root != null:
		_synthesis_root.visible = enable
	_set_main_menu_tabs_visible(not enable)
	if not enable:
		if _synth_toast != null:
			_synth_toast.visible = false
		_synth_toast_timer = 0.0
	if enable:
		if _detail_popup != null:
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


func _main_menu_bottom_bar_height() -> float:
	var bottom_bar := get_node_or_null("../../BottomBar") as Control
	if bottom_bar == null:
		return _scaled(168.0)
	var h := bottom_bar.size.y
	if h > 0.0:
		return h
	return maxf(bottom_bar.custom_minimum_size.y, _scaled(168.0))


func _set_main_menu_tabs_visible(visible: bool) -> void:
	var bottom_bar := get_node_or_null("../../BottomBar") as Control
	if bottom_bar != null:
		bottom_bar.visible = visible
	var content := get_parent() as Control
	if content != null:
		content.offset_bottom = -_main_menu_bottom_bar_height() if visible else 0.0


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
	if _synth_gold_label:
		_synth_gold_label.text = text


func _refresh_slots() -> void:
	for slot in SLOT_ORDER:
		var btn := _slot_buttons.get(slot, null) as TextureButton
		if btn == null:
			continue
		var icon_rect := btn.get_node_or_null("ItemIcon") as TextureRect
		var item := LobbyState.get_equipped_item(slot)
		if item.is_empty():
			if icon_rect != null:
				icon_rect.visible = false
				icon_rect.texture = null
			btn.modulate = Color(1, 1, 1, 1)
			continue
		var quality := int(item.get("quality", 0))
		var icon := _get_item_icon(item)
		if icon_rect != null:
			icon_rect.texture = icon
			icon_rect.visible = icon != null
		btn.modulate = LobbyState.get_quality_color(quality)


func _refresh_attributes() -> void:
	if _battle_power_label == null or _attack_label == null or _hp_label == null:
		return
	var attrs := LobbyState.get_player_preview_attributes()
	_battle_power_label.text = str(int(attrs.get("battle_power", 0)))
	_attack_label.text = str(int(round(float(attrs.get("attack", 0.0)))))
	_hp_label.text = str(int(attrs.get("hp", 0)))


func _setup_inventory_slots() -> void:
	if _inventory_grid == null:
		return
	_ensure_inventory_slot_count(INVENTORY_BASE_SLOTS)
	for i in range(_inventory_grid.get_child_count()):
		var btn := _inventory_grid.get_child(i) as TextureButton
		if btn == null:
			continue
		btn.texture_normal = INVENTORY_SLOT_TEX
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		btn.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		if not btn.pressed.is_connected(_on_bag_slot_pressed):
			btn.pressed.connect(_on_bag_slot_pressed.bind(i))


func _ensure_inventory_slot_count(count: int) -> void:
	if _inventory_grid == null:
		return
	while _inventory_grid.get_child_count() < count:
		var index := _inventory_grid.get_child_count()
		var btn := BAG_SLOT_SCENE.instantiate() as TextureButton
		if btn == null:
			break
		btn.name = "BagSlot%02d" % index
		btn.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		btn.pressed.connect(_on_bag_slot_pressed.bind(index))
		_inventory_grid.add_child(btn)
	while _inventory_grid.get_child_count() > count:
		_inventory_grid.get_child(_inventory_grid.get_child_count() - 1).queue_free()


func _apply_item_to_bag_slot(btn: TextureButton, item: Dictionary, uid: int) -> void:
	var icon_rect := btn.get_node_or_null("ItemIcon") as TextureRect
	var icon := _get_item_icon(item)
	if icon_rect != null:
		icon_rect.texture = icon
		icon_rect.visible = icon != null
	btn.modulate = LobbyState.get_quality_color(int(item.get("quality", 0)))
	btn.set_meta("bag_uid", uid)


func _apply_empty_bag_slot(btn: TextureButton) -> void:
	var icon_rect := btn.get_node_or_null("ItemIcon") as TextureRect
	if icon_rect != null:
		icon_rect.texture = null
		icon_rect.visible = false
	btn.modulate = Color(1, 1, 1, 1)
	btn.set_meta("bag_uid", -1)


func _on_bag_slot_pressed(slot_index: int) -> void:
	var bag_scroll := get_node_or_null("Frame/RootMargin/BaseRoot/BagScroll") as SpringScrollContainer
	if bag_scroll != null and bag_scroll.was_scroll_gesture():
		return
	if slot_index < 0 or slot_index >= _bag_slot_uids.size():
		return
	var uid := int(_bag_slot_uids[slot_index])
	if uid >= 0:
		_open_item_detail(uid)


func _refresh_inventory() -> void:
	if _inventory_grid == null:
		return
	var inventory := LobbyState.get_inventory_sorted()
	var slot_count := maxi(INVENTORY_BASE_SLOTS, inventory.size())
	_ensure_inventory_slot_count(slot_count)
	_bag_slot_uids.resize(slot_count)
	for i in range(slot_count):
		var btn := _inventory_grid.get_child(i) as TextureButton
		if btn == null:
			continue
		if i < inventory.size():
			var item: Dictionary = inventory[i]
			var uid := int(item.get("uid", -1))
			_bag_slot_uids[i] = uid
			_apply_item_to_bag_slot(btn, item, uid)
		else:
			_bag_slot_uids[i] = -1
			_apply_empty_bag_slot(btn)
	if _inventory_empty_label != null:
		_inventory_empty_label.visible = false


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
	if _detail_popup == null or _btn_equip == null or _btn_unequip == null or _btn_upgrade == null:
		return
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
				_synth_material_slot_size()
			)
			continue
		if _has_synth_target():
			var ghost_item := {
				"def_id": _synth_target_def_id,
			}
			slot_btn.icon = _get_item_icon(ghost_item)
			slot_btn.modulate = Color(1, 1, 1, 0.35)
			_apply_button_text_fit(slot_btn, "需要同款同品质", _synth_material_slot_size())
		else:
			slot_btn.icon = null
			slot_btn.modulate = Color(1, 1, 1, 1)
			_apply_button_text_fit(slot_btn, "素材槽", _synth_material_slot_size())


func _refresh_synthesis_result_slot() -> void:
	if _synth_result_preview.is_empty():
		_synth_result_slot.icon = null
		_synth_result_slot.modulate = Color(1, 1, 1, 1)
		_apply_button_text_fit(_synth_result_slot, "合成结果", _synth_result_slot_size())
		return
	_synth_result_slot.icon = _get_item_icon(_synth_result_preview)
	_synth_result_slot.modulate = LobbyState.get_quality_color(int(_synth_result_preview.get("quality", 0)))
	_apply_button_text_fit(
		_synth_result_slot,
		"%s Lv.%d" % [
			LobbyState.get_item_name(_synth_result_preview),
			int(_synth_result_preview.get("level", 1)),
		],
		_synth_result_slot_size()
	)


func _refresh_synthesis_bag() -> void:
	if _synth_bag_grid == null:
		return
	for child in _synth_bag_grid.get_children():
		child.queue_free()
	var inventory := LobbyState.get_inventory_sorted()
	if _synth_bag_empty_label != null:
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
		_apply_button_text_fit(btn, label_text, _synth_bag_button_size())
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
