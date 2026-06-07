class_name ReviewQueue
extends RefCounted

var misses: Dictionary = {}
var recent: Array[String] = []
var recent_limit := 8
var attempts: Dictionary = {}
var corrects: Dictionary = {}
var streaks: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func record_result(item_id: String, correct: bool) -> void:
	var key := str(item_id)
	if key.is_empty():
		return
	attempts[key] = int(attempts.get(key, 0)) + 1
	var prev := int(misses.get(key, 0))
	if correct:
		corrects[key] = int(corrects.get(key, 0)) + 1
		streaks[key] = int(streaks.get(key, 0)) + 1
		misses[key] = maxi(0, prev - 1)
	else:
		streaks[key] = 0
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
	var soft_recent_limit: int = mini(recent_limit, maxi(1, pool.size() - 1))
	var effective_recent: Array[String] = recent.slice(maxi(0, recent.size() - soft_recent_limit), recent.size())
	for key in pool:
		if not effective_recent.has(key):
			filtered.append(key)
	if filtered.is_empty():
		filtered = _least_recent_candidates(pool)
	var total_weight := 0.0
	var weights: Dictionary = {}
	for key in filtered:
		var miss_count := maxf(0.0, float(misses.get(key, 0)))
		var asked_count := int(attempts.get(key, 0))
		var correct_count := int(corrects.get(key, 0))
		var accuracy := float(correct_count) / float(maxi(1, asked_count))
		var mastery_discount := accuracy * minf(0.75, float(streaks.get(key, 0)) * 0.16)
		var under_practiced_boost := maxf(0.0, 3.0 - float(asked_count)) * 0.22
		var w := maxf(0.15, 1.0 + (miss_count * 3.0) + under_practiced_boost - mastery_discount)
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


func _least_recent_candidates(pool: Array[String]) -> Array[String]:
	var best_age := -1
	var out: Array[String] = []
	for key in pool:
		var age := recent.size() + 1
		for i in range(recent.size() - 1, -1, -1):
			if recent[i] == key:
				age = recent.size() - i
				break
		if age > best_age:
			best_age = age
			out = [key]
		elif age == best_age:
			out.append(key)
	return out if not out.is_empty() else pool
