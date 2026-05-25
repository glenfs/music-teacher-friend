class_name LearningStepFactory
extends RefCounted

# Pure step/module builders used by the learning map's placement check and
# weakness-review flow. All inputs are passed in — the caller (interval_birds.gd)
# owns the live registry and progress objects and just hands them over.
#
# These were originally _build_learning_* methods on interval_birds; pulled out
# because they only touched static module data and the LMD helper class.


const LearningModuleDataScript = preload("res://scripts/learning/learning_module_data.gd")


# Build a synthetic module that contains every step from every registered
# module. The lesson player uses this in placement / test-out mode to find
# where the student belongs in the curriculum.
static func placement_module(all_modules: Array) -> Dictionary:
	var steps: Array[Dictionary] = []
	for module_data in all_modules:
		for step in module_data.get("steps", []):
			if step is Dictionary:
				steps.append((step as Dictionary).duplicate(true))
	if steps.is_empty():
		return {}
	var placement: Dictionary = LearningModuleDataScript.create_module(
		"_placement_assessment",
		"Placement Check",
		"Find the right starting point for your learning path.",
		"",
		steps,
		5,
		""
	)
	placement["placement_mode"] = true
	placement["test_out_max_questions"] = 12
	return placement


# Build a synthetic "weakness review" module that bundles steps for each
# concept id the spaced-repetition queue surfaced.
static func review_module(review_items: Array, all_modules: Array) -> Dictionary:
	var steps: Array[Dictionary] = []
	steps.append(LearningModuleDataScript.create_intro_step(
		"Review Practice",
		"Let's review the concepts that need the most support. Answer carefully and take your time.",
		"Mixed review: notes, theory, listening, keyboard, and rhythm"
	))
	for concept_id_variant in review_items:
		var step: Dictionary = review_step(str(concept_id_variant), all_modules)
		if not step.is_empty():
			steps.append(step)
	if steps.size() <= 1:
		return {}
	return LearningModuleDataScript.create_module(
		"_review_practice",
		"Review Practice",
		"Practice your weak concepts",
		"",
		steps,
		4,
		""
	)


# Map a single concept_id back to the step dict that exercises it.
# Returns {} when no matching step exists in any module.
static func review_step(concept_id: String, all_modules: Array) -> Dictionary:
	if concept_id.begins_with("treble:") or concept_id.begins_with("bass:"):
		return note_review_step(concept_id, all_modules)
	if concept_id.begins_with("theory:"):
		var theory_item: Dictionary = LearningModuleDataScript.find_theory_item_by_concept_id(concept_id)
		if not theory_item.is_empty():
			var quiz_step: Dictionary = LearningModuleDataScript.create_quiz_step(
				str(theory_item.get("question", "")),
				theory_item.get("choices", []),
				int(theory_item.get("correct_index", 0)),
				"Correct.",
				"Not quite."
			)
			quiz_step["concept_id"] = concept_id
			return quiz_step
	if concept_id.begins_with("quiz:"):
		for module_data in all_modules:
			for step in module_data.get("steps", []):
				if int(step.get("type", -1)) == 4 and ("quiz:" + str(step.get("question", "")).left(40)) == concept_id:
					return step.duplicate(true)
	if concept_id.begins_with("listening:"):
		for module_data in all_modules:
			for step in module_data.get("steps", []):
				if int(step.get("type", -1)) != 10:
					continue
				for item in step.get("items", []):
					if not (item is Dictionary):
						continue
					var item_dict: Dictionary = (item as Dictionary).duplicate(true)
					var item_concept: String = str(item_dict.get("concept_id", listening_concept_id(item_dict)))
					if item_concept == concept_id:
						item_dict["concept_id"] = item_concept
						return LearningModuleDataScript.create_listening_quiz_step(
							"Listening Review",
							"Listen once, then choose the best answer.",
							[item_dict]
						)
	if concept_id.begins_with("keyboard:"):
		for module_data in all_modules:
			for step in module_data.get("steps", []):
				if int(step.get("type", -1)) == 15 and keyboard_concept_id(step) == concept_id:
					return step.duplicate(true)
	if concept_id.begins_with("rhythm:"):
		for module_data in all_modules:
			for step in module_data.get("steps", []):
				if int(step.get("type", -1)) == 12 and rhythm_concept_id(step) == concept_id:
					return step.duplicate(true)
	return {}


