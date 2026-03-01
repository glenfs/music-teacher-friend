class_name Conductor
extends Node

var _events: Array[Dictionary] = []
var _clock_start_sec := 0.0


func _ready() -> void:
	_clock_start_sec = float(Time.get_ticks_usec()) / 1000000.0
	set_process(true)


func _process(_delta: float) -> void:
	if _events.is_empty():
		return
	var now := _now_sec()
	while not _events.is_empty() and float(_events[0].get("time", 0.0)) <= now:
		var event: Dictionary = _events.pop_front()
		var cb: Callable = event.get("callback", Callable())
		if cb.is_valid():
			cb.call()


func schedule(delay_sec: float, callback: Callable) -> void:
	if not callback.is_valid():
		return
	var event_time := _now_sec() + maxf(0.0, delay_sec)
	_events.append({
		"time": event_time,
		"callback": callback
	})
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("time", 0.0)) < float(b.get("time", 0.0))
	)


func schedule_series(start_sec: float, step_sec: float, callbacks: Array[Callable]) -> void:
	var start := maxf(0.0, start_sec)
	var step := maxf(0.0, step_sec)
	for i in callbacks.size():
		var cb: Callable = callbacks[i]
		if not cb.is_valid():
			continue
		schedule(start + (step * float(i)), cb)


func clear() -> void:
	_events.clear()


func _now_sec() -> float:
	return (float(Time.get_ticks_usec()) / 1000000.0) - _clock_start_sec
