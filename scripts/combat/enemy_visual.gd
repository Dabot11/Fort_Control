extends Node3D
## Imported, animated warrior. Health, path and rewards remain in FortEnemy.

const WARRIOR_SCENE: PackedScene = preload("res://assets/models/skeleton/warrior.glb")
const SWORD_SCENE: PackedScene = preload("res://assets/models/sword/shardblade.glb")
const MODEL_SCALE := 1.15 / 1.7
const WALK_REFERENCE_SPEED := 1.25

static var _materials: Dictionary = {}
var _body: Node3D
var _model: Node3D
var _animation_player: AnimationPlayer
var _skeleton: Skeleton3D
var _health_bar: Node3D
var _health_fill: MeshInstance3D
var _health_ratio := 1.0
var _hit_time := 0.0


func _ready() -> void:
	# Reactions affect this wrapper, never the animated bones or the health bar.
	_body = Node3D.new()
	_body.name = "HitReaction"
	add_child(_body)
	_model = WARRIOR_SCENE.instantiate() as Node3D
	_model.name = "WarriorModel"
	_model.scale = Vector3.ONE * MODEL_SCALE
	# The supplied warrior faces +Z. Gameplay consistently faces -Z.
	_model.rotation.y = PI
	_body.add_child(_model)
	_animation_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if is_instance_valid(_animation_player):
		# Only enemy locomotion advances the pose. Pausing the enemy pauses its gait.
		_animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var walk := _animation_player.get_animation("Walking")
		walk.loop_mode = Animation.LOOP_LINEAR
		_animation_player.play("Walking")
		_animation_player.advance(0.0)
	_attach_sword()
	_health_bar = Node3D.new()
	_health_bar.name = "HealthBar"
	_health_bar.position.y = 1.32
	add_child(_health_bar)
	_box(_health_bar, Vector3(0.49, 0.065, 0.045), Vector3.ZERO, Color("222d38"))
	_health_fill = _box(_health_bar, Vector3(0.43, 0.04, 0.055), Vector3.ZERO, Color("a2dc67"))
	_health_fill.name = "HealthFill"
	set_health_ratio(_health_ratio)


func _attach_sword() -> void:
	if not is_instance_valid(_skeleton):
		return
	var grip := BoneAttachment3D.new()
	grip.name = "SwordGrip"
	grip.bone_name = "mixamorig_RightHand"
	_skeleton.add_child(grip)
	var sword := SWORD_SCENE.instantiate() as Node3D
	sword.name = "Shardblade"
	# Original blade is along +Y with the grip below its centre. Place that grip
	# inside the palm; the blade points along the hand's +Z as the arm swings.
	sword.scale = Vector3.ONE * 0.75
	sword.rotation.x = PI * 0.5
	sword.position = Vector3(0.0, 0.09, 0.30)
	grip.add_child(sword)


func animate_walk(delta: float, speed: float) -> void:
	if not is_instance_valid(_animation_player) or delta <= 0.0 or speed <= 0.0:
		return
	# The source clip is already in-place. Keep its small hip sway, never apply
	# it to this node or to FortEnemy's world position.
	_animation_player.advance(delta * clampf(speed / WALK_REFERENCE_SPEED, 0.4, 2.0))


func show_hit() -> void:
	_hit_time = 0.15


func _process(delta: float) -> void:
	if _hit_time <= 0.0 or not is_instance_valid(_body):
		return
	_hit_time = maxf(0.0, _hit_time - delta)
	var strength := _hit_time / 0.15
	_body.scale = Vector3.ONE * (1.0 + strength * 0.08)
	_body.position.x = sin(strength * TAU) * strength * 0.035


func set_health_ratio(ratio: float) -> void:
	_health_ratio = clampf(ratio, 0.0, 1.0)
	if not is_instance_valid(_health_fill):
		return
	_health_fill.scale.x = maxf(0.001, _health_ratio)
	_health_fill.position.x = -0.215 * (1.0 - _health_ratio)
	_health_bar.visible = _health_ratio < 0.999 and _health_ratio > 0.0


func _box(parent: Node3D, size: Vector3, origin: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = origin
	instance.material_override = _material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.88
		_materials[key] = material
	return _materials[key]
