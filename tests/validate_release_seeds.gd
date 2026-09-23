extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var generator := ManifestGenerator.new()
	var seeds := ["", "Côte, \"Azure\" 🌊", "x".repeat(64), "release-repeat"]
	for index in 96:
		seeds.append("release-%03d" % index)
	var hashes := {}
	for seed_text in seeds:
		var result := generator.generate(seed_text)
		if not bool(result.get("ok", false)) or (result.rows as Array).size() != 5740:
			push_error("P29 seed failed: %s — %s" % [seed_text, result.get("error", "wrong row count")])
			quit(1)
			return
		hashes[result.manifest_hash] = true
	var repeat := generator.generate("release-repeat")
	var original := generator.generate("release-repeat")
	var invalid_long := generator.generate("é".repeat(33))
	var invalid_control := generator.generate("bad\nseed")
	if hashes.size() != 100 or repeat.manifest_hash != original.manifest_hash or invalid_long.ok or invalid_control.ok:
		push_error("P29 distinct/repeated/invalid seed contract failed")
		quit(1)
		return
	print("P29_SEEDS valid=100 distinct=100 rows=5740 repeated=stable long=reject control=reject")
	quit()
