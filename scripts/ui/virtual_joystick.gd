extends Control
class_name VirtualJoystick

## 浮动摇杆：在触摸点出现，方向输出恒为归一化向量（固定速率移动）。

const BASE_RADIUS := 48.0
const KNOB_RADIUS := 20.0
const MAX_DRAG_RADIUS := 56.0
const DEADZONE_RATIO := 0.12

const BASE_FILL := Color(1.0, 1.0, 1.0, 0.14)
const BASE_RING := Color(1.0, 1.0, 1.0, 0.42)
const KNOB_FILL := Color(1.0, 0.92, 0.55, 0.55)
const KNOB_RING := Color(1.0, 0.85, 0.25, 0.9)

var enabled := true
var output: Vector2 = Vector2.ZERO

var _active := false
var _center := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 25


func is_active() -> bool:
	return _active


func get_output() -> Vector2:
	return output


func set_battle_enabled(on: bool) -> void:
	if enabled == on:
		return
	enabled = on
	if not on:
		_force_end()


func feed_pointer(screen_pos: Vector2, phase: String) -> bool:
	if not enabled:
		return false
	match phase:
		"down":
			if _active:
				return true
			_begin(screen_pos)
			return true
		"move":
			if not _active:
				return false
			_update_knob(screen_pos)
			return true
		"up":
			if not _active:
				return false
			_end()
			return true
	return false


func _begin(screen_pos: Vector2) -> void:
	_active = true
	_center = screen_pos
	_knob = screen_pos
	output = Vector2.ZERO
	queue_redraw()


func _update_knob(screen_pos: Vector2) -> void:
	var offset := screen_pos - _center
	if offset.length() > MAX_DRAG_RADIUS:
		offset = offset.normalized() * MAX_DRAG_RADIUS
	_knob = _center + offset
	var ratio := offset.length() / MAX_DRAG_RADIUS
	if ratio < DEADZONE_RATIO:
		output = Vector2.ZERO
	else:
		output = offset.normalized()
	queue_redraw()


func _end() -> void:
	_active = false
	output = Vector2.ZERO
	queue_redraw()


func _force_end() -> void:
	if _active:
		_end()


func _screen_to_local(screen_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_pos


func _draw() -> void:
	if not _active:
		return
	var center := _screen_to_local(_center)
	var knob := _screen_to_local(_knob)
	draw_circle(center, BASE_RADIUS, BASE_FILL)
	draw_arc(center, BASE_RADIUS, 0.0, TAU, 48, BASE_RING, 2.0)
	draw_line(center, knob, Color(1.0, 1.0, 1.0, 0.28), 2.0)
	draw_circle(knob, KNOB_RADIUS, KNOB_FILL)
	draw_arc(knob, KNOB_RADIUS, 0.0, TAU, 32, KNOB_RING, 2.0)
