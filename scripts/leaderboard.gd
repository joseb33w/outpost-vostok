class_name Leaderboard
extends Node

signal top10_loaded(rows: Array)
signal submit_done(ok: bool)

var _busy := false

func fetch_top10() -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		var rows: Array = []
		if code == 200:
			var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
			if parsed is Array:
				rows = parsed
		top10_loaded.emit(rows))
	var url := "%s/rest/v1/%s?select=initials,score,wave&order=score.desc&limit=10" % [CFG.SUPABASE_URL, CFG.SCORES_TABLE]
	var err := req.request(url, _headers(), HTTPClient.METHOD_GET)
	if err != OK:
		req.queue_free()
		top10_loaded.emit([])

func submit_score(initials: String, score: int, wave: int) -> void:
	if _busy:
		return
	_busy = true
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		req.queue_free()
		_busy = false
		submit_done.emit(code >= 200 and code < 300))
	var url := "%s/rest/v1/%s" % [CFG.SUPABASE_URL, CFG.SCORES_TABLE]
	var body := JSON.stringify({"initials": initials.to_upper().substr(0, 3), "score": score, "wave": wave})
	var err := req.request(url, _headers(), HTTPClient.METHOD_POST, body)
	if err != OK:
		req.queue_free()
		_busy = false
		submit_done.emit(false)

func _headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + CFG.SUPABASE_ANON_KEY,
		"Authorization: Bearer " + CFG.SUPABASE_ANON_KEY,
		"Content-Type: application/json",
		"Prefer: return=minimal",
	])
