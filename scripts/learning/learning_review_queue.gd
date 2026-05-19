extends RefCounted

# Lightweight spaced-review queue for Learning Mode concepts.
# Tracks performance per concept and schedules future review with a small
# spaced-repetition ladder.

var _concepts: Dictionary = {}  # concept_id -> review analytics
var _rng := RandomNumberGenerator.new()

# Strength levels
const STRENGTH_NEW := 0
const STRENGTH_WEAK := 1
const STRENGTH_LEARNING := 2
const STRENGTH_MASTERED := 3

const SAME_DAY_SECONDS := 6 * 60 * 60
const REVIEW_STEPS_SECONDS := [
	SAME_DAY_SECONDS,
	1 * 24 * 60 * 60,
	3 * 24 * 60 * 60,
	7 * 24 * 60 * 60,
	14 * 24 * 60 * 60,
]


func _init() -> void:
	_rng.randomize()


func record_result(concept_id: String, correct: bool, first_try: bool, response_ms: float = -1.0, confidence: String = "", skill_family: String = "") -> void:
	if concept_id.is_empty():
		return
	if not _concepts.has(concept_id):
		_concepts[concept_id] = {
			"attempts": 0,
			"correct": 0,
			"first_try": 0,
			"strength": STRENGTH_NEW,
			"avg_response_ms": 0.0,
			"last_response_ms": 0.0,
			"confidence_sure": 0,
			"confidence_unsure": 0,
			"consecutive_success": 0,
			"skill_family": "",
			"last_seen_unix": 0,
			"due_unix": 0,
		}
	var c: Dictionary = _concepts[concept_id]
	c["attempts"] = int(c["attempts"]) + 1
	if correct:
		c["correct"] = int(c["correct"]) + 1
	if first_try and correct:
		c["first_try"] = int(c["first_try"]) + 1
	if response_ms > 0.0:
		var prev_count: int = maxi(int(c["attempts"]) - 1, 0)
		var prev_avg: float = float(c.get("avg_response_ms", 0.0))
		var next_avg: float = response_ms
		if prev_count > 0:
			next_avg = ((prev_avg * float(prev_count)) + response_ms) / float(prev_count + 1)
		c["avg_response_ms"] = next_avg
		c["last_response_ms"] = response_ms
	if confidence == "sure":
		c["confidence_sure"] = int(c.get("confidence_sure", 0)) + 1
	elif confidence == "unsure":
		c["confidence_unsure"] = int(c.get("confidence_unsure", 0)) + 1
	if skill_family != "":
		c["skill_family"] = skill_family
	c["consecutive_success"] = int(c.get("consecutive_success", 0)) + 1 if correct and first_try else 0
	var now_unix: int = Time.get_unix_time_from_system()
	c["last_seen_unix"] = now_unix
	c["strength"] = _compute_strength(c)
	c["due_unix"] = _compute_due_unix(c, correct, now_unix)


func record_confidence(concept_id: String, confidence: String) -> void:
	if concept_id.is_empty() or not _concepts.has(concept_id):
		return
	var c: Dictionary = _concepts[concept_id]
	if confidence == "sure":
		c["confidence_sure"] = int(c.get("confidence_sure", 0)) + 1
	elif confidence == "unsure":
		c["confidence_unsure"] = int(c.get("confidence_unsure", 0)) + 1


func _compute_strength(c: Dictionary) -> int:
	var attempts: int = int(c.get("attempts", 0))
	if attempts == 0:
		return STRENGTH_NEW
	var accuracy: float = float(c.get("correct", 0)) / float(attempts)
	var ft: int = int(c.get("first_try", 0))
	var avg_response_ms: float = float(c.get("avg_response_ms", 0.0))
	var fluent: bool = avg_response_ms <= 0.0 or avg_response_ms <= 4500.0
	if attempts >= 3 and accuracy >= 0.9 and ft >= 2 and fluent:
		return STRENGTH_MASTERED
	elif attempts >= 2 and (accuracy >= 0.6 or ft >= 1):
		return STRENGTH_LEARNING
	else:
		return STRENGTH_WEAK


func _compute_due_unix(c: Dictionary, correct: bool, now_unix: int) -> int:
	if not correct:
		return now_unix
	var streak: int = int(c.get("consecutive_success", 0))
	var ladder_index: int = mini(maxi(streak - 1, 0), REVIEW_STEPS_SECONDS.size() - 1)
	return now_unix + REVIEW_STEPS_SECONDS[ladder_index]


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
	var now_unix: int = Time.get_unix_time_from_system()
	var pool: Array[String] = []
	var weights: Dictionary = {}
	var due_pool: Array[String] = []
	for concept_id in _concepts:
		if exclude.has(concept_id):
			continue
		var concept: Dictionary = _concepts[concept_id]
		var s: int = int(concept.get("strength", STRENGTH_NEW))
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
		var due_unix: int = int(concept.get("due_unix", 0))
		var is_due: bool = due_unix <= 0 or due_unix <= now_unix
		if is_due:
			var overdue_days: float = float(maxi(now_unix - due_unix, 0)) / 86400.0
			w *= 2.5 + minf(overdue_days, 3.0)
			due_pool.append(concept_id)
		pool.append(concept_id)
		weights[concept_id] = w
	if not due_pool.is_empty():
		pool = due_pool

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


func get_skill_family(concept_id: String) -> String:
	if not _concepts.has(concept_id):
		return ""
	return str(_concepts[concept_id].get("skill_family", ""))


func get_due_unix(concept_id: String) -> int:
	if not _concepts.has(concept_id):
		return 0
	return int(_concepts[concept_id].get("due_unix", 0))


func to_dict() -> Dictionary:
	return _concepts.duplicate(true)


func from_dict(data: Dictionary) -> void:
	_concepts = data.duplicate(true)
