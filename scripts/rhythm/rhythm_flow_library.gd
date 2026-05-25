class_name RhythmFlowLibrary
extends RefCounted

# Pure rhythm-flow data tables — pattern library (one exercise set per
# difficulty band) and the input-timing windows. Caller (interval_birds.gd)
# owns the live difficulty level + per-event triplet-assist multipliers and
# just queries this module for the static base data.


# Timing windows in seconds: how close to the expected beat counts as
# "perfect" / "good" / "ok" hit. Caller may multiply these for triplet assist.
static func timing_windows() -> Dictionary:
	return {"perfect": 0.050, "good": 0.100, "ok": 0.200}


# Returns the exercise pattern bank for the given 1-indexed difficulty level.
# Each pattern is an Array of event dicts: {type: "hit"|"rest", duration_beats: float}.
# Levels above the table cap clamp to the densest set.
static func pattern_library(difficulty_level: int) -> Array[Array]:
	var idx := clampi(difficulty_level - 1, 0, EXERCISES.size() - 1)
	var selected: Array = EXERCISES[idx]
	var out: Array[Array] = []
	for pattern_v in selected:
		out.append(pattern_v as Array)
	return out


const EXERCISES: Array = [
	[
		[
			{"type": "hit", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 1.0},
			{"type": "rest", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 1.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "rest", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 2.0},
			{"type": "hit", "duration_beats": 2.0}
		],
		[
			{"type": "hit", "duration_beats": 4.0}
		],
		[
			{"type": "rest", "duration_beats": 2.0},
			{"type": "hit", "duration_beats": 2.0}
		],
		[
			{"type": "hit", "duration_beats": 2.0},
			{"type": "rest", "duration_beats": 2.0}
		]
	],
	[
		[
			{"type": "hit", "duration_beats": 1.0},
			{"type": "rest", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0},
			{"type": "rest", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 2.0},
			{"type": "hit", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "rest", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 4.0}
		],
		[
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 2.0}
		]
	],
	[
		[
			{"type": "hit", "duration_beats": 2.0},
			{"type": "rest", "duration_beats": 2.0}
		],
		[
			{"type": "rest", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0},
			{"type": "rest", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 3.0},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 1.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 2.0}
		],
		[
			{"type": "hit", "duration_beats": 4.0}
		]
	],
	[
		# 16th-note intro (beamed pairs/runs)
		[
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "rest", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 2.0}
		],
		[
			{"type": "hit", "duration_beats": 1.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 1.0}
		]
	],
	[
		# 16th-note practice (denser runs)
		[
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 2.0}
		],
		[
			{"type": "hit", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "rest", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "rest", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 3.0},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25}
		]
	]
]
