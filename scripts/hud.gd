class_name Hud
extends CanvasLayer
## All 2D UI + mobile touch controls. Drives Main via signals + read state.
## move_vector/look_delta/firing are polled by Main each frame.

signal start_pressed()
signal restart_pressed()
signal submit_pressed(initials: String)
signal reload_pressed()
signal dodge_pressed()

const ACCENT := Color(0.21, 0.77, 1.0)
const DANGER := Color(1.0, 0.35, 0.30)
const PANEL := Color(0.04, 0.06, 0.09, 0.86)

# Read by Main:
var move_vector := Vector2.ZERO     # x right, y up(=forward)
var look_delta := Vector2.ZERO      # consumed (zeroed) by Main each frame
var firing := false

var _state := "menu"                # menu | play | over
var _touch_mode := false
var _insets := {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}

# touch tracking: index -> role dict
var _touches := {}
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _joy_active := false

# in-game widgets
var _controls: Control
var _hp_bg: ColorRect
var _hp_fill: ColorRect
var _hp_label: Label
var _wave_label: Label
var _hostiles_label: Label
var _score_label: Label
var _ammo_label: Label
var _msg_label: Label
var _msg_sub: Label
var _dmg_flash: ColorRect

# panels
var _menu: Control
var _menu_board: Label
var _over: Control
var _over_stats: Label
var _over_board: Label
var _initials_edit: LineEdit
# native menu/over buttons — tapped via explicit touch hit-test in _input() because
# emulate_mouse_from_touch is off (touch no longer auto-presses Control buttons).
var _deploy_btn: Button
var _submit_btn: Button
var _redeploy_btn: Button

func _ready() -> void:
	layer = 10
	_build()
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	call_deferred("_relayout")
	_refresh_insets()

func _process(_dt: float) -> void:
	if _state == "play":
		_controls.queue_redraw()

# ── public API ─────────────────────────────
func set_health(cur: float, max_hp: float) -> void:
	var f: float = clampf(cur / max(max_hp, 1.0), 0.0, 1.0)
	var w: float = _hp_bg.size.x - 4.0
	_hp_fill.size = Vector2(maxf(0.0, w * f), _hp_bg.size.y - 4.0)
	_hp_fill.color = DANGER if f < 0.3 else ACCENT
	_hp_label.text = "ARMOR  %d" % roundi(cur)

func set_ammo(cur: int, mag: int) -> void:
	_ammo_label.text = ("RELOADING..." if cur <= 0 else "AMMO  %d / %d" % [cur, mag])

func set_wave(n: int) -> void:
	_wave_label.text = "WAVE %d" % n

func set_hostiles(c: int) -> void:
	_hostiles_label.text = "HOSTILES  %d" % c

func set_score(s: int) -> void:
	_score_label.text = "SCORE  %d" % s

func flash_damage() -> void:
	_dmg_flash.color = Color(0.8, 0.0, 0.05, 0.0)
	var tw := _dmg_flash.create_tween()
	tw.tween_property(_dmg_flash, "color:a", 0.42, 0.04)
	tw.tween_property(_dmg_flash, "color:a", 0.0, 0.35)

