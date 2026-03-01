class_name TrainingSession
extends RefCounted

var score := 0
var total := 0
var asked := 0
var current_question_id := ""
var current_correct_answer := ""
var current_prompt := ""
var current_choices: Array[String] = []
var current_payload: Dictionary = {}
var last_correct := false

var on_question_ready: Callable
var on_feedback: Callable
var on_session_end: Callable


func start(total_questions: int) -> void:
	score = 0
	asked = 0
	total = maxi(0, total_questions)
	current_question_id = ""
	current_correct_answer = ""
	current_prompt = ""
	current_choices.clear()
	current_payload = {}
	last_correct = false


func next_question(generator: Callable) -> void:
	if asked >= total:
		if on_session_end.is_valid():
			on_session_end.call(self)
		return
	if not generator.is_valid():
		return
	var q: Variant = generator.call()
	if not (q is Dictionary):
		return
	var d := q as Dictionary
	current_payload = d.duplicate(true)
	current_question_id = str(d.get("id", ""))
	current_correct_answer = str(d.get("correct", ""))
	current_prompt = str(d.get("prompt", ""))
	current_choices.clear()
	var raw_choices: Array = d.get("choices", [])
	for c in raw_choices:
		current_choices.append(str(c))
	asked += 1
	if on_question_ready.is_valid():
		on_question_ready.call(d)


func submit(answer: String) -> void:
	last_correct = str(answer) == current_correct_answer
	if last_correct:
		score += 1
	if on_feedback.is_valid():
		on_feedback.call(last_correct, answer, current_correct_answer, self)
	if asked >= total and on_session_end.is_valid():
		on_session_end.call(self)
