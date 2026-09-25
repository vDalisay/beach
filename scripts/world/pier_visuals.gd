extends Node3D

const LIGHTHOUSE := preload("res://art/synty/wrappers/world_lighthouse.tscn")
const PLATFORM := preload("res://art/synty/wrappers/world_dock_platform.tscn")
const RAILING := preload("res://art/synty/wrappers/world_dock_railing.tscn")
const POLE := preload("res://art/synty/wrappers/world_pier_pole.tscn")
const AWNING := preload("res://art/synty/wrappers/world_pier_awning.tscn")
const LAMP := preload("res://art/synty/wrappers/world_pier_lamp.tscn")
const BENCH := preload("res://art/synty/wrappers/world_pier_bench.tscn")
const UMBRELLA := preload("res://art/synty/wrappers/world_pier_umbrella.tscn")
const TABLE := preload("res://art/synty/wrappers/world_pier_table.tscn")
const CHAIR := preload("res://art/synty/wrappers/world_pier_chair.tscn")
const SAND_RIDGE := preload("res://art/synty/wrappers/world_reef_ridge.tscn")
const SAND_PILE := preload("res://art/synty/wrappers/world_sand_pile.tscn")


func _ready() -> void:
	var tower := LIGHTHOUSE.instantiate() as Node3D
	tower.name = "SyntyLighthouse"
	add_child(tower)
	tower.position = Vector3(260, 1.65, 95)
	_add_lighthouse_bands(tower)
	var island := SAND_RIDGE.instantiate() as Node3D
	island.name = "SyntyLighthouseIsland"
	island.position = Vector3(260, -0.4, 95)
	island.scale = Vector3(2, 5, 6)
	_tint_island_sand(island, "Ridge")
	add_child(island)
	for index in 2:
		var pile := SAND_PILE.instantiate() as Node3D
		pile.name = "SyntyIslandDune%02d" % index
		pile.position = Vector3(255 if index == 0 else 266, 0, 93 if index == 0 else 99)
		pile.scale = Vector3(4, 6, 4)
		_tint_island_sand(pile, "Pile")
		add_child(pile)
	for index in 2:
		var palm := FoliageVariants.instance_palm(index * 2, 0.8 if index == 0 else 0.65)
		palm.name = "SyntyIslandPalm%02d" % index
		palm.position = Vector3(254 if index == 0 else 268, 1.5, 95 if index == 0 else 92)
		palm.rotation.y = 0.7 if index == 0 else -1.1
		add_child(palm)
	var island_shape := ConvexPolygonShape3D.new()
	var island_vertices := PackedVector3Array()
	for vertex in (island.get_node("Visual/Ridge") as MeshInstance3D).mesh.get_faces():
		island_vertices.append(island.transform * vertex)
	island_shape.points = island_vertices
	_add_solid("LighthouseIsland", Vector3.ZERO, island_shape)
	_add_modules(PLATFORM, "Platform", 72, func(index: int) -> Transform3D:
		return Transform3D(Basis.IDENTITY, Vector3(245 + (index % 4) * 2.5, 1.25, 37 + (index / 4) * 2.5))
	)
	# The head is 18 m wide like its collision; the outer column is stretched to 3 m to reach it.
	_add_modules(PLATFORM, "Platform", 63, func(index: int) -> Transform3D:
		var basis := Basis.from_scale(Vector3(1.2, 1, 1)) if index % 7 == 6 else Basis.IDENTITY
		return Transform3D(basis, Vector3(241 + (index % 7) * 2.5, 1.25, 67 + (index / 7) * 2.5))
	, "PierHeadPlatform")
	_add_modules(POLE, "Pole", 12, func(index: int) -> Transform3D:
		var x := (246.5 if index % 2 == 0 else 253.5) if index < 8 else (243.0 if index % 2 == 0 else 257.0)
		var z := 45.0 + float(index / 2) * 10.0 if index < 8 else 74.0 + float((index - 8) / 2) * 15.0
		return Transform3D(Basis.IDENTITY.scaled(Vector3(1, 1.3, 1)), Vector3(x, -3.4, z))
	, "PierPoles")
	_add_modules(PLATFORM, "Platform", 40, func(index: int) -> Transform3D:
		var z := 13.0 + float(index / 4) * 2.5
		return Transform3D(Basis(Vector3.RIGHT, -0.05), Vector3(245 + (index % 4) * 2.5, -0.08 + 0.05 * (z - 13.0), z))
	, "Approach")
	# A railing module runs 2.5 m along its local +X with its posts toward local -Z, so each side is
	# yawed to run along its deck edge with the posts inboard. Sides yawed +90° run toward -Z.
	_add_modules(RAILING, "Railing", 24, func(index: int) -> Transform3D:
		if index < 12:
			return Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(245, 1.45, 37 + index * 2.5))
		return Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(255, 1.45, 67 - (index - 12) * 2.5))
	)
	# Head sides, the far end (stretched to the 18 m head) and the two corners where the head widens.
	_add_modules(RAILING, "Railing", 29, func(index: int) -> Transform3D:
		if index < 9:
			return Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(241, 1.45, 67 + index * 2.5))
		if index < 18:
			return Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(259, 1.45, 89.5 - (index - 9) * 2.5))
		if index < 25:
			return Transform3D(Basis.from_scale(Vector3(18.0 / 17.5, 1, 1)), Vector3(241 + (index - 18) * 18.0 / 7.0, 1.45, 89.5))
		var corner: float = [243.0, 245.0, 257.0, 259.0][index - 25]
		return Transform3D(Basis(Vector3.UP, PI) * Basis.from_scale(Vector3(0.8, 1, 1)), Vector3(corner, 1.45, 67))
	, "PierHeadRailing")
	# Approach sides: ten 2.4 m modules from the sand (z = 13) to the deck (z = 37), sheared so their
	# rails follow the 5 % slope while the posts stay upright.
	_add_modules(RAILING, "Railing", 20, func(index: int) -> Transform3D:
		var left := index < 10
		var z := 13.0 + 2.4 * float(index % 10 if left else index % 10 + 1)
		var slope := 0.05 if left else -0.05
		var along := Basis(Vector3(0.96, 0.96 * slope, 0), Vector3.UP, Vector3.BACK)
		var yaw := -PI / 2.0 if left else PI / 2.0
		return Transform3D(Basis(Vector3.UP, yaw) * along, Vector3(245 if left else 255, 0.2 + 0.05 * (z - 13.0), z))
	, "ApproachRailing")
	var awning_red := StandardMaterial3D.new()
	awning_red.albedo_color = Color(0.79, 0.14, 0.11)
	awning_red.roughness = 0.9
	var awning_cream := StandardMaterial3D.new()
	awning_cream.albedo_color = Color(1.0, 0.93, 0.77)
	awning_cream.roughness = 0.9
	var lamp_shape := CylinderShape3D.new()
	lamp_shape.radius = 0.2
	lamp_shape.height = 4.2
	var bench_shape := BoxShape3D.new()
	bench_shape.size = Vector3(1.5, 0.8, 0.4)
	var table_shape := CylinderShape3D.new()
	table_shape.radius = 0.75
	table_shape.height = 0.8
	var chair_shape := BoxShape3D.new()
	chair_shape.size = Vector3(0.6, 0.96, 0.6)
	for index in 10:
		var awning := AWNING.instantiate() as Node3D
		awning.name = "PierAwning%02d" % index
		awning.position = Vector3(256.25 - index * 1.25, 4.8, 78.35)
		awning.rotation.y = PI
		awning.scale.x = 0.5
		(awning.get_node("Visual/Awning") as MeshInstance3D).material_override = awning_red if index % 2 == 0 else awning_cream
		add_child(awning)
	var sign_board := MeshInstance3D.new()
	sign_board.name = "PierCafeSignBoard"
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(5.8, 0.95, 0.12)
	sign_board.mesh = board_mesh
	sign_board.position = Vector3(250, 6.4, 79.55)
	var board_finish := StandardMaterial3D.new()
	board_finish.albedo_color = Color(0.95, 0.86, 0.68)
	board_finish.roughness = 0.9
	sign_board.material_override = board_finish
	sign_board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sign_board)
	var sign_text := Label3D.new()
	sign_text.name = "PierCafeSign"
	sign_text.position = Vector3(250, 6.4, 79.47)
	sign_text.rotation.y = PI
	sign_text.text = "PIER CAFÉ"
	sign_text.font_size = 64
	sign_text.pixel_size = 0.01
	sign_text.modulate = Color(0.13, 0.28, 0.3)
	sign_text.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sign_text)
	for side in [-1, 1]:
		for z in [70.0, 87.0]:
			var lamp := LAMP.instantiate() as Node3D
			lamp.name = "PierLamp_%d_%d" % [side, int(z)]
			lamp.position = Vector3(250 + side * 8.5, 1.45, z)
			add_child(lamp)
			_add_solid(lamp.name, lamp.position + Vector3(0, 2.1, 0), lamp_shape)
		for z in [55.0, 65.0]:
			var bench := BENCH.instantiate() as Node3D
			bench.name = "PierBench_%d_%d" % [side, int(z)]
			bench.position = Vector3(250 + side * 3.3, 1.45, z)
			bench.rotation.y = -PI / 2.0 if side < 0 else PI / 2.0
			add_child(bench)
			_add_solid(bench.name, bench.position + Vector3(0, 0.4, 0), bench_shape, bench.rotation.y)
	var terrace_centers := [Vector2(243, 75), Vector2(257, 75), Vector2(243, 87), Vector2(257, 87)]
	var chair_offsets := [Vector2(-1.45, 0), Vector2(1.45, 0), Vector2(0, -1.6), Vector2(0, 1.6)]
	for terrace_index in terrace_centers.size():
		var center: Vector2 = terrace_centers[terrace_index]
		var umbrella := UMBRELLA.instantiate() as Node3D
		umbrella.name = "PierUmbrella%02d" % terrace_index
		umbrella.position = Vector3(center.x, 1.45, center.y)
		add_child(umbrella)
		var table := TABLE.instantiate() as Node3D
		table.name = "PierTable%02d" % terrace_index
		table.position = umbrella.position
		add_child(table)
		_add_solid(table.name, table.position + Vector3(0, 0.4, 0), table_shape)
		for chair_index in chair_offsets.size():
			var offset: Vector2 = chair_offsets[chair_index]
			var chair := CHAIR.instantiate() as Node3D
			chair.name = "PierChair%02d_%d" % [terrace_index, chair_index]
			chair.position = Vector3(center.x + offset.x, 1.45, center.y + offset.y)
			chair.rotation.y = chair_index * PI / 2.0
			add_child(chair)
			_add_solid(chair.name, chair.position + Vector3(0, 0.48, 0), chair_shape, chair.rotation.y)