func show_message(txt: String, sub := "") -> void:
	_msg_label.text = txt
	_msg_sub.text = sub
	_msg_label.modulate.a = 1.0
	_msg_sub.modulate.a = 1.0
	_msg_label.scale = Vector2(0.6, 0.6)
	var tw := _msg_label.create_tween()
	tw.tween_property(_msg_label, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func fade_message() -> void:
	var tw := _msg_label.create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(_msg_label, "modulate:a", 0.0, 0.5)
	var tw2 := _msg_sub.create_tween()
	tw2.tween_interval(0.6)
	tw2.tween_property(_msg_sub, "modulate:a", 0.0, 0.5)

func show_menu(top10: Array) -> void:
	_state = "menu"
	_menu.visible = true
	_over.visible = false
	_controls.visible = false
	_menu_board.text = _format_board(top10)

func start_play() -> void:
	_state = "play"
	_menu.visible = false
	_over.visible = false
	_controls.visible = true
	firing = false
	move_vector = Vector2.ZERO
	_joy_active = false
	_touches.clear()

func show_gameover(score: int, wave: int, kills: int, best: int, top10: Array) -> void:
	_state = "over"
	_controls.visible = false
	firing = false
	move_vector = Vector2.ZERO
	_over.visible = true
	_over_stats.text = "SCORE  %d        WAVE  %d        KILLS  %d\nBEST  %d" % [score, wave, kills, best]
	_over_board.text = _format_board(top10)

func update_board(top10: Array) -> void:
	_over_board.text = _format_board(top10)
	_menu_board.text = _format_board(top10)

# ── build ───────────────────────────────
func _build() -> void:
	_dmg_flash = ColorRect.new()
	_dmg_flash.color = Color(0.8, 0, 0.05, 0)
	_dmg_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dmg_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dmg_flash)

	_controls = Control.new()
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	_controls.draw.connect(_draw_controls)
	add_child(_controls)

	_hp_bg = ColorRect.new()
	_hp_bg.color = PANEL
	_hp_bg.size = Vector2(220, 26)
	add_child(_hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = ACCENT
	_hp_fill.position = Vector2(2, 2)
	_hp_bg.add_child(_hp_fill)
	_hp_label = _mk_label("ARMOR 100", 15, Color.WHITE)
	add_child(_hp_label)

	_wave_label = _mk_label("WAVE 1", 22, ACCENT)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_wave_label)
	_hostiles_label = _mk_label("HOSTILES 0", 14, Color(0.85, 0.9, 0.95))
	_hostiles_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hostiles_label)

	_score_label = _mk_label("SCORE 0", 18, Color.WHITE)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_score_label)

	_ammo_label = _mk_label("AMMO 30 / 30", 17, Color(0.95, 0.85, 0.5))
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_ammo_label)

	_msg_label = _mk_label("", 40, ACCENT)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.pivot_offset = Vector2(200, 30)
	add_child(_msg_label)
	_msg_sub = _mk_label("", 18, Color(0.9, 0.95, 1.0))
	_msg_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_msg_sub)

	_build_menu()
	_build_over()

func _mk_label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_menu() -> void:
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.07, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(bg)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 10)
	_menu.add_child(box)
	box.add_child(_center_label("OUTPOST VOSTOK", 46, ACCENT))
	box.add_child(_center_label("WAVE-SURVIVAL // FROZEN STATION", 18, Color(0.8, 0.88, 0.95)))
	box.add_child(_spacer(8))
	box.add_child(_center_label("TOP OPERATIVES", 16, Color(0.95, 0.85, 0.5)))
	_menu_board = _center_label("loading...", 17, Color.WHITE)
	box.add_child(_menu_board)
	box.add_child(_spacer(10))
	var deploy := _mk_button("DEPLOY")
	deploy.pressed.connect(func() -> void: start_pressed.emit())
	_deploy_btn = deploy
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(deploy)
	box.add_child(hb)
	box.add_child(_center_label("Move: stick / WASD   -   Fire: button / Space   -   Reload: R   -   Dodge: Shift   -   Drag right side to look", 13, Color(0.7, 0.78, 0.85)))

