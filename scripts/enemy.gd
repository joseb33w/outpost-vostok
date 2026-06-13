class_name Enemy
extends CharacterBody3D

signal killed(enemy: Enemy, score: int)

const GRAVITY := 22.0

var kind := "infected"
var stats: Dictionary = {}
var hp := 40.0
var dead := false
var is_boss := false

var rig: MeshyCharacterRig
var _player: Player
var _audio: GameAudio
var _attack_cd_until := 0.0
var _attack_lands_at := -1.0
var _stagger_until := 0.0
var _burst_active := false
var _mats: Array[StandardMaterial3D] = []
var _flash_tween: Tween

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func setup(p_kind: String, hp_scale: float, player: Player, audio: GameAudio) -> void:
	kind = p_kind
	stats = CFG.ENEMIES[kind]
	hp = float(stats["hp"]) * hp_scale
	is_boss = kind == "reaver"
	_player = player
	_audio = audio
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var body_scale := float(stats["scale"])
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4 * body_scale
	capsule.height = 1.75 * body_scale
	shape.shape = capsule
	shape.position = Vector3(0, 0.9 * body_scale, 0)
	add_child(shape)
	rig = MeshyCharacterRig.new()
	rig.scale = Vector3.ONE * body_scale
	add_child(rig)
	var character: Node3D = load(str(stats["model"])).instantiate()
	if bool(stats["ranged"]):
		var weapon: Node3D = load(str(stats["weapon"])).instantiate()
		rig.setup(character, weapon, MeshyCharacterRig.ARMCANNON)
	else:
		rig.setup(character)
	_collect_materials(character)
	if not is_boss:
		var tint := Color(randf_range(0.82, 1.0), randf_range(0.82, 1.0), randf_range(0.82, 1.0))
		for m in _mats:
			m.albedo_color = m.albedo_color * tint
		rig.scale *= randf_range(0.93, 1.07)
	if rig.current_anim != null and rig.current_anim.has_animation("idle"):
		rig.current_anim.seek(randf() * rig.current_anim.get_animation("idle").length, true)
	_attack_cd_until = _now() + randf_range(0.6, 1.4)

func _collect_materials(root: Node3D) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in range(maxi(1, mi.mesh.get_surface_count())):
			var base: Material = mi.get_active_material(s)
			if base == null:
				continue
			var dup := base.duplicate() as StandardMaterial3D
			if dup == null:
				continue
			mi.set_surface_override_material(s, dup)
			_mats.append(dup)

func take_hit(dmg: float, from_pos: Vector3) -> bool:
	if dead:
		return false
	hp -= dmg
	_stagger_until = _now() + 0.18
	_hit_flash()
	_impact_burst(from_pos)
	_audio.play("impact", -6.0)
	if hp <= 0.0:
		_die()
		return true
	return false

func _hit_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	for m in _mats:
		m.emission_enabled = true
		m.emission = Color(1, 0.9, 0.8)
		m.emission_energy_multiplier = 1.6
	_flash_tween = create_tween()
	_flash_tween.tween_interval(0.09)
	_flash_tween.tween_callback(func() -> void:
		for m in _mats:
			m.emission_energy_multiplier = 0.0
			m.emission_enabled = false)

func _impact_burst(from_pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 14
	p.lifetime = 0.3
	p.explosiveness = 1.0
	p.spread = 70.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -8, 0)
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.1
	p.mesh = SphereMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.45, 0.2)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.5, 0.15)
	m.emission_energy_multiplier = 3.0
	p.material_override = m
	add_child(p)
	p.position = Vector3(0, 1.2 * float(stats["scale"]), 0)
	var dir := global_position - from_pos
	dir.y = 0
	if dir.length() > 0.01:
		p.direction = -dir.normalized()
	p.emitting = true
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())

func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 1
	rig.play("death")
	_audio.play("boss_roar" if is_boss else "enemy_die", 0.0 if is_boss else -4.0)
	killed.emit(self, int(stats["score"]))
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_callback(func() -> void:
		if is_instance_valid(self):
			queue_free())

func _physics_process(delta: float) -> void:
	if dead or _player == null or rig == null:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	var to_p := _player.global_position - global_position
	to_p.y = 0
	var dist := to_p.length()
	var dir := to_p.normalized() if dist > 0.01 else Vector3.ZERO
	if dir.length() > 0.01:
		rig.rotation.y = lerp_angle(rig.rotation.y, atan2(dir.x, dir.z), 0.18)
	var attack_range := float(stats["attack_range"])
	var attacking := _attack_lands_at >= 0.0 or _burst_active
	var moving := false
	if _player.dead:
		velocity.x = move_toward(velocity.x, 0, 30 * delta)
		velocity.z = move_toward(velocity.z, 0, 30 * delta)
	elif attacking or _now() < _stagger_until:
		velocity.x = move_toward(velocity.x, 0, 30 * delta)
		velocity.z = move_toward(velocity.z, 0, 30 * delta)
	elif dist > attack_range:
		var spd := float(stats["speed"])
		velocity.x = move_toward(velocity.x, dir.x * spd, 25 * delta)
		velocity.z = move_toward(velocity.z, dir.z * spd, 25 * delta)
		moving = true
	else:
		velocity.x = move_toward(velocity.x, 0, 30 * delta)
		velocity.z = move_toward(velocity.z, 0, 30 * delta)
		if _now() >= _attack_cd_until:
			_start_attack(dist)
	move_and_slide()
	_resolve_attack(dist)
	_update_anim(moving)

func _start_attack(_dist: float) -> void:
	_attack_cd_until = _now() + float(stats["attack_cd"])
	if bool(stats["ranged"]):
		_fire_burst()
	else:
		rig.play("fire")
		_attack_lands_at = _now() + 0.45

func _resolve_attack(dist: float) -> void:
	if _attack_lands_at >= 0.0 and _now() >= _attack_lands_at:
		_attack_lands_at = -1.0
		if not _player.dead and dist <= float(stats["attack_range"]) + 0.6:
			_player.take_damage(float(stats["dmg"]), false)

func _fire_burst() -> void:
	_burst_active = true
	rig.fire()
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void:
		if dead or _player == null or _player.dead:
			return
		var to_p := _player.global_position - global_position
		if to_p.length() <= float(stats["attack_range"]) + 4.0 and randf() < 0.7:
			_player.take_damage(float(stats["dmg"]), true))
	tw.tween_interval(0.45)
	tw.tween_callback(func() -> void:
		if dead or _player == null or _player.dead:
			return
		var to_p := _player.global_position - global_position
		if to_p.length() <= float(stats["attack_range"]) + 4.0 and randf() < 0.55:
			_player.take_damage(float(stats["dmg"]), true))
	tw.tween_interval(0.4)
	tw.tween_callback(func() -> void:
		_burst_active = false)

func _update_anim(moving: bool) -> void:
	if dead:
		return
	var clip := "idle"
	if _attack_lands_at >= 0.0 or _burst_active:
		clip = "fire"
	elif _now() < _stagger_until:
		clip = "hit"
	elif moving:
		clip = "run" if float(stats["speed"]) > 4.0 else "walk"
	if rig.current_clip != clip:
		rig.play(clip)