func _add_solid(prop_name: String, origin: Vector3, shape: Shape3D, yaw: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.name = "%sCollision" % prop_name
	body.position = origin
	body.rotation.y = yaw
	add_child(body)
	var collider := CollisionShape3D.new()
	collider.name = "Collision"
	collider.shape = shape
	body.add_child(collider)


func _tint_island_sand(wrapper: Node3D, mesh_name: String) -> void:
	var source := wrapper.get_node("Visual/%s" % mesh_name) as MeshInstance3D
	var sand := source.get_surface_override_material(0).duplicate() as ShaderMaterial
	sand.set_shader_parameter("color_tint", Color(0.85, 0.7, 0.48))
	source.set_surface_override_material(0, sand)


func _add_lighthouse_bands(tower: Node3D) -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.45, 0.08, 0.07)
	paint.roughness = 0.88
	var bands := [[6.0, 3.55, 3.3], [13.5, 3.1, 2.9], [20.5, 2.6, 2.45]]
	for index in bands.size():
		var band: Array = bands[index]
		var stripe := MeshInstance3D.new()
		stripe.name = "RedBand%02d" % index
		var ring := CylinderMesh.new()
		ring.height = 2.6
		ring.bottom_radius = float(band[1])
		ring.top_radius = float(band[2])
		ring.cap_top = false
		ring.cap_bottom = false
		stripe.mesh = ring
		stripe.material_override = paint
		stripe.position.y = float(band[0])
		tower.add_child(stripe)


func _add_modules(scene: PackedScene, component_name: String, count: int, pose: Callable, visual_name: String = "") -> void:
	var wrapper := scene.instantiate() as Node3D
	var source := wrapper.get_node("Visual/%s" % component_name) as MeshInstance3D
	var mesh := source.mesh.duplicate() as ArrayMesh
	for surface in mesh.get_surface_count():
		var material := source.get_surface_override_material(surface)
		if material != null:
			mesh.surface_set_material(surface, material)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = count
	for index in count:
		instances.set_instance_transform(index, pose.call(index))
	var visual := MultiMeshInstance3D.new()
	visual.name = "Synty%s" % (visual_name if not visual_name.is_empty() else component_name)
	visual.multimesh = instances
	visual.material_override = source.material_override
	add_child(visual)
	wrapper.free()
