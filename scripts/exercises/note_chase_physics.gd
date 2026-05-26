class_name NoteChasePhysics
extends RefCounted

# Pure iteration/spacing/scoring helpers that walk the active-notes array
# without touching parent UI or audio. Caller mutates panels + counters;
# this module just answers questions about the current note set.


# Per-item scroll speed multiplier — clef tokens move faster (so the player
# notices them in time), freeze items move slower (so they're easier to
# tap), shield slightly faster, rainbow notes slightly faster.
static func item_speed_multiplier(n: Dictionary) -> float:
	var kind := str(n.get("kind", "note"))
	if kind == "clef":
		return 1.65
	if kind == "shield":
		return 1.55
	if kind == "freeze":
		return 0.88
	if kind == "note" and bool(n.get("rainbow", false)):
		return 1.22
	return 1.0


# True when any currently-alive note is an un-triggered clef token. While
# such a token exists the spawn loop pauses so the clef switch happens before
# the new clef's notes start appearing.
static func has_untriggered_clef_token(active_notes: Array) -> bool:
	for item in active_notes:
		var n: Dictionary = item
		if bool(n.get("hit", false)):
			continue
		if str(n.get("kind", "")) != "clef":
			continue
		if bool(n.get("triggered", false)):
			continue
		var node_obj = n.get("node", null)
		if node_obj != null and is_instance_valid(node_obj):
			return true
	return false


# True if a special of the given kind is currently alive. `kind == "rainbow"`
# matches any note flagged rainbow; other kinds match by `n.kind` directly.
static func has_active_special(active_notes: Array, kind: String) -> bool:
	for item in active_notes:
		var n: Dictionary = item
		if bool(n.get("hit", false)):
			continue
		var note_kind := str(n.get("kind", ""))
		if kind == "rainbow":
			if note_kind != "note" or not bool(n.get("rainbow", false)):
				continue
		elif note_kind != kind:
			continue
		var node_obj = n.get("node", null)
		if node_obj != null and is_instance_valid(node_obj):
			return true
	return false


# Count visible target notes between the spawn line and the staff left edge.
# Caller passes the geometry so this module stays UI-free.
static func visible_target_count(active_notes: Array, staff_left_x: float, spawn_x: float) -> int:
	var count := 0
	for item in active_notes:
		var n: Dictionary = item
		if bool(n.get("hit", false)):
			continue
		if str(n.get("kind", "note")) != "note":
			continue
		if not bool(n.get("target", false)):
			continue
		var node_obj = n.get("node", null)
		if node_obj == null or not is_instance_valid(node_obj):
			continue
		var panel := node_obj as Panel
		if panel == null:
			continue
		if panel.position.x + panel.size.x < staff_left_x:
			continue
		if panel.position.x > spawn_x + 8.0:
			continue
		count += 1
	return count


# Pick a fresh spawn x that doesn't overlap any existing note within `min_gap`
# pixels. Walks up to 16 iterations of "push past the nearest conflict" so
# multi-note spawn bursts don't pile on top of each other.
static func next_spawn_x_with_spacing(active_notes: Array, base_x: float, min_gap: float = 58.0) -> float:
	var x := base_x
	for _i in range(16):
		var overlap := false
		for item in active_notes:
			var n: Dictionary = item
			if bool(n.get("hit", false)):
				continue
			if str(n.get("kind", "note")) == "clef":
				continue
			var node_obj = n.get("node", null)
			if node_obj == null or not is_instance_valid(node_obj):
				continue
			var panel := node_obj as Panel
			if panel == null:
				continue
			if absf(panel.position.x - x) < min_gap:
				x = panel.position.x + min_gap
				overlap = true
				break
		if not overlap:
			break
	return x


# After a clef switch triggers, wipe any notes that just spawned (or are still
# near the spawn line) so the player doesn't get blindsided by old-clef notes
# mid-switch. Mutates by queue_free'ing the dropped panels. Returns the new
# `active_notes` array + a count of dropped note-kind items (caller subtracts
# this from `_question_index` so the round counter stays correct).
static func clear_recent_notes_after_clef_switch(
	active_notes: Array,
	elapsed: float,
	spawn_x: float,
	recent_seconds: float = 2.0
) -> Dictionary:
	var kept: Array[Dictionary] = []
	var removed_notes := 0
	var spawn_cutoff_x := spawn_x - 24.0
	for item in active_notes:
		var n: Dictionary = item
		var node_obj = n.get("node", null)
		if node_obj == null or not is_instance_valid(node_obj):
			continue
		var panel := node_obj as Panel
		if panel == null:
			continue
		var kind := str(n.get("kind", "note"))
		if kind == "clef":
			kept.append(n)
			continue
		var spawn_t := float(n.get("spawn_t", -9999.0))
		var age := elapsed - spawn_t
		var near_spawn_zone := panel.position.x >= spawn_cutoff_x
		if age <= recent_seconds or near_spawn_zone:
			if kind == "note":
				removed_notes += 1
			panel.queue_free()
			continue
		kept.append(n)
	return {
		"active_notes": kept,
		"removed_notes": removed_notes,
	}
