extends SceneTree


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	var seed_text := arguments[0] if not arguments.is_empty() else "manifest-fixture-v1"
	var generator := ManifestGenerator.new()
	var result := generator.generate(seed_text)
	if not result.ok:
		push_error("MANIFEST_PROBE_ERROR %s" % " | ".join(result.errors))
		quit(1)
		return
	var stream := generator.derive_stream(
		"Côte, \"Azure\" 🌊", "reef_west:coral", "buried", str(result.content_hash)
	)
	print("MANIFEST_PROBE %s %s %s %d" % [result.seed, result.manifest_hash, result.content_hash, result.rows.size()])
	print("STREAM_GOLDEN %s %s %d" % [stream.canonical, stream.hash, stream.rng_seed])
	quit()