static func note_review_step(concept_id: String, all_modules: Array) -> Dictionary:
	var parts: PackedStringArray = concept_id.split(":")
	if parts.size() < 2:
		return {}
	var clef: String = parts[0]
	var note_id: String = parts[1]
	var note_item: Dictionary = {}
	var search_pool: Array = LearningModuleDataScript.treble_note_pool_full() if clef == "treble" else LearningModuleDataScript.bass_note_pool_full()
	for entry in search_pool:
		if str(entry.get("note_id", "")) == note_id:
			note_item = entry.duplicate(true)
			break
	if note_item.is_empty():
		for module_data in all_modules:
			for step in module_data.get("steps", []):
				var stype: int = int(step.get("type", -1))
				if stype == 13 or stype == 14:
					if str(step.get("clef", "")) == clef and str(step.get("target_note_id", "")) == note_id:
						note_item = {
							"clef": clef,
							"note_name": note_id[0],
							"note_step": int(step.get("target_step", 4)),
							"note_id": note_id,
						}
						break
			if not note_item.is_empty():
				break
	if note_item.is_empty():
		return {}
	var choice_data: Dictionary = note_choice_data(str(note_item.get("note_name", note_id[0])))
	var quiz_step: Dictionary = LearningModuleDataScript.create_note_quiz_step(
		clef,
		str(note_item.get("note_name", note_id[0])),
		int(note_item.get("note_step", 4)),
		choice_data.get("choices", []),
		int(choice_data.get("correct_index", 0)),
		"Correct.",
		"Not quite."
	)
	quiz_step["concept_id"] = concept_id
	return quiz_step


# Pick 3 distractors for a note-quiz: 1 adjacent letter + 2 non-adjacent.
static func note_choice_data(correct_letter: String) -> Dictionary:
	var all_letters := ["C", "D", "E", "F", "G", "A", "B"]
	var ci: int = all_letters.find(correct_letter)
	var adjacent: Array[String] = []
	var non_adjacent: Array[String] = []
	for offset in [-1, 1]:
		var didx: int = (ci + offset + 7) % 7
		var d: String = all_letters[didx]
		if d != correct_letter and not adjacent.has(d):
			adjacent.append(d)
	for offset in [-3, 3, -4, 4]:
		var didx2: int = (ci + offset + 7) % 7
		var d2: String = all_letters[didx2]
		if d2 != correct_letter and not adjacent.has(d2) and not non_adjacent.has(d2):
			non_adjacent.append(d2)
		if non_adjacent.size() >= 2:
			break
	adjacent.shuffle()
	non_adjacent.shuffle()
	var distractors: Array[String] = []
	if not adjacent.is_empty():
		distractors.append(adjacent[0])
	for d in non_adjacent:
		distractors.append(d)
		if distractors.size() >= 3:
			break
	if distractors.size() < 3 and adjacent.size() > 1:
		distractors.append(adjacent[1])
	var choices: Array[String] = [correct_letter]
	for d in distractors:
		choices.append(d)
	choices.shuffle()
	return {"choices": choices, "correct_index": choices.find(correct_letter)}


# Stable concept-id encodings — used both to register the item with the
# review queue and to look it back up.
static func listening_concept_id(item: Dictionary) -> String:
	var joined_ids := ""
	for note_id in item.get("note_ids", []):
		if joined_ids != "":
			joined_ids += "_"
		joined_ids += str(note_id)
	return "listening:%s:%s" % [str(item.get("label", "item")), joined_ids]


static func keyboard_concept_id(step: Dictionary) -> String:
	return "keyboard:%s" % str(step.get("target_note_id", ""))


static func rhythm_concept_id(step: Dictionary) -> String:
	var pattern_text := ""
	for beat in step.get("pattern", []):
		if pattern_text != "":
			pattern_text += "-"
		pattern_text += str(beat)
	return "rhythm:%s:%s" % [str(step.get("title", "pattern")), pattern_text]
