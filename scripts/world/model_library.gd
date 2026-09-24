class_name ModelLibrary
extends RefCounted
## Shared access to the project's low-poly model meshes (art/models, built by
## tools/blender/build_models.py) for scripts that assemble visuals in code.

static var _meshes: Dictionary = {}


static func mesh(path: String) -> Mesh:
	if not _meshes.has(path):
		var root := (load(path) as PackedScene).instantiate()
		var source := root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		_meshes[path] = source.mesh
		root.free()
	return _meshes[path] as Mesh
