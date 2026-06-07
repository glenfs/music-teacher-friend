class_name MidiFileWriter
extends RefCounted

# Minimal Standard MIDI File (format 0) writer. Enough to export a chord or a
# chord progression so it can be opened in any DAW / notation app.
#
#   var bytes := MidiFileWriter.encode([[60,64,67],[62,65,69]], 90, 1.0)
#   FileAccess.open(path, FileAccess.WRITE).store_buffer(bytes)
#
# `chords` is an Array of Array[int] (each inner array = MIDI notes sounding
# together). Each chord lasts `beats_per_chord` quarter notes at `tempo_bpm`.

const DIVISION := 480   # ticks per quarter note
const VELOCITY := 80


static func encode(chords: Array, tempo_bpm: int = 90, beats_per_chord: float = 1.0) -> PackedByteArray:
	var track := PackedByteArray()
	# Tempo meta event at delta 0.
	var us_per_quarter: int = int(60000000.0 / float(maxi(1, tempo_bpm)))
	_vlq(track, 0)
	track.append_array(PackedByteArray([0xFF, 0x51, 0x03,
		(us_per_quarter >> 16) & 0xFF, (us_per_quarter >> 8) & 0xFF, us_per_quarter & 0xFF]))
	var ticks: int = maxi(1, int(round(beats_per_chord * float(DIVISION))))
	for chord_v in chords:
		if typeof(chord_v) != TYPE_ARRAY:
			continue
		var notes: Array = chord_v
		# Note-ons (all at delta 0).
		for n in notes:
			_vlq(track, 0)
			track.append_array(PackedByteArray([0x90, int(n) & 0x7F, VELOCITY]))
		# Note-offs: the first after `ticks`, the rest at delta 0.
		var first_off := true
		for n in notes:
			_vlq(track, ticks if first_off else 0)
			first_off = false
			track.append_array(PackedByteArray([0x80, int(n) & 0x7F, 0]))
	# End of track.
	_vlq(track, 0)
	track.append_array(PackedByteArray([0xFF, 0x2F, 0x00]))

	var out := PackedByteArray()
	out.append_array("MThd".to_ascii_buffer())
	_u32(out, 6)
	_u16(out, 0)          # format 0
	_u16(out, 1)          # one track
	_u16(out, DIVISION)
	out.append_array("MTrk".to_ascii_buffer())
	_u32(out, track.size())
	out.append_array(track)
	return out


static func _u16(buf: PackedByteArray, v: int) -> void:
	buf.append((v >> 8) & 0xFF)
	buf.append(v & 0xFF)


static func _u32(buf: PackedByteArray, v: int) -> void:
	buf.append((v >> 24) & 0xFF)
	buf.append((v >> 16) & 0xFF)
	buf.append((v >> 8) & 0xFF)
	buf.append(v & 0xFF)


# Variable-length quantity (big-endian, 7 bits/byte with continuation bit).
static func _vlq(buf: PackedByteArray, value: int) -> void:
	var v: int = maxi(0, value)
	var bytes: Array = [v & 0x7F]
	v = v >> 7
	while v > 0:
		bytes.push_front((v & 0x7F) | 0x80)
		v = v >> 7
	for b in bytes:
		buf.append(int(b))
