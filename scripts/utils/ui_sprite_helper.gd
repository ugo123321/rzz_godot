class_name UiSpriteHelper
extends RefCounted

## Franuka RPG UI 图集（1x）：`res://assets/ui/UI assets (1x).png`（1024×1024）

const UI_ATLAS_PATH := "res://assets/ui/UI assets (1x).png"

# 单段横条外框（勿用 0,50,144,13 —— 那是三连段整条素材）
const BAR_FRAME_REGION := Rect2(1, 69, 46, 19)
const BAR_FRAME_MARGINS := Vector4(14, 5, 14, 5)

# 单段实心填充（横向九宫格拉伸）
const BAR_FILL_KI_REGION := Rect2(433, 50, 46, 13)
const BAR_FILL_EXP_REGION := Rect2(598, 856, 21, 16)
const BAR_FILL_MARGINS := Vector4(4, 2, 4, 2)

const BAR_VISUAL_HEIGHT := 18.0

# 气力条颜色：未满保持素材原色，满为明亮天蓝
const KI_FILL_NORMAL := Color(1.0, 1.0, 1.0, 1.0)
const KI_FILL_FULL := Color(0.38, 1.32, 1.75, 1.0)
const KI_GLOW_SKY := Color(0.45, 0.92, 1.0)
const KI_GLOW_FILL := Color(0.55, 1.2, 1.65, 1.0)

# 暂停按钮（MINI ICONS 行 y≈736 的 ||，勿用 287,785 横条或 48,176 大块）
const PAUSE_ICON_REGION := Rect2(210, 740, 12, 12)
const PAUSE_BUTTON_REGION := Rect2(204, 736, 18, 18)

static var _atlas: Texture2D
static var _cache: Dictionary = {}


static func _load_atlas() -> Texture2D:
	if _atlas == null:
		_atlas = load(UI_ATLAS_PATH) as Texture2D
	return _atlas


static func get_region_texture(region: Rect2) -> Texture2D:
	var key := "%d_%d_%d_%d" % [region.position.x, region.position.y, region.size.x, region.size.y]
	if _cache.has(key):
		return _cache[key]
	var atlas_tex := AtlasTexture.new()
	atlas_tex.atlas = _load_atlas()
	atlas_tex.region = region
	atlas_tex.filter_clip = true
	_cache[key] = atlas_tex
	return atlas_tex


static func apply_pixel_filter(node: CanvasItem) -> void:
	if node:
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func _draw_nine_patch_horizontal(
	canvas: CanvasItem,
	tex: Texture2D,
	rect: Rect2,
	margins: Vector4,
	modulate: Color = Color.WHITE
) -> void:
	if tex == null:
		return
	apply_pixel_filter(canvas)
	var src_size := tex.get_size()
	if src_size.x <= 0.0 or src_size.y <= 0.0:
		return
	var ml := margins.x
	var mr := margins.z
	var center_src_w := maxf(1.0, src_size.x - ml - mr)
	var dest_h := rect.size.y
	var x := rect.position.x
	var y := rect.position.y
	var total_w := rect.size.x

	var left_w := minf(ml, total_w)
	if left_w > 0.5:
		canvas.draw_texture_rect_region(
			tex, Rect2(x, y, left_w, dest_h), Rect2(0, 0, left_w, src_size.y), modulate
		)
		x += left_w

	var right_w := minf(mr, maxf(0.0, total_w - left_w))
	var mid_w := maxf(0.0, total_w - left_w - right_w)
	if mid_w > 0.5:
		canvas.draw_texture_rect_region(
			tex,
			Rect2(x, y, mid_w, dest_h),
			Rect2(ml, 0, center_src_w, src_size.y),
			modulate
		)
		x += mid_w

	if right_w > 0.5:
		canvas.draw_texture_rect_region(
			tex,
			Rect2(x, y, right_w, dest_h),
			Rect2(src_size.x - mr, 0, mr, src_size.y),
			modulate
		)


static func _ki_fill_modulate(ratio: float, is_ready: bool) -> Color:
	if is_ready:
		return KI_FILL_FULL
	# 接近满时略偏蓝，满时一下子切到天蓝
	var t := clampf(inverse_lerp(0.72, 1.0, ratio), 0.0, 1.0)
	return KI_FILL_NORMAL.lerp(KI_FILL_FULL, t * 0.35)


