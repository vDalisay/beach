extends SceneTree
## Writes data/world/beach_layout.tres (level pads, litter obstacles and mess sources) from the
## authored beach scene. Run after moving a hut, palm, pool or activity:
##
##   godot --headless --path . -s res://tools/bake_beach_layout.gd
##
## The layout is part of the manifest content hash, so re-baking after a scene edit changes
## generated layouts: bump the content version when it does.

const CONTENT_VERSION := "beach-content-9"


func _init() -> void:
	call_deferred("_bake")


func _bake() -> void:
	var beach := (load("res://scenes/world/beach.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(beach)
	await process_frame
	var layout := BeachLayoutBaker.collect(beach)
	var resource := Resource.new()
	resource.resource_name = "beach_01_layout"
	resource.set_meta(&"content_version", CONTENT_VERSION)
	for key in ["pads", "obstacles", "sources"]:
		resource.set_meta(StringName(key), layout[key])
	var error := ResourceSaver.save(resource, BeachLayoutBaker.LAYOUT_PATH)
	print("bake_beach_layout: %d pads, %d obstacles, %d sources -> %s (%s)" % [
		(layout.pads as Array).size(), (layout.obstacles as Array).size(), (layout.sources as Array).size(),
		BeachLayoutBaker.LAYOUT_PATH, error_string(error)])
	beach.queue_free()
	await process_frame
	quit(0 if error == OK else 1)
