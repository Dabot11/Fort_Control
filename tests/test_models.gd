extends SceneTree
## Imported art must preserve combat transforms, resource sharing and pause behavior.

const EnemyScript := preload("res://scripts/combat/enemy.gd")
const TowerScript := preload("res://scripts/combat/tower.gd")
const ProjectileScript := preload("res://scripts/combat/projectile.gd")
const MODEL_BUDGETS := {
	"res://assets/models/skeleton/warrior.glb": {"texture": 1024, "triangles": 3000},
	"res://assets/models/sword/shardblade.glb": {"texture": 512, "triangles": 1000},
	"res://assets/models/tower/crossbow.glb": {"texture": 1024, "triangles": 20000},
	"res://assets/models/arrow/crystal_arrow.glb": {"texture": 256, "triangles": 1000},
}

var _checks := 0
var _failures := 0
var _sandbox: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("MODEL CHECK FAILED: " + description)


func _run() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func():
		push_error("Imported model verification timed out before reporting completion.")
		quit(124)
	)
	_sandbox = Node3D.new()
	_sandbox.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(_sandbox)
	_test_imported_resources()
	await _test_skeleton_animation()
	_test_tower_aim_and_upgrades()
	_test_projectile_visual()
	paused = false
	_sandbox.free()
	await process_frame
	print("MODEL TESTS: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_imported_resources() -> void:
	for path: String in MODEL_BUDGETS:
		var packed := load(path) as PackedScene
		_check(packed != null, "Imported GLB is a playable scene: " + path)
		if packed == null:
			continue
		var model := packed.instantiate() as Node3D
		var second := packed.instantiate() as Node3D
		_sandbox.add_child(model)
		_sandbox.add_child(second)
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		var other_meshes := second.find_children("*", "MeshInstance3D", true, false)
		_check(not meshes.is_empty(), "Imported model contains mesh geometry: " + path)
		var textured := not meshes.is_empty()
		var within_texture_budget := true
		var shared := meshes.size() == other_meshes.size()
		var triangles := 0
		for index in range(meshes.size()):
			var mesh_instance := meshes[index] as MeshInstance3D
			var mesh := mesh_instance.mesh
			textured = textured and mesh is ArrayMesh
			if index < other_meshes.size():
				shared = shared and mesh == (other_meshes[index] as MeshInstance3D).mesh
			for surface in range(mesh.get_surface_count()):
				var arrays := mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				triangles += indices.size() / 3 if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size() / 3
				var material := mesh_instance.get_active_material(surface) as BaseMaterial3D
				textured = textured and material != null and material.get_texture(BaseMaterial3D.TEXTURE_ALBEDO) != null
				if material == null:
					continue
				if index < other_meshes.size():
					shared = shared and material == (other_meshes[index] as MeshInstance3D).get_active_material(surface)
				for channel in [BaseMaterial3D.TEXTURE_ALBEDO, BaseMaterial3D.TEXTURE_NORMAL, BaseMaterial3D.TEXTURE_ROUGHNESS, BaseMaterial3D.TEXTURE_METALLIC]:
					var texture := material.get_texture(channel)
					if texture != null:
						within_texture_budget = within_texture_budget and maxi(texture.get_width(), texture.get_height()) <= int(MODEL_BUDGETS[path].texture)
		_check(textured, "Real mesh surfaces retain textured materials: " + path)
		_check(within_texture_budget, "Texture dimensions respect the mobile asset budget: " + path)
		_check(triangles > 0 and triangles <= int(MODEL_BUDGETS[path].triangles), "Geometry respects the mobile asset budget: " + path)
		_check(shared, "Repeated instances share meshes and materials: " + path)
		_check(model.find_children("*", "CollisionObject3D", true, false).is_empty(), "Imported art cannot intercept selection or alter movement: " + path)
		model.free()
		second.free()


func _test_skeleton_animation() -> void:
	var enemy := EnemyScript.new() as FortEnemy
	enemy.configure([Vector3.ZERO, Vector3(0, 0, -20)], {"health": 48.0, "speed": 1.25}, 25, 1)
	_sandbox.add_child(enemy)
	enemy.set_physics_process(false)
	var visual := enemy.visual
	var players := visual.find_children("*", "AnimationPlayer", true, false)
	var rigs := visual.find_children("*", "Skeleton3D", true, false)
	_check(players.size() == 1 and rigs.size() == 1, "Enemy uses the imported animation player and skeleton")
	if players.is_empty() or rigs.is_empty():
		enemy.free()
		return
	var player := players[0] as AnimationPlayer
	var rig := rigs[0] as Skeleton3D
	_check(rig.get_bone_count() > 10, "Enemy retains a skeletal rig rather than a static placeholder")
	var attachments := rig.find_children("*", "BoneAttachment3D", true, false)
	_check(attachments.size() == 1 and (attachments[0] as BoneAttachment3D).get_bone_idx() >= 0, "Sword is attached to a real character bone")
	var parent_before := enemy.global_transform
	var visual_before := visual.transform
	var poses: Array[Transform3D] = []
	for index in range(rig.get_bone_count()):
		poses.append(rig.get_bone_pose(index))
	visual.call("animate_walk", 0.23, enemy.speed)
	var pose_changed := false
	for index in range(rig.get_bone_count()):
		pose_changed = pose_changed or not rig.get_bone_pose(index).is_equal_approx(poses[index])
	_check(pose_changed, "Walking advances the character's actual bone poses")
	_check(player.is_playing() and player.current_animation.to_lower().contains("walk"), "Locomotion uses the supplied walking animation")
	if player.has_animation(player.current_animation):
		_check(player.get_animation(player.current_animation).loop_mode == Animation.LOOP_LINEAR, "Walking repeats continuously between path points")
	for index in range(100):
		visual.call("animate_walk", 0.1, enemy.speed)
	_check(enemy.global_transform.is_equal_approx(parent_before) and visual.transform.is_equal_approx(visual_before), "Repeated animation cannot apply root motion to the gameplay transform")
	var health_before := enemy.health
	visual.call("show_hit")
	visual.call("_process", 0.04)
	_check(enemy.health == health_before and enemy.global_transform.is_equal_approx(parent_before), "Hit presentation cannot move or damage the logical enemy")
	visual.call("set_health_ratio", 0.5)
	var health_bar := visual.get("_health_bar") as Node3D
	var body := visual.get("_body") as Node3D
	_check(health_bar != null and health_bar.visible and not body.is_ancestor_of(health_bar), "Damaged enemy shows a health bar independent of hit and walking transforms")
	visual.call("_process", 1.0)
	enemy.set_physics_process(true)
	await create_timer(0.08).timeout
	paused = true
	var position_before_pause := enemy.global_transform
	var animation_before_pause := player.current_animation_position
	await create_timer(0.08, true, false, true).timeout
	_check(enemy.global_transform.is_equal_approx(position_before_pause), "Pausing stops enemy movement with the imported visual")
	_check(is_equal_approx(player.current_animation_position, animation_before_pause), "Pausing freezes the walking animation")
	paused = false
	await create_timer(0.08).timeout
	_check(not enemy.global_transform.is_equal_approx(position_before_pause), "Enemy resumes movement after pause")
	_check(not is_equal_approx(player.current_animation_position, animation_before_pause), "Walking resumes with gameplay")
	enemy.free()


func _test_tower_aim_and_upgrades() -> void:
	var tower := TowerScript.new() as FortTower
	_sandbox.add_child(tower)
	tower.set_physics_process(false)
	tower.position = Vector3(3.0, 0.0, 4.0)
	var visual := tower.visual
	var base := visual.get("_base") as Node3D
	var head := visual.get("_head") as Node3D
	_check(base != null and head != null, "Imported tower separates fixed base and aiming head")
	if base == null or head == null:
		tower.free()
		return
	var base_before := base.global_transform
	for direction in [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]:
		visual.call("aim_at", tower.global_position + direction * 10.0)
		var forward := -head.global_basis.z.normalized()
		_check(forward.dot(direction) > 0.99, "Tower head aims at targets from each side of the board")
		var muzzle: Vector3 = visual.call("muzzle_position")
		var horizontal_offset := muzzle - head.global_position
		horizontal_offset.y = 0.0
		_check(horizontal_offset.dot(direction) > 0.1, "Projectile spawns in front of the aimed crossbow")
	_check(base.global_transform.is_equal_approx(base_before), "Aiming leaves the imported stone base fixed")
	var head_before := head.transform
	visual.call("play_recoil")
	visual.call("_process", 0.08)
	_check(not head.transform.is_equal_approx(head_before) and base.global_transform.is_equal_approx(base_before), "Firing animates the crossbow without recoiling the base")
	visual.call("_process", 1.0)
	_check(head.transform.is_equal_approx(head_before), "Recoil returns the head to its resting transform")
	for level in [2, 3]:
		visual.call("set_level", level)
		head = visual.get("_head") as Node3D
		_check((-head.global_basis.z.normalized()).dot(Vector3.LEFT) > 0.99, "Tower upgrade preserves its aiming direction")
		var muzzle: Vector3 = visual.call("muzzle_position")
		_check(muzzle.y > tower.global_position.y + 0.5 and muzzle.distance_to(tower.global_position) < 2.5, "Upgraded tower keeps a valid elevated muzzle within its model")
	_check(visual.find_children("*", "CollisionObject3D", true, false).is_empty(), "Tower appearance keeps selection collisions on the build slot")
	tower.free()


func _test_projectile_visual() -> void:
	var first := ProjectileScript.new() as FortProjectile
	var second := ProjectileScript.new() as FortProjectile
	_sandbox.add_child(first)
	_sandbox.add_child(second)
	first.set_physics_process(false)
	second.set_physics_process(false)
	var meshes := first.find_children("*", "MeshInstance3D", true, false)
	var second_meshes := second.find_children("*", "MeshInstance3D", true, false)
	_check(not meshes.is_empty() and meshes.size() == second_meshes.size(), "Live projectiles instantiate the supplied crystal arrow")
	var bounds := _model_bounds(first)
	_check(bounds.size.z > 0.45 and bounds.size.z < 0.8 and bounds.size.z > maxf(bounds.size.x, bounds.size.y) * 3.0, "Arrow fits the board scale and flies along its long Z axis")
	var shared := not meshes.is_empty()
	for index in range(mini(meshes.size(), second_meshes.size())):
		var mesh := meshes[index] as MeshInstance3D
		var other := second_meshes[index] as MeshInstance3D
		shared = shared and mesh.mesh == other.mesh and mesh.get_active_material(0) == other.get_active_material(0)
	_check(shared, "Concurrent projectiles share meshes and textured materials")
	_check(first.find_children("*", "CollisionObject3D", true, false).is_empty(), "Arrow art does not introduce physical collisions")
	first.free()
	second.free()


func _model_bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var relative := node.global_transform.affine_inverse() * mesh.global_transform
		var bounds := relative * mesh.get_aabb()
		result = bounds if first else result.merge(bounds)
		first = false
	return result
