extends RefCounted

# Lightweight spaced-review queue for Learning Mode concepts.
# Tracks quiz performance per concept (note ID like "treble:C4")
# and surfaces weak items for later review.

var _concepts: Dictionary = {}  # concept_id -> {attempts, correct, first_try, strength}
var _rng := RandomNumberGenerator.new()

# Strength levels
const STRENGTH_NEW := 0
const STRENGTH_WEAK := 1
const STRENGTH_LEARNING := 2
const STRENGTH_MASTERED := 3


func _init() -> void:
	_rng.randomize()


func record_result(concept_id: String, correct: bool, first_try: bool) -> void:
	if concept_id.is_empty():
		return
	if not _concepts.has(concept_id):
		_concepts[concept_id] = {"attempts": 0, "correct": 0, "first_try": 0, "strength": STRENGTH_NEW}
	var c: Dictionary = _concepts[concept_id]
	c["attempts"] = int(c["attempts"]) + 1
	if correct:
		c["correct"] = int(c["correct"]) + 1
	if first_try and correct:
		c["first_try"] = int(c["first_try"]) + 1
	c["strength"] = _compute_strength(c)


func _compute_strength(c: Dictionary) -> int:
	var attempts: int = int(c.get("attempts", 0))
	if attempts == 0:
		return STRENGTH_NEW
	var accuracy: float = float(c.get("correct", 0)) / float(attempts)
	var ft: int = int(c.get("first_try", 0))
	if attempts >= 2 and accuracy >= 0.9 and ft >= 2:
		return STRENGTH_MASTERED
	elif accuracy >= 0.6:
		return STRENGTH_LEARNING
	else:
		return STRENGTH_WEAK


func get_weak_concepts(max_count: int = 5) -> Array[String]:
	var weak: Array[String] = []
	for concept_id in _concepts:
		var s: int = int(_concepts[concept_id].get("strength", STRENGTH_NEW))
		if s == STRENGTH_WEAK or s == STRENGTH_NEW:
			weak.append(concept_id)
	weak.shuffle()
	if weak.size() > max_count:
		weak.resize(max_count)
	return weak


func get_review_items(count: int = 5, exclude: Array[String] = []) -> Array[String]:
	var pool: Array[String] = []
	var weights: Dictionary = {}
	for concept_id in _concepts:
		if exclude.has(concept_id):
			continue
		var s: int = int(_concepts[concept_id].get("strength", STRENGTH_NEW))
		var w: float = 1.0
		match s:
			STRENGTH_WEAK:
				w = 4.0
			STRENGTH_LEARNING:
				w = 2.0
			STRENGTH_MASTERED:
				w = 0.5
			STRENGTH_NEW:
				w = 3.0
		pool.append(concept_id)
		weights[concept_id] = w

	var result: Array[String] = []
	for _i in mini(count, pool.size()):
		if pool.is_empty():
			break
		var total: float = 0.0
		for cid in pool:
			total += float(weights.get(cid, 1.0))
		if total <= 0.0:
			break
		var roll: float = _rng.randf() * total
		var acc: float = 0.0
		var pick: String = pool[0]
		for cid in pool:
			acc += float(weights.get(cid, 1.0))
			if roll <= acc:
				pick = cid
				break
		result.append(pick)
		pool.erase(pick)
	return result


func get_concept_strength(concept_id: String) -> int:
	if _concepts.has(concept_id):
		return int(_concepts[concept_id].get("strength", STRENGTH_NEW))
	return STRENGTH_NEW


func get_accuracy(concept_id: String) -> float:
	if not _concepts.has(concept_id):
		return 0.0
	var c: Dictionary = _concepts[concept_id]
	var attempts: int = int(c.get("attempts", 0))
	if attempts == 0:
		return 0.0
	return float(c.get("correct", 0)) / float(attempts)


func to_dict() -> Dictionary:
	return _concepts.duplicate(true)


func from_dict(data: Dictionary) -> void:
	_concepts = data.duplicate(true)