static func _draw_ki_ready_glow(canvas: CanvasItem, rect: Rect2, ratio: float) -> void:
	var pulse := 0.85 + sin(Time.get_ticks_msec() * 0.011) * 0.15
	var frame_tex := get_region_texture(BAR_FRAME_REGION)
	var fill_tex := get_region_texture(BAR_FILL_KI_REGION)
	if frame_tex == null:
		return

	for i in range(3):
		var expand := 8.0 - float(i) * 2.5
		var glow_rect := Rect2(
			rect.position.x - expand,
			rect.position.y - expand,
			rect.size.x + expand * 2.0,
			rect.size.y + expand * 2.0
		)
		var layer_a := pulse * (0.8 - float(i) * 0.1)
		_draw_nine_patch_horizontal(
			canvas,
			frame_tex,
			glow_rect,
			BAR_FRAME_MARGINS,
			Color(KI_GLOW_SKY.r, KI_GLOW_SKY.g, KI_GLOW_SKY.b, layer_a)
		)

	var pad := 5.0
	var inner := Rect2(
		rect.position.x + pad,
		rect.position.y + pad,
		maxf(0.0, rect.size.x - pad * 2.0),
		maxf(0.0, rect.size.y - pad * 2.0)
	)
	if fill_tex and inner.size.x > 0.5 and inner.size.y > 0.5:
		var fill_w := inner.size.x * clampf(ratio, 0.0, 1.0)
		if fill_w > 0.5:
			var fill_rect := Rect2(inner.position, Vector2(fill_w, inner.size.y))
			for layer_a in [pulse * 0.9, pulse * 0.55]:
				_draw_nine_patch_horizontal(
					canvas,
					fill_tex,
					fill_rect,
					BAR_FILL_MARGINS,
					Color(KI_GLOW_FILL.r, KI_GLOW_FILL.g, KI_GLOW_FILL.b, layer_a)
				)


static func _fit_bar_rect(x: float, y: float, width: float, height: float) -> Rect2:
	var bar_h := minf(BAR_VISUAL_HEIGHT, height)
	var bar_y := y + (height - bar_h) * 0.5
	return Rect2(x, bar_y, width, bar_h)


static func draw_horizontal_bar(
	canvas: CanvasItem,
	rect: Rect2,
	ratio: float,
	fill_region: Rect2,
	fill_margins: Vector4 = BAR_FILL_MARGINS,
	fill_modulate: Color = Color.WHITE
) -> void:
	var frame_tex := get_region_texture(BAR_FRAME_REGION)
	if frame_tex:
		_draw_nine_patch_horizontal(canvas, frame_tex, rect, BAR_FRAME_MARGINS)

	var pad := 5.0
	var inner := Rect2(
		rect.position.x + pad,
		rect.position.y + pad,
		maxf(0.0, rect.size.x - pad * 2.0),
		maxf(0.0, rect.size.y - pad * 2.0)
	)
	var fill_tex := get_region_texture(fill_region)
	if inner.size.x > 0.5 and inner.size.y > 0.5 and fill_tex:
		var fill_w := inner.size.x * clampf(ratio, 0.0, 1.0)
		if fill_w > 0.5:
			var fill_rect := Rect2(inner.position, Vector2(fill_w, inner.size.y))
			_draw_nine_patch_horizontal(canvas, fill_tex, fill_rect, fill_margins, fill_modulate)


static func draw_exp_bar(
	canvas: CanvasItem,
	viewport_size: Vector2,
	level: int,
	exp_value: int,
	exp_to_next: int
) -> void:
	var pad := 10.0
	var w := viewport_size.x - pad * 2.0
	var rect := _fit_bar_rect(pad, viewport_size.y - BAR_VISUAL_HEIGHT - pad, w, BAR_VISUAL_HEIGHT)
	var ratio := clampf(float(exp_value) / maxf(1.0, float(exp_to_next)), 0.0, 1.0)
	draw_horizontal_bar(canvas, rect, ratio, BAR_FILL_EXP_REGION)

	var font_size := 11
	var cy := rect.position.y + rect.size.y * 0.5
	PixelUiHelper.draw_pixel_text(
		canvas, "Lv%d" % level, Vector2(pad + 8.0, cy), font_size,
		Color("#ffe8a8"), HORIZONTAL_ALIGNMENT_LEFT
	)
	PixelUiHelper.draw_pixel_text(
		canvas, "%d / %d" % [exp_value, exp_to_next], Vector2(pad + w - 8.0, cy),
		font_size, Color("#e8f0d8"), HORIZONTAL_ALIGNMENT_RIGHT
	)


static func draw_ki_bar(
	canvas: CanvasItem,
	x: float,
	y: float,
	width: float,
	height: float,
	ratio: float,
	is_ready: bool
) -> void:
	var rect := _fit_bar_rect(x, y, width, height)
	var fill_tint := _ki_fill_modulate(ratio, is_ready)
	draw_horizontal_bar(canvas, rect, ratio, BAR_FILL_KI_REGION, BAR_FILL_MARGINS, fill_tint)
	if is_ready:
		_draw_ki_ready_glow(canvas, rect, ratio)


static func make_pause_button_icon() -> Texture2D:
	return get_region_texture(PAUSE_ICON_REGION)


static func make_pause_button_texture() -> Texture2D:
	return get_region_texture(PAUSE_BUTTON_REGION)


static func style_pause_button(btn: TextureButton) -> void:
	var tex := make_pause_button_texture()
	btn.texture_normal = tex
	btn.texture_pressed = tex
	btn.texture_hover = tex
	btn.texture_disabled = tex
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	apply_pixel_filter(btn)
