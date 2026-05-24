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


static func segment_circle_crossings(a: Vector2, b: Vector2, center: Vector2, radius: float) -> Array:
	var ab := b - a
	var ab_len_sq := ab.length_squared()
	if ab_len_sq < 0.0001:
		return []
	var ac := a - center
	var b_coeff := 2.0 * ac.dot(ab)
	var c_coeff := ac.length_squared() - radius * radius
	var disc := b_coeff * b_coeff - 4.0 * ab_len_sq * c_coeff
	if disc < 0.0:
		return []
	var sqrt_disc := sqrt(disc)
	var inv_denom := 1.0 / (2.0 * ab_len_sq)
	var ts: Array[float] = []
	var t_a: float = (-b_coeff - sqrt_disc) * inv_denom
	var t_b: float = (-b_coeff + sqrt_disc) * inv_denom
	if t_a >= 0.0 and t_a <= 1.0:
		ts.append(t_a)
	if t_b >= 0.0 and t_b <= 1.0:
		ts.append(t_b)
	ts.sort()
	var events: Array = []
	var inside: bool = ac.length_squared() <= radius * radius
	var last_t := -1.0
	for t in ts:
		if last_t >= 0.0 and abs(t - last_t) < 0.000001:
			continue
		last_t = t
		if inside:
			events.append({"t": t, "enter": false})
			inside = false
		else:
			events.append({"t": t, "enter": true})
			inside = true
	return events


static func count_path_circle_hits(path: Array, center: Vector2, radius: float) -> int:
	if path.is_empty():
		return 0
	var start: Vector2 = path[0]
	var inside: bool = start.distance_to(center) <= radius
	var count := 1 if inside else 0
	for i in range(path.size() - 1):
		var from: Vector2 = path[i]
		var to: Vector2 = path[i + 1]
		for ev in segment_circle_crossings(from, to, center, radius):
			if bool(ev.get("enter", false)):
				if not inside:
					count += 1
				inside = true
			else:
				inside = false
	return count


static func rand_range(min_v: float, max_v: float) -> float:
	return randf_range(min_v, max_v)


static func lerp_f(a: float, b: float, t: float) -> float:
	return lerpf(a, b, t)


static func pick_random(arr: Array):
	if arr.is_empty():
		return null
	return arr[randi() % arr.size()]
