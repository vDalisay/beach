extends Node3D


func _ready() -> void:
	var wall_material: StandardMaterial3D
	var canopy_teal := StandardMaterial3D.new()
	canopy_teal.albedo_color = Color(0.08, 0.42, 0.47)
	canopy_teal.roughness = 0.9
	var canopy_cream := StandardMaterial3D.new()
	canopy_cream.albedo_color = Color(0.95, 0.83, 0.58)
	canopy_cream.roughness = 0.9
	for child in get_children():
		if not child.name.begins_with("Synty"):
			continue
		if child.name.begins_with("SyntyCanopy"):
			var awning := child.get_node("Visual/Awning") as MeshInstance3D
			awning.material_override = canopy_teal if int(str(child.name).right(2)) % 2 == 0 else canopy_cream
			continue
		var panel := child.get_node_or_null("Visual/Wall") as MeshInstance3D
		if panel == null:
			continue
		if wall_material == null:
			wall_material = (panel.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
			wall_material.emission_enabled = false
			wall_material.vertex_color_use_as_albedo = true
			wall_material.albedo_color = Color(0.68, 0.54, 0.38)
		panel.set_surface_override_material(0, wall_material)
