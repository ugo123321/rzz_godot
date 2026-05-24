extends Node2D
class_name ParticleManager

const POOL_SIZE := 500

var pool: Array = []


func _ready() -> void:
	for i in range(POOL_SIZE):
		pool.append({"active": false})


func clear() -> void:
	for p in pool:
		p.active = false
	queue_redraw()


func emit_particle(x: float, y: float, vx: float, vy: float, life: float, size: float, color: Color, gravity: float = 0.0, shrink: bool = true, glow: bool = false) -> void:
	for p in pool:
		if p.active:
			continue
		p.active = true
		p.pos = Vector2(x, y)
		p.vel = Vector2(vx, vy)
		p.life = life
		p.max_life = life
		p.size = size
		p.color = color
		p.gravity = gravity
		p.shrink = shrink
		p.glow = glow
		return


func hit_spark(pos: Vector2, is_crit: bool) -> void:
	var count := 20 if is_crit else 10
	var colors: Array = [Color("#ffff00"), Color("#ff8800"), Color("#ff4444"), Color.WHITE] if is_crit else [Color.WHITE, Color("#ffff00"), Color("#aaddff")]
	for i in range(count):
		var a := randf() * TAU
		var speed := randf_range(60.0, 250.0 if is_crit else 150.0)
		emit_particle(
			pos.x, pos.y,
			cos(a) * speed, sin(a) * speed,
			randf_range(0.2, 0.5), randf_range(2.0, 6.0 if is_crit else 4.0),
			colors[randi() % colors.size()], 100.0, true, true
		)


func slash_trail(pos: Vector2, ang: float) -> void:
	for i in range(6):
		var along := randf_range(-12.0, 18.0)
		var perp := ang + PI * 0.5
		var spread := randf_range(-14.0, 14.0)
		var px := pos.x + cos(ang) * along + cos(perp) * spread
		var py := pos.y + sin(ang) * along + sin(perp) * spread
		var speed := randf_range(80.0, 200.0)
		emit_particle(
			px, py,
			cos(ang + randf_range(-0.4, 0.4)) * speed,
			sin(ang + randf_range(-0.4, 0.4)) * speed,
			randf_range(0.12, 0.28), randf_range(3.0, 7.0),
			Color(0.95, 0.97, 1.0), 0.0, true, true
		)


func death_effect(pos: Vector2, color: Color) -> void:
	for i in range(16):
		var a := randf() * TAU
		var speed := randf_range(30.0, 100.0)
		emit_particle(
			pos.x, pos.y,
			cos(a) * speed, sin(a) * speed,
			randf_range(0.3, 0.7), randf_range(3.0, 6.0),
			color, 60.0, true, false
		)


func update_particles(delta: float) -> void:
	var any := false
	for p in pool:
		if not p.active:
			continue
		any = true
		p.pos += p.vel * delta
		p.vel.y += float(p.gravity) * delta
		p.life -= delta
		if p.life <= 0.0:
			p.active = false
	if any:
		queue_redraw()


func draw_particles(canvas: Node2D) -> void:
	var offset := -canvas.global_position
	for p in pool:
		if not p.active:
			continue
		var t := clampf(float(p.life) / float(p.max_life), 0.0, 1.0)
		var s := float(p.size) * t if bool(p.shrink) else float(p.size)
		var col: Color = p.color
		col.a = t
		canvas.draw_rect(Rect2(p.pos + offset - Vector2(s * 0.5, s * 0.5), Vector2(s, s)), col)
