class_name Player
extends CharacterBody3D
## Spec-ops soldier: camera-relative movement, auto-aim hitscan rifle (burst fire
## with recoil/flash/tracer via the rig), reload, dodge roll with i-frames.

signal health_changed(cur: float, max_hp: float)
signal ammo_changed(cur: int, mag: int)
signal died()

const GRAVITY := 22.0

var dead := false
var max_hp := 100.0
var hp := 100.0
var ammo := 30
var reloading := false

# Per-frame input, written by Main:
var move_dir := Vector3.ZERO        # world-space, length 0..1
var want_fire := false

var rig: MeshyCharacterRig
var _audio: GameAudio
var _main: Node = null

var _facing_y := 0.0
var _burst_active := false
var _next_burst := 0.0
var _dodging := false
var _dodge_until := 0.0
var _iframe_until := 0.0
var _dodge_cd_until := 0.0
var _dodge_dir := Vector3.ZERO

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func setup(audio: GameAudio, main: Node) -> void:
	_audio = audio
	_main = main
	max_hp = float(CFG.PLAYER["hp"])
	hp = max_hp
	ammo = int(CFG.PLAYER["mag"])
	collision_layer = 2                # player
	collision_mask = 1                 # collide with world only
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)
	rig = MeshyCharacterRig.new()
	add_child(rig)
	var character: Node3D = load(str(CFG.PLAYER["model"])).instantiate()
	var weapon: Node3D = load(str(CFG.PLAYER["weapon"])).instantiate()
	rig.setup(character, weapon, MeshyCharacterRig.RIFLE)
	health_changed.emit(hp, max_hp)
	ammo_changed.emit(ammo, int(CFG.PLAYER["mag"]))

func _physics_process(delta: float) -> void:
	if rig == null:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	if dead:
		velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 40.0 * delta)
		move_and_slide()
		return

	var t: float = _now()
	var target: Node = _nearest_target()
	var firing: bool = want_fire and ammo > 0 and not reloading

	# ── movement ──
	if _dodging:
		if t >= _dodge_until:
			_dodging = false
		else:
			velocity.x = _dodge_dir.x * float(CFG.PLAYER["dodge_speed"])
			velocity.z = _dodge_dir.z * float(CFG.PLAYER["dodge_speed"])
	if not _dodging:
		var spd: float = float(CFG.PLAYER["fire_speed"]) if firing else float(CFG.PLAYER["speed"])
		var wish := move_dir
		if wish.length() > 1.0:
			wish = wish.normalized()
		velocity.x = move_toward(velocity.x, wish.x * spd, 60.0 * delta)
		velocity.z = move_toward(velocity.z, wish.z * spd, 60.0 * delta)

	# ── facing ──
	var desired := _facing_y
	if _dodging and _dodge_dir.length() > 0.1:
		desired = atan2(_dodge_dir.x, _dodge_dir.z)
	elif firing and target != null:
		var d: Vector3 = (target as Node3D).global_position - global_position
		desired = atan2(d.x, d.z)
	elif move_dir.length() > 0.12:
		desired = atan2(move_dir.x, move_dir.z)
	elif target != null:
		var d2: Vector3 = (target as Node3D).global_position - global_position
		desired = atan2(d2.x, d2.z)
	_facing_y = lerp_angle(_facing_y, desired, 1.0 - exp(-delta * 16.0))
	rig.rotation.y = _facing_y

	# ── firing ──
	if firing and not _burst_active and t >= _next_burst:
		_burst()
	elif want_fire and ammo <= 0 and not reloading:
		do_reload()

	move_and_slide()
	_update_anim(firing)

func _update_anim(firing: bool) -> void:
	if dead:
		return
	if _dodging:
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	var loco := "idle"
	if planar > 4.2:
		loco = "run"
	elif planar > 0.5:
		loco = "walk"
	# Always feed the lower body so the legs keep stepping — even while the upper body
	# holds the aim/fire/reload pose (walk/run blends UNDER the IK aim).
	rig.set_locomotion(loco)
	if reloading or firing or _burst_active:
		rig.set_aiming(true)   # hold ADS; legs follow set_locomotion above
		return
	if rig.aiming:
		rig.set_aiming(false)
	if rig.current_clip != loco:
		rig.play(loco)

func _burst() -> void:
	_burst_active = true
	_next_burst = _now() + float(CFG.PLAYER["burst_cd"])
	if rig != null:
		rig.fire()
	_audio.play("shot_rifle", -2.0)
	var rounds: int = int(CFG.PLAYER["burst"])
	var gap: float = float(CFG.PLAYER["round_gap"])
	var dmg: float = float(CFG.PLAYER["dmg"])
	for _r in rounds:
		if dead or reloading:
			break
		if ammo <= 0:
			break
		ammo -= 1
		ammo_changed.emit(ammo, int(CFG.PLAYER["mag"]))
		var tgt: Node = _nearest_target()
		if tgt != null and _los_clear(tgt as Node3D):
			tgt.call("take_hit", dmg, _muzzle_pos())
		await get_tree().create_timer(gap).timeout
		if not is_inside_tree() or dead:
			_burst_active = false
			return
	_burst_active = false
	if ammo <= 0 and not reloading:
		do_reload()

func do_reload() -> void:
	if reloading or dead or ammo == int(CFG.PLAYER["mag"]):
		return
	reloading = true
	if rig != null:
		rig.reload()
	_audio.play("reload", -3.0)
	await get_tree().create_timer(float(CFG.PLAYER["reload_time"])).timeout
	if not is_inside_tree() or dead:
		reloading = false
		return
	ammo = int(CFG.PLAYER["mag"])
	ammo_changed.emit(ammo, int(CFG.PLAYER["mag"]))
	reloading = false

func do_dodge() -> void:
	var t: float = _now()
	if dead or _dodging or t < _dodge_cd_until:
		return
	_dodging = true
	_dodge_until = t + float(CFG.PLAYER["dodge_time"])
	_iframe_until = t + float(CFG.PLAYER["dodge_iframe"])
	_dodge_cd_until = t + float(CFG.PLAYER["dodge_cd"])
	_dodge_dir = move_dir
	if _dodge_dir.length() < 0.1:
		_dodge_dir = Vector3(sin(_facing_y), 0, cos(_facing_y))
	_dodge_dir = _dodge_dir.normalized()
	if rig != null:
		rig.play("dodge")
	_audio.play("dodge", -4.0)

func take_damage(amount: float, _ranged: bool) -> void:
	if dead or _now() < _iframe_until:
		return
	hp -= amount
	health_changed.emit(max(hp, 0.0), max_hp)
	_audio.play("hurt", -2.0)
	if _main != null and _main.has_method("on_player_hurt"):
		_main.call("on_player_hurt", amount)
	if hp <= 0.0:
		_die()

func _die() -> void:
	dead = true
	if rig != null:
		rig.play("death")
	died.emit()

func _nearest_target() -> Node:
	if _main != null and _main.has_method("nearest_enemy"):
		return _main.call("nearest_enemy", global_position, float(CFG.PLAYER["range"]))
	return null

func _los_clear(tgt: Node3D) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 1.4
	var to := tgt.global_position + Vector3.UP * 1.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)  # world layer only
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	return hit.is_empty()

func _muzzle_pos() -> Vector3:
	if rig != null and rig.muzzle != null:
		return rig.muzzle.global_position
	return global_position + Vector3.UP * 1.3 + Vector3(sin(_facing_y), 0, cos(_facing_y))
