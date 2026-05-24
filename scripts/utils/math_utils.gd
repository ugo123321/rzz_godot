class_name MathUtils

static func clampf(value: float, min_v: float, max_v: float) -> float:
	return clamp(value, min_v, max_v)


static func dist(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b)


static func angle_between(from_pos: Vector2, to_pos: Vector2) -> float:
	return (to_pos - from_pos).angle()


static func point_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func rand_range(min_v: float, max_v: float) -> float:
	return randf_range(min_v, max_v)


static func lerp_f(a: float, b: float, t: float) -> float:
	return lerpf(a, b, t)


static func pick_random(arr: Array):
	if arr.is_empty():
		return null
	return arr[randi() % arr.size()]
