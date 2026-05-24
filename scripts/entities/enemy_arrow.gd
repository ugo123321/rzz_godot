extends Node2D
class_name EnemyArrow

const ARROW_TEXTURES: Array[String] = [
	"res://assets/Characters/Characters(100x100)/Archer/Arrow(projectile)/Arrow01(32x32).png",
	"res://assets/Characters/Characters(100x100)/Archer/Arrow(projectile)/Arrow02(32x32).png",
	"res://assets/Characters/Characters(100x100)/Archer/Arrow(projectile)/Arrow03(32x32).png",
]
const HIT_RADIUS := 6.0
const DRAW_SCALE := 1.0
const SPAWN_OFFSET := 10.0

var velocity := Vector2.ZERO
var damage := 10
var _battle: BattleController
var _player: BattlePlayer
var _alive := true


static func spawn(
	battle: BattleController,
	from_pos: Vector2,
	to_pos: Vector2,
	dmg: int,
	speed: float
) -> void:
	if battle == null or battle.player == null:
		return
	var dir := to_pos - from_pos
	if dir.length_squared() < 1.0:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	var arrow := EnemyArrow.new()
	arrow._battle = battle
	arrow._player = battle.player
	arrow.damage = maxi(1, dmg)
	arrow.velocity = dir * maxf(40.0, speed)
	arrow.global_position = from_pos + dir * SPAWN_OFFSET
	arrow.rotation = dir.angle()
	battle.projectiles.add_child(arrow)


func is_alive() -> bool:
	return _alive


func update_arrow(delta: float) -> void:
	if not _alive:
		return
	if delta <= 0.0:
		return
	if _battle == null or _player == null or not is_instance_valid(_player):
		queue_free()
		return
	if _battle.state != GameState.PLAYING:
		queue_free()
		return
	global_position += velocity * delta
	if _try_hit_player():
		return
	if not _battle.is_in_bounds(global_position):
		queue_free()


func destroy_blocked(from: Vector2, to: Vector2) -> void:
	if not _alive:
		return
	_alive = false
	if _battle and _battle.particles:
		_battle.particles.hit_spark(global_position, false)
		_battle.particles.slash_trail(global_position, (to - from).angle())
	queue_free()


func _ready() -> void:
	var sprite := Sprite2D.new()
	var tex_path: String = ARROW_TEXTURES[randi() % ARROW_TEXTURES.size()]
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
	else:
		sprite.texture = load(ARROW_TEXTURES[1])
	sprite.centered = true
	sprite.scale = Vector2.ONE * SpriteHelper.pixel_scale(DRAW_SCALE)
	SpriteHelper.apply_pixel_art(sprite)
	add_child(sprite)


func _try_hit_player() -> bool:
	if _player.hp <= 0:
		return false
	if _player.state == BattlePlayer.State.BULLET_TIME:
		return false
	if _player.is_attack_invincible():
		return false
	var player_r := _player.get_effective_radius() + 2.0
	if global_position.distance_to(_player.global_position) > HIT_RADIUS + player_r:
		return false
	_alive = false
	var dealt := _player.take_damage(damage)
	if dealt > 0:
		if _battle.combat:
			_battle.combat.spawn_damage_number(
				_player.global_position + Vector2(0.0, -_player.get_effective_radius() - 8.0),
				dealt,
				false,
				false,
				Color("#e05840")
			)
		if _battle.particles:
			_battle.particles.hit_spark(_player.global_position, false)
	queue_free()
	return true
