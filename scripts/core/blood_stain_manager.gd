extends Node2D
class_name BloodStainManager

const MAX_STAINS := 280
const FADE_DURATION := 10.0
const MIN_ALPHA := 0.22
const REDRAW_INTERVAL := 0.05

const COLORS: Array[Color] = [
	Color("#f0a8a8"),
	Color("#e89090"),
	Color("#ffc8c8"),
]

var stains: Array = []
var _redraw_timer := 0.0


func clear() -> void:
	stains.clear()
	queue_redraw()


func update_stains(delta: float) -> void:
	if stains.is_empty():
		return
	var i := stains.size() - 1
	while i >= 0:
		var s: Dictionary = stains[i]
		var age := float(s.get("age", 0.0)) + delta
		if age >= FADE_DURATION:
			stains.remove_at(i)
		else:
			s["age"] = age
			stains[i] = s
		i -= 1
	_trim()
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_INTERVAL
		queue_redraw()


func _trim() -> void:
	while stains.size() > MAX_STAINS:
		stains.remove_at(0)


func _alpha(age: float) -> float:
	if age >= FADE_DURATION:
		return MIN_ALPHA
	var t := age / FADE_DURATION
	return MIN_ALPHA + (1.0 - MIN_ALPHA) * (1.0 - t)


func spawn(x: float, y: float, intensity: float = 1.0, from_angle = null) -> void:
	var base_ang := randf() * TAU if from_angle == null else float(from_angle)
	var drops: Array = []
	var drop_count := int(floor(8.0 + 12.0 * intensity))
	for i in range(drop_count):
		var a := base_ang + randf_range(-1.2, 1.2)
		var d := randf_range(3.0, 28.0 * intensity)
		drops.append({
			"x": cos(a) * d,
			"y": sin(a) * d * 0.75,
			"r": randf_range(1.2, 3.8) * intensity,
			"c": COLORS[randi() % COLORS.size()],
		})
	stains.append({"x": x, "y": y, "drops": drops, "age": 0.0})
	_trim()
	queue_redraw()


func draw_stains(canvas: Node2D) -> void:
	var offset := -canvas.global_position
	for s in stains:
		var alpha := _alpha(float(s.age))
		var origin := Vector2(float(s.x), float(s.y))
		for d in s.drops:
			var col: Color = d.c
			col.a = alpha
			canvas.draw_circle(origin + Vector2(float(d.x), float(d.y)) + offset, float(d.r), col)
