@tool
extends SceneTree

# Standalone self-test runner — invoke via:
#   godot --headless --script res://scripts/qa/run_exercise_self_test.gd
# Reports pass/fail counts to stdout and exits with code 0 (success) or 1 (failure).

const ExerciseSelfTestScript = preload("res://scripts/exercises/exercise_self_test.gd")


func _init() -> void:
	var result: Dictionary = ExerciseSelfTestScript.run()
	var passed: int = int(result.get("passed", 0))
	var failed: int = int(result.get("failed", 0))
	var failures: Array = result.get("failures", [])
	print("ExerciseSelfTest: %d passed, %d failed" % [passed, failed])
	for f in failures:
		print("  FAIL: %s" % str(f))
	if failed > 0:
		quit(1)
	else:
		quit(0)