func _build_over() -> void:
	_over = Control.new()
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.visible = false
	add_child(_over)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.01, 0.02, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.add_child(bg)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 8)
	_over.add_child(box)
	box.add_child(_center_label("OUTPOST LOST", 44, DANGER))
	_over_stats = _center_label("", 18, Color.WHITE)
	box.add_child(_over_stats)
	box.add_child(_spacer(6))
	box.add_child(_center_label("LOG YOUR CALLSIGN", 15, Color(0.95, 0.85, 0.5)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_initials_edit = LineEdit.new()
	_initials_edit.text = "YOU"
	_initials_edit.max_length = 3
	_initials_edit.custom_minimum_size = Vector2(120, 44)
	_initials_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_initials_edit.add_theme_font_size_override("font_size", 22)
	row.add_child(_initials_edit)
	var submit := _mk_button("SUBMIT")
	submit.pressed.connect(_on_submit)
	_submit_btn = submit
	row.add_child(submit)
	box.add_child(row)
	box.add_child(_spacer(6))
	box.add_child(_center_label("TOP OPERATIVES", 15, Color(0.95, 0.85, 0.5)))
	_over_board = _center_label("", 17, Color.WHITE)
	box.add_child(_over_board)
	box.add_child(_spacer(8))
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var again := _mk_button("REDEPLOY")
	again.pressed.connect(func() -> void: restart_pressed.emit())
	_redeploy_btn = again
	hb.add_child(again)
	box.add_child(hb)

func _on_submit() -> void:
	var s := _initials_edit.text.strip_edges().to_upper()
	if s == "":
		s = "YOU"
	submit_pressed.emit(s)

func _center_label(txt: String, size: int, col: Color) -> Label:
	var l := _mk_label(txt, size, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return l

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _mk_button(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(180, 52)
	b.add_theme_font_size_override("font_size", 22)
	return b

func _format_board(rows: Array) -> String:
	if rows.is_empty():
		return "- no scores yet -"
	var out := ""
	var i := 1
	for r: Variant in rows:
		if r is Dictionary:
			var ini := str(r.get("initials", "???"))
			var sc := int(r.get("score", 0))
			var wv := int(r.get("wave", 0))
			out += "%2d.  %-3s   %6d   W%d\n" % [i, ini, sc, wv]
			i += 1
	return out.strip_edges()

# ── layout ──────────────────────────────
func _refresh_insets() -> void:
	if not OS.has_feature("web"):
		return
	var js := "(()=>{const d=document.createElement('div');d.style.cssText='position:fixed;top:env(safe-area-inset-top);bottom:env(safe-area-inset-bottom);left:env(safe-area-inset-left);right:env(safe-area-inset-right)';document.body.appendChild(d);const r=getComputedStyle(d);const o={top:parseFloat(r.top)||0,bottom:parseFloat(r.bottom)||0,left:parseFloat(r.left)||0,right:parseFloat(r.right)||0};d.remove();return JSON.stringify(o);})()"
	var raw: String = str(JavaScriptBridge.eval(js, true))
	if raw == "" or raw == "null":
		return
	var d: Variant = JSON.parse_string(raw)
	if d is Dictionary:
		_insets = d

func _relayout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var it: float = maxf(10.0, float(_insets.get("top", 0.0)))
	var il: float = maxf(14.0, float(_insets.get("left", 0.0)))
	var ir: float = maxf(14.0, float(_insets.get("right", 0.0)))
	_hp_bg.position = Vector2(il, it)
	_hp_bg.size = Vector2(minf(240.0, vs.x * 0.34), 26)
	_hp_fill.size = Vector2(_hp_fill.size.x, _hp_bg.size.y - 4)
	_hp_label.position = Vector2(il + 6, it + 2)
	_wave_label.position = Vector2(vs.x * 0.5 - 150, it - 2)
	_wave_label.size = Vector2(300, 30)
	_hostiles_label.position = Vector2(vs.x * 0.5 - 150, it + 28)
	_hostiles_label.size = Vector2(300, 20)
	_score_label.position = Vector2(vs.x - 260 - ir, it + 2)
	_score_label.size = Vector2(260, 26)
	_ammo_label.position = Vector2(vs.x * 0.5 - 150, vs.y - 40 - maxf(8.0, float(_insets.get("bottom", 0.0))))
	_ammo_label.size = Vector2(300, 26)
	_msg_label.position = Vector2(vs.x * 0.5 - 200, vs.y * 0.34)
	_msg_label.size = Vector2(400, 60)
	_msg_label.pivot_offset = Vector2(200, 30)
	_msg_sub.position = Vector2(vs.x * 0.5 - 200, vs.y * 0.34 + 56)
	_msg_sub.size = Vector2(400, 30)

# ── input (touch + desktop) ─────────────────────────────
func _input(event: InputEvent) -> void:
	if _state == "menu" or _state == "over":
		_menu_touch(event)
		return
	if _state != "play":
		return
	if event is InputEventScreenTouch:
		_touch_mode = true
		var e := event as InputEventScreenTouch
		if e.pressed:
			_press(e.index, e.position)
		else:
			_release(e.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_touch_mode = true
		var d := event as InputEventScreenDrag
		_move(d.index, d.position)
		get_viewport().set_input_as_handled()
	elif not _touch_mode and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_press(-1, mb.position)
			else:
				_release(-1)
	elif not _touch_mode and event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _touches.has(-1):
			_move(-1, mm.position)

func _menu_touch(event: InputEvent) -> void:
	# emulate_mouse_from_touch is off, so native Buttons don't press from a tap. Route
	# screen taps to the visible panel's controls by hit-testing their global rects.
	# (Desktop mouse still drives the native Buttons, so they aren't handled here.)
	if not (event is InputEventScreenTouch):
		return
	var e := event as InputEventScreenTouch
	if not e.pressed:
		return
	var p := e.position
	if _state == "menu":
		if _deploy_btn != null and _deploy_btn.get_global_rect().has_point(p):
			start_pressed.emit()
			get_viewport().set_input_as_handled()
	else:  # over
		if _initials_edit != null and _initials_edit.get_global_rect().has_point(p):
			_initials_edit.grab_focus()
			get_viewport().set_input_as_handled()
		elif _submit_btn != null and _submit_btn.get_global_rect().has_point(p):
			_on_submit()
			get_viewport().set_input_as_handled()
		elif _redeploy_btn != null and _redeploy_btn.get_global_rect().has_point(p):
			restart_pressed.emit()
			get_viewport().set_input_as_handled()

func _press(index: int, pos: Vector2) -> void:
	var vs := get_viewport().get_visible_rect().size
	if _circle_hit(pos, _fire_center(vs), _fire_r()):
		_touches[index] = "fire"
		firing = true
		return
	if _circle_hit(pos, _dodge_center(vs), 42.0):
		_touches[index] = "dodge"
		dodge_pressed.emit()
		return
	if _circle_hit(pos, _reload_center(vs), 42.0):
		_touches[index] = "reload"
		reload_pressed.emit()
		return
	if pos.x < vs.x * 0.5 and pos.y > vs.y * 0.22:
		_touches[index] = "joy"
		_joy_active = true
		_joy_origin = pos
		_joy_pos = pos
		_update_joy()
		return
	_touches[index] = "look"

func _move(index: int, pos: Vector2) -> void:
	if not _touches.has(index):
		return
	match _touches[index]:
		"joy":
			_joy_pos = pos
			_update_joy()
		"look":
			# delta tracked via stored last pos
			if _touches.has(str(index) + "_lp"):
				look_delta += pos - _touches[str(index) + "_lp"]
			_touches[str(index) + "_lp"] = pos

func _release(index: int) -> void:
	if _touches.has(index):
		match _touches[index]:
			"fire":
				firing = false
			"joy":
				_joy_active = false
				move_vector = Vector2.ZERO
		_touches.erase(index)
	_touches.erase(str(index) + "_lp")

func _update_joy() -> void:
	var off := _joy_pos - _joy_origin
	var r := 70.0
	if off.length() > r:
		off = off.normalized() * r
		_joy_pos = _joy_origin + off
	move_vector = Vector2(off.x / r, -off.y / r)

func _circle_hit(p: Vector2, c: Vector2, r: float) -> bool:
	return p.distance_to(c) <= r

func _fire_r() -> float:
	return 60.0

func _fire_center(vs: Vector2) -> Vector2:
	var ir: float = maxf(14.0, float(_insets.get("right", 0.0)))
	var ib: float = maxf(14.0, float(_insets.get("bottom", 0.0)))
	return Vector2(vs.x - 96 - ir, vs.y - 120 - ib)

func _dodge_center(vs: Vector2) -> Vector2:
	var c := _fire_center(vs)
	return Vector2(c.x, c.y - 140)

func _reload_center(vs: Vector2) -> Vector2:
	var c := _fire_center(vs)
	return Vector2(c.x - 130, c.y - 8)

# ── draw touch controls ─────────────────────────────
func _draw_controls() -> void:
	var vs := get_viewport().get_visible_rect().size
	var font := ThemeDB.fallback_font
	# joystick
	if _joy_active:
		_controls.draw_circle(_joy_origin, 70, Color(0.5, 0.7, 0.85, 0.16))
		_controls.draw_arc(_joy_origin, 70, 0, TAU, 40, Color(0.6, 0.85, 1.0, 0.5), 2.5, true)
		_controls.draw_circle(_joy_pos, 30, Color(0.55, 0.85, 1.0, 0.55))
	# fire
	var fc := _fire_center(vs)
	_controls.draw_circle(fc, _fire_r(), Color(1.0, 0.32, 0.27, 0.30 if firing else 0.20))
	_controls.draw_arc(fc, _fire_r(), 0, TAU, 48, DANGER, 3.0, true)
	_btn_text(font, fc, "FIRE")
	# dodge
	var dc := _dodge_center(vs)
	_controls.draw_circle(dc, 42, Color(0.4, 0.8, 1.0, 0.16))
	_controls.draw_arc(dc, 42, 0, TAU, 40, ACCENT, 2.4, true)
	_btn_text(font, dc, "DASH")
	# reload
	var rc := _reload_center(vs)
	_controls.draw_circle(rc, 42, Color(0.95, 0.85, 0.4, 0.14))
	_controls.draw_arc(rc, 42, 0, TAU, 40, Color(0.95, 0.85, 0.45), 2.4, true)
	_btn_text(font, rc, "RLD")

func _btn_text(font: Font, c: Vector2, t: String) -> void:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_controls.draw_string(font, c - Vector2(w * 0.5, -6), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.92))

func consume_look() -> Vector2:
	var d := look_delta
	look_delta = Vector2.ZERO
	return d
