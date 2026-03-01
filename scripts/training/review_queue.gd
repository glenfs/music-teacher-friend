class_name ReviewQueue
extends RefCounted

var misses: Dictionary = {}
var recent: Array[String] = []
var recent_limit := 6
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func record_result(item_id: String, correct: bool) -> void:
	var key := str(item_id)
	if key.is_empty():
		return
	var prev := int(misses.get(key, 0))
	if correct:
		misses[key] = maxi(0, prev - 1)
	else:
		misses[key] = prev + 1
	recent.append(key)
	while recent.size() > recent_limit:
		recent.remove_at(0)


func pick_next(candidates: Array[String]) -> String:
	var pool: Array[String] = []
	for item in candidates:
		var key := str(item)
		if key.is_empty():
			continue
		if not pool.has(key):
			pool.append(key)
	if pool.is_empty():
		return ""
	var filtered: Array[String] = []
	for key in pool:
		if not recent.has(key):
			filtered.append(key)
	if filtered.is_empty():
		filtered = pool
	var total_weight := 0.0
	var weights: Dictionary = {}
	for key in filtered:
		var miss_count := maxf(0.0, float(misses.get(key, 0)))
		var w := 1.0 + (miss_count * 2.5)
		weights[key] = w
		total_weight += w
	if total_weight <= 0.0:
		return filtered[_rng.randi_range(0, filtered.size() - 1)]
	var roll := _rng.randf() * total_weight
	var acc := 0.0
	for key in filtered:
		acc += float(weights[key])
		if roll <= acc:
			return key
	return filtered[filtered.size() - 1]
