extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if "--review-pair" in OS.get_cmdline_user_args():
		var output := []
		var args := ["--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/validate_full_run.gd", "--"]
		args.append_array(OS.get_cmdline_user_args())
		var status := OS.execute(OS.get_executable_path(), args, output, true)
		for line in output:
			print(line)
		quit(status)
		return
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/p25"
	main.seed_input.text = "restoration-fixture"
	var session := main.start_run() as RunSession
	var pier := session.get_node("Beach/PierBlockout") as Node3D
	var platform := pier.get_node("SyntyPlatform") as MultiMeshInstance3D
	var head_platform := pier.get_node("SyntyPierHeadPlatform") as MultiMeshInstance3D
	var support_poles := pier.get_node("SyntyPierPoles") as MultiMeshInstance3D
	var approach := pier.get_node("SyntyApproach") as MultiMeshInstance3D
	var rail := pier.get_node("SyntyRailing") as MultiMeshInstance3D
	var head_rail := pier.get_node("SyntyPierHeadRailing") as MultiMeshInstance3D
	var approach_rail := pier.get_node("SyntyApproachRailing") as MultiMeshInstance3D
	var tower := pier.get_node("SyntyLighthouse") as Node3D
	check(tower != null and platform.multimesh.mesh != null and platform.multimesh.instance_count == 72 and head_platform.multimesh.instance_count == 63 and support_poles.multimesh.instance_count == 12 and approach.multimesh.instance_count == 40 and rail.multimesh.instance_count == 24 and head_rail.multimesh.instance_count == 25 and approach_rail.multimesh.instance_count == 20, "shortened Synty pier and cafe head assemble in the playable beach")
	check(tower.find_children("RedBand*", "MeshInstance3D", false, false).size() == 3, "Synty lighthouse has reference-style painted bands")
	check(tower.global_position.distance_to(Vector3(72.5, 1.65, 95)) < 0.01 and pier.has_node("SyntyLighthouseIsland/Visual/Ridge") and pier.has_node("SyntyIslandPalm01/Visual/Palm") and pier.has_node("LighthouseIslandCollision/Collision"), "Synty lighthouse sits on a solid planted island offshore")
	check((pier.get_node("Deck/Collision") as CollisionShape3D).shape != null and (pier.get_node("PierHead/Collision") as CollisionShape3D).shape != null and (pier.get_node("PavilionCollision/Collision") as CollisionShape3D).shape != null and (pier.get_node("Lighthouse/Collision") as CollisionShape3D).shape != null, "pier head, pavilion and lighthouse remain solid")
	check(pier.has_node("PierAwning00") and pier.has_node("PierAwning09") and pier.has_node("PierLamp_-1_70") and pier.has_node("PierBench_1_65") and pier.has_node("PierUmbrella03") and pier.has_node("PierTable03") and pier.has_node("PierChair03_3"), "Synty cafe awnings and terrace furniture dress the pier head")
	check(pier.has_node("PierBench_1_65Collision/Collision") and pier.has_node("PierTable03Collision/Collision") and pier.has_node("PierChair03_3Collision/Collision"), "pier terrace furniture blocks the player")
	var beach := session.get_node("Beach") as Node3D
	await physics_frame
	var island_hit := beach.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(78.5, 5, 95), Vector3(78.5, -2, 95)))
	check(island_hit.get("collider") == pier.get_node("LighthouseIslandCollision"), "Synty island mesh provides a physical shore above the water")
	var water_faces := (beach.get_node("Water/SyntyWaterSurface") as MeshInstance3D).mesh.get_faces()
	check(water_faces.size() >= 3 and (water_faces[1] - water_faces[0]).cross(water_faces[2] - water_faces[0]).y < 0.0, "water faces the playable camera rather than being back-face culled")
	var water_material := (beach.get_node("Water/SyntyWaterSurface") as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
	check(water_material != null and water_material.shader != null and water_material.shader.resource_path.ends_with("shaders/beach_water.gdshader") and is_equal_approx(float(water_material.get_shader_parameter("facet_color_strength")), 0.6), "packed beach water uses its local faceted Synty-texture shader")
	check((beach.get_node("Terrain/CurvedSandSurface") as MeshInstance3D).mesh != null and not beach.has_node("Terrain/Sand01"), "single visible sand surface replaces obsolete sand boxes")
	check((beach.get_node("Terrain/CurvedSandSurface") as MeshInstance3D).mesh.get_aabb().size.z > 800.0 and not beach.has_node("Terrain/Seabed") and (beach.get_node("Terrain/CurvedSandCollision/Collision") as CollisionShape3D).shape != null, "rendered coast and playable seabed share one static collision surface")
	var coast_hit := beach.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(75, 5, 50), Vector3(75, -5, 50)))
	check(coast_hit.get("collider") == beach.get_node("Terrain/CurvedSandCollision") and not (beach.get_node("Water/SwimVolume") as WaterVolume).contains_horizontal(Vector3(75, 0, 50)) and (beach.get_node("Water/SwimVolume") as WaterVolume).contains_horizontal(Vector3(75, 0, 60)), "outer cove has solid dry sand and water begins at its visible edge")
	check(beach.get_node("ActivityAreas/VolleyballNet") != null and beach.get_node("ActivityAreas/LifeguardWest/Deck") != null and beach.get_node("Skyline/CityWest") != null, "Synty beach structures replace primitive landmarks")
	check(beach.has_node("ActivityAreas/Windsurf/Visual/Board") and beach.has_node("ActivityAreas/Windsurf/Visual/Sail"), "Synty windsurf board and sail dress the playable waterline")
	check(beach.has_node("ActivityAreas/SportsCafeSet/ChairNorth/Visual/Chair") and beach.has_node("ActivityAreas/LoungesCafeSetEast/Umbrella/Visual/Umbrella") and beach.has_node("ActivityAreas/SandplayCafeSet/Collision/ChairSouthShape"), "fixed beach cafe seating uses Synty table, chair and umbrella meshes with collision")
	check(beach.has_node("ActivityAreas/SportsShelter/SyntyShelter/Visual/Shelter") and beach.has_node("ActivityAreas/LoungesShelter/PostSW") and beach.has_node("ActivityAreas/SandplayShelter/PostNE"), "Synty beach shelters frame the cafes with post collision")
	check(beach.has_node("Skyline/BeachShopArrivalA") and beach.has_node("Skyline/BeachShopSportsB") and beach.has_node("Skyline/BeachShopLoungesC"), "Synty storefronts layer the main beach frontage")
	var backdrop := beach.get_node("CityBackdrop") as Node3D
	check((backdrop.get_node("SyntyCityFacades") as MultiMeshInstance3D).multimesh.instance_count > 20 and (backdrop.get_node("SyntyLowriseWindows") as MultiMeshInstance3D).multimesh.instance_count > 20 and (backdrop.get_node("SyntyDecoFacades") as MultiMeshInstance3D).multimesh.instance_count > 20 and (backdrop.get_node("SyntyVillaFacades") as MultiMeshInstance3D).multimesh.instance_count > 20 and backdrop.find_children("*", "CollisionObject3D", true, false).is_empty(), "varied Synty city glass/facades render as collision-free scenery")
	check(backdrop.has_node("SyntyCloudRing") and backdrop.has_node("SyntyCloudRingUpper"), "two staged Synty cloud rings layer the playable sky")
	check((backdrop.get_node("SyntyCityAwningsRed") as MultiMeshInstance3D).multimesh.instance_count > 8 and (backdrop.get_node("SyntyCityAwningsCream") as MultiMeshInstance3D).multimesh.instance_count > 8, "staged Synty art-deco awnings dress the city storefronts")
	check((backdrop.get_node("SyntyDecoBalconies") as MultiMeshInstance3D).multimesh.instance_count == 12 and backdrop.has_node("SyntyCityRoofCap"), "staged Synty balconies and roof cap break the decorative skyline")
	check((backdrop.get_node("SyntyRoadCurbs") as MultiMeshInstance3D).multimesh.instance_count == 128 and backdrop.has_node("SyntyPlanter05") and backdrop.has_node("SyntyBoulevardPalm10"), "compact Synty boulevard trim, planters and palms dress the inland edge")
	check((backdrop.get_node("SyntyPromenadePavers") as MultiMeshInstance3D).multimesh.instance_count == 320 and (beach.get_node("Promenade/Collision") as CollisionShape3D).shape != null, "staged Synty sidewalk tiles dress the unchanged playable promenade")
	var hut_roof := beach.get_node("ServicePoints/S1/Hut/Roof") as Node3D
	for service_id in ["S1", "S2", "S3"]:
		check(beach.has_node("ServicePoints/%s/Hut/SyntyFrontWest" % service_id) and beach.has_node("ServicePoints/%s/Hut/SyntyWindowWest" % service_id) and beach.has_node("ServicePoints/%s/Hut/SyntyCanopy03" % service_id) and beach.has_node("ServicePoints/%s/Hut/Roof/SyntyRoof" % service_id), "%s service hut uses Synty wall, window, awning and roof meshes" % service_id)
	hut_roof.hide()
	check(not (hut_roof.get_node("SyntyRoof") as Node3D).is_visible_in_tree(), "sorting table can hide the Synty roof")
	hut_roof.show()
	check(not beach.has_node("ActivityAreas/SportsCourt") and not beach.has_node("Boundaries/Rear/Mesh"), "unused primitive boxes are removed")
	var player := session.get_node("Player") as BeachPlayer
	player.global_position = Vector3(66, 2.6, 68)
	player.camera.look_at(Vector3(72.5, 16, 95))
	await physics_frame
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("P25-lighthouse-first.png")
	player.global_position = Vector3(62.5, 2.2, 87)
	player.camera.look_at(Vector3(62.5, 1.8, 64))
	await physics_frame
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("P25-dock-first.png")
	if "--capture" in OS.get_cmdline_user_args():
		await _view(player, Vector3(-70, 2, 9), Vector3(10, 2, 9), "P25-01-beachfront-before.png")
		await _view(player, Vector3(-15, 65, 135), Vector3(0, 0, 0), "P25-02-beach-layout-before.png")
		await _view(player, Vector3(36, 2.1, 21), Vector3(48, 0.7, 12), "P25-03-small-props-before.png")
		await _view(player, Vector3(-17, 2.1, 24), Vector3(-17, 1.7, -18), "P25-04-furniture-before.png")
		await _view(player, Vector3(-55, 3.3, 20), Vector3(-45, 4, -5), "P25-05-foliage-before.png")
		await _view(player, Vector3(30, -1.9, 111), Vector3(30, -2.6, 102), "P25-06-reef-before.png")
	if "--goal" in OS.get_cmdline_user_args():
		(main.get_node("UI") as CanvasLayer).visible = false
		(player.get_node("Head/Camera/HandRig") as Node3D).visible = false
		await _view(player, Vector3(-15, 65, 135), Vector3(0, 0, 0), "reference-aerial.png")
		await _view(player, Vector3(-70, 2, 9), Vector3(10, 2, 9), "reference-arrival.png")
		await _view(player, Vector3(5, 2.1, -33), Vector3(0, 12, -83), "reference-city-close.png", 30)
		await _view(player, Vector3(-37, 2.1, 28), Vector3(-27.5, 2.1, 46), "reference-windsurf-eye.png", 90)
		await _view(player, Vector3(-45, 2.1, 32), Vector3(-43.75, 1.7, 12), "reference-sports-eye.png", 90)
		await _view(player, Vector3(-17, 2.1, 24), Vector3(-17, 1.7, -18), "reference-lounges-eye.png", 90)
		await _view(player, Vector3(4, 15, 68), Vector3(0, 0, 0), "reference-beach-cluster.png")
		await _view(player, Vector3(66, 2.6, 68), Vector3(72.5, 16, 95), "reference-lighthouse.png")
		await _view(player, Vector3(62.5, 18, 75), Vector3(62.5, 2, 111), "reference-pier-head.png")
	player.global_position = Vector3(62.5, 2.2, 70)
	player.velocity = Vector3.ZERO
	player.look_at(Vector3(62.5, 2.2, 90))
	Input.action_press(&"move_forward")
	for frame in 240:
		await physics_frame
	Input.action_release(&"move_forward")
	check(player.global_position.z > 74.0 and player.global_position.z < 81.0 and player.global_position.y > 1.4, "player walks onto solid pier head and stops at Synty pavilion")
	check(session.state.validate_invariants(session.definitions).is_empty(), "art-only replacement leaves run ownership valid")
	main.free()
	print("P25_PIER lighthouse=1 tiles=135 rails=49 collision=1 failures=%d" % failures)
	quit(failures)


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://docs/handoffs/images/%s" % filename)
	check(root.get_texture().get_image().save_png(path) == OK, "capture %s" % filename)


func _view(player: BeachPlayer, origin: Vector3, target: Vector3, filename: String, settle_frames: int = 1) -> void:
	player.global_position = origin
	player.camera.look_at(target)
	for frame in settle_frames:
		await physics_frame
	await _capture(filename)


func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("P25 FAIL: " + label)
