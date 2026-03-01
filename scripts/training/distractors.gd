class_name Distractors
extends RefCounted

const MODE_NOTE_STEPS := {
	"Major": [0, 2, 4, 5, 7, 9, 11],
	"Natural Minor": [0, 2, 3, 5, 7, 8, 10],
	"Dorian": [0, 2, 3, 5, 7, 9, 10],
	"Mixolydian": [0, 2, 4, 5, 7, 9, 10]
}


static func pick_similar(correct: String, pool: Array[String], count: int) -> Array[String]:
	var clean_correct := str(correct)
	var candidates: Array[String] = []
	for item in pool:
		var value := str(item)
		if value == clean_correct:
			continue
		if not candidates.has(value):
			candidates.append(value)
	if candidates.is_empty() or count <= 0:
		return []
	var scored: Array[Dictionary] = []
	for value in candidates:
		scored.append({
			"name": value,
			"score": _similarity_score(clean_correct, value)
		})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := int(a.get("score", 0))
		var sb := int(b.get("score", 0))
		if sa == sb:
			return str(a.get("name", "")) < str(b.get("name", ""))
		return sa > sb
	)
	var picks: Array[String] = []
	for row in scored:
		var name := str(row.get("name", ""))
		if name.is_empty():
			continue
		if picks.has(name):
			continue
		picks.append(name)
		if picks.size() >= count:
			break
	if picks.size() < count:
		var remaining := candidates.duplicate()
		remaining.shuffle()
		for name in remaining:
			if picks.has(name):
				continue
			picks.append(name)
			if picks.size() >= count:
				break
	return picks


static func _similarity_score(a: String, b: String) -> int:
	var score := 0
	score += _roman_overlap_score(a, b)
	score += _mode_overlap_score(a, b)
	if _starts_with_same_token(a, b):
		score += 5
	if _ends_with_same_token(a, b):
		score += 4
	if a.length() == b.length():
		score += 1
	return score


static func _roman_overlap_score(a: String, b: String) -> int:
	var ar := _extract_roman_tokens(a)
	var br := _extract_roman_tokens(b)
	if ar.is_empty() or br.is_empty():
		return 0
	var score := 0
	if str(ar[0]) == str(br[0]):
		score += 8
	if str(ar[ar.size() - 1]) == str(br[br.size() - 1]):
		score += 8
	var shared := 0
	for token in ar:
		if br.has(token):
			shared += 1
	score += shared * 3
	return score


static func _mode_overlap_score(a: String, b: String) -> int:
	if not MODE_NOTE_STEPS.has(a) or not MODE_NOTE_STEPS.has(b):
		return 0
	var steps_a: Array = MODE_NOTE_STEPS[a]
	var steps_b: Array = MODE_NOTE_STEPS[b]
	var shared := 0
	for step in steps_a:
		if steps_b.has(step):
			shared += 1
	if shared >= 6:
		return 12
	if shared >= 5:
		return 7
	return shared


static func _extract_roman_tokens(value: String) -> Array[String]:
	var out: Array[String] = []
	var cur := ""
	for i in value.length():
		var ch := value.substr(i, 1)
		var is_roman := ["I", "V", "i", "v"].has(ch)
		if is_roman:
			cur += ch
		else:
			if cur != "":
				out.append(cur)
				cur = ""
	if cur != "":
		out.append(cur)
	return out


static func _starts_with_same_token(a: String, b: String) -> bool:
	var at := _first_token(a)
	var bt := _first_token(b)
	return at != "" and at == bt


static func _ends_with_same_token(a: String, b: String) -> bool:
	var at := _last_token(a)
	var bt := _last_token(b)
	return at != "" and at == bt


static func _first_token(value: String) -> String:
	var parts := value.split(" ", false)
	return str(parts[0]) if not parts.is_empty() else ""


static func _last_token(value: String) -> String:
	var parts := value.split(" ", false)
	return str(parts[parts.size() - 1]) if not parts.is_empty() else ""
