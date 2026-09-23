extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.seed_input.text = "release-pack-smoke"
	var run := main.start_run() as RunSession
	if run == null or run.state.items.size() != 5740 or run.definitions.size() != 34:
		push_error("P29 packed new run failed: %s" % main.error_label.text)
		quit(1)
		return
	var bottle := load("res://art/synty/POLYGON_Palm_City/meshes/tscn_separate/SM_Prop_Drink_Bottle_01.tscn") as PackedScene
	var rolled_towel := load("res://art/synty/POLYGON_Palm_City/meshes/tscn_separate/SM_Prop_Towel_02.tscn") as PackedScene
	var tent_scene := load("res://art/replacements/world/portable_tent.tscn") as PackedScene
	var tent := tent_scene.instantiate() as Node3D if tent_scene != null else null
	var tent_ok := tent != null and tent.has_node("SyntyShelter/Visual/Shelter") and (tent.get_node("SyntyShelter/Visual/Shelter") as MeshInstance3D).mesh != null
	if tent != null:
		tent.free()
	var player := run.get_node("Player") as BeachPlayer
	if bottle == null or rolled_towel == null or not tent_ok or run.item_view_manager.views.is_empty() or player.hand_rig.tool_socket.get_child_count() != 1 or not player.hand_rig.tool_socket.get_child(0).has_node("Visual/Shaft"):
		push_error("P29 packed visuals or nearby world items failed")
		main.free()
		quit(1)
		return
	for _frame in range(120):
		await physics_frame
	if run.progress_service.completed_props != 0 or run.state.revision != 0:
		push_error("P29 packed new run completed props without player input")
		main.free()
		quit(1)
		return
	print("P29_PACK new_run=5740 catalog=34 nearby_views=%d initial_progress=0 synty_bottle=loaded rolled_towel=loaded shelter=loaded stick_shaft=loaded" % run.item_view_manager.views.size())
	main.free()
	quit()
