class_name SaveService
extends Node

signal saved(slot_id: StringName, sequence: int)
signal save_failed(slot_id: StringName, message: String)

const FORMAT_SCHEMA := 1
const MAX_FILE_BYTES := 32 * 1024 * 1024
const MAX_ID_LENGTH := 64
const AUTOSAVE_INTERVAL := 60.0
const MANIFEST_CACHE_LIMIT := 4

# Manifest generation is deterministic for a seed and this build's content, so validation reuses one
# result per seed for the life of the process instead of regenerating it (about 1 s) for every
# generation file it checks. Entries also keep the derived canonical manifest and row index.
static var _manifests: Dictionary = {}
static var _content_hash_value := ""
# Folder -> {file name -> [modified time, size, read ok, valid, sequence]} for generation files this
# process already read, validated or wrote. Unchanged files are not parsed and validated again.
static var _known_generations: Dictionary = {}
# Save path -> [modified time and size, listing summary] for the title and pause menus.
static var _summaries: Dictionary = {}
static var _cache_lock := Mutex.new()

var save_root := "user://saves"
var beach_id: StringName
var session: RunSession
var player: BeachPlayer
var _last_autosave_seconds := 0.0
var _autosave_pending := false
# Autosaves are built, serialised, written and verified on a worker thread; the main thread only
# copies the run's values. A request made while one is in flight writes the newest state afterwards.
var _autosave_task := -1
var _autosave_job: Dictionary = {}
var _autosave_run_id := ""
var _autosave_again := false


func configure(run_session: RunSession, player_body: BeachPlayer, loaded_beach_id: StringName) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = run_session
	player = player_body
	beach_id = loaded_beach_id
	_last_autosave_seconds = session.state.elapsed_active_seconds
	session.wallet_changed.connect(func(_id: StringName) -> void: request_autosave())
	session.section_restored.connect(func(_id: StringName) -> void: request_autosave())
	session.run_completed.connect(func(_receipt: Dictionary) -> void: request_autosave())
	session.collection_service.receipt_created.connect(func(_receipt: Dictionary) -> void: request_autosave())
	session.swim_service.faint_completed.connect(func(_receipt: Dictionary) -> void: request_autosave())
	# Resources load here on the main thread, so background autosaves never need to.
	_content_hash()
	set_process(true)


func _process(_delta: float) -> void:
	if _autosave_task != -1 and WorkerThreadPool.is_task_completed(_autosave_task):
		_finish_autosave()
	if session != null and not get_tree().paused and session.state.elapsed_active_seconds - _last_autosave_seconds >= AUTOSAVE_INTERVAL:
		request_autosave()


func request_autosave() -> void:
	if session == null or _autosave_pending:
		return
	_autosave_pending = true
	call_deferred("_write_pending_autosave")


func _write_pending_autosave() -> void:
	if not _autosave_pending or not is_instance_valid(session):
		return
	_autosave_pending = false
	_last_autosave_seconds = session.state.elapsed_active_seconds
	if _autosave_task != -1:
		_autosave_again = true
		return
	if session == null or player == null:
		return
	# The worker builds the snapshot from this copy (copying takes a few milliseconds; building the
	# snapshot here took 70-100 ms on the full beach) and validates the written snapshot's full
	# state before publishing it, so an invalid run still never replaces the previous generation.
	_synchronize_world()
	_autosave_job = {"beach_id": beach_id, "run_id": session.state.run_id, "capture": session.state.capture_for_snapshot(), "result": {}}
	_autosave_run_id = session.state.run_id
	_autosave_task = WorkerThreadPool.add_task(_run_autosave_job.bind(_autosave_job), false, "Beach autosave")


func _run_autosave_job(job: Dictionary) -> void:
	var snapshot := RunState.snapshot_from_capture(job.capture as Dictionary)
	# The copy is released here, on the worker, rather than when the main thread clears the job.
	job.erase("capture")
	job.result = write_snapshot(StringName(job.beach_id), str(job.run_id), &"autosave", snapshot)


func _notification(what: int) -> void:
	# The worker still calls into this object: let an in-flight autosave finish (it publishes
	# atomically) before the object goes away, including when the game quits.
	if what == NOTIFICATION_PREDELETE and _autosave_task != -1:
		WorkerThreadPool.wait_for_task_completion(_autosave_task)
		_autosave_task = -1


## Waits for an in-flight background autosave and reports it; loads and listings call this first so
## they always see the newest autosave.
func wait_for_autosave() -> void:
	_finish_autosave()


func _finish_autosave() -> void:
	if _autosave_task == -1:
		return
	# Every task is waited on exactly once; this blocks only if the write is still running.
	WorkerThreadPool.wait_for_task_completion(_autosave_task)
	_autosave_task = -1
	var result := _autosave_job.get("result", {}) as Dictionary
	_autosave_job = {}
	# A run that ended or was replaced meanwhile gets no feedback for its old autosave.
	if session != null and session.state.run_id == _autosave_run_id:
		if bool(result.get("ok", false)):
			saved.emit(&"autosave", int(result.sequence))
		else:
			save_failed.emit(&"autosave", str(result.get("message", "Autosave failed")))
	if _autosave_again:
		_autosave_again = false
		request_autosave()


func save_slot(slot_id: StringName) -> Dictionary:
	if session == null or player == null:
		return {"ok": false, "message": "No active beach run"}
	var snapshot := capture_snapshot()
	var errors := session.state.validate_invariants(session.definitions)
	if not errors.is_empty():
		var message := "Run state cannot be saved: %s" % errors[0]
		save_failed.emit(slot_id, message)
		return {"ok": false, "message": message}
	var result := write_snapshot(beach_id, session.state.run_id, slot_id, snapshot)
	if bool(result.ok):
		saved.emit(slot_id, int(result.sequence))
	else:
		save_failed.emit(slot_id, str(result.message))
	return result


func capture_snapshot() -> Dictionary:
	_synchronize_world()
	return session.state.to_snapshot()


## Copies the live physics poses (item and bag views, the player) into their records.
func _synchronize_world() -> void:
	if session.item_view_manager != null:
		for item_id in session.item_view_manager.views:
			var item := session.state.items.get(item_id) as ItemRecord
			if item != null and item.location == ItemRecord.Location.WORLD:
				(session.item_view_manager.views[item_id] as WorldItem).synchronize_record()
	for bag_id in session.state.bag_records:
		var bag := session.state.bag_records[bag_id] as Dictionary
		if str(bag.get("location", "")) != "WORLD":
			continue
		var station := session.sorting_stations.get(StringName(str(bag.get("station_id", "")))) as SortingStation
		var view := station.bag_view_for(StringName(bag_id)) if station != null else null
		if view != null:
			view.synchronize_record()
	var record := session.state.players[&"local"] as Dictionary
	record.transform = player.global_transform
	record.velocity = player.velocity


func write_snapshot(target_beach: StringName, run_id: String, slot_id: StringName, snapshot: Dictionary) -> Dictionary:
	if not _valid_id(str(target_beach)) or not _valid_id(run_id) or not _valid_id(str(slot_id)):
		return {"ok": false, "message": "Invalid save ID"}
	if not save_root.begins_with("user://"):
		return {"ok": false, "message": "Save root must be under user data"}
	var folder := _slot_folder(target_beach, run_id, slot_id)
	var folder_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if folder_error != OK:
		return {"ok": false, "message": "Could not create save folder (%d)" % folder_error}
	var a := _generation_status(folder, "A.json", run_id)
	var b := _generation_status(folder, "B.json", run_id)
	var a_valid := bool(a.read) and bool(a.valid)
	var b_valid := bool(b.read) and bool(b.valid)
	var sequence := maxi(int(a.sequence) if bool(a.read) else 0, int(b.sequence) if bool(b.read) else 0) + 1
	var target := "A.json" if not a_valid or (b_valid and int(a.sequence) <= int(b.sequence)) else "B.json"
	var content_hash := _content_hash()
	var body := {"sequence": sequence, "schema": FORMAT_SCHEMA, "content_hash": content_hash, "saved_at": int(Time.get_unix_time_from_system()), "payload": _canonical(snapshot)}
	var envelope := body.duplicate(true)
	envelope["checksum"] = _generation_checksum(body)
	var temporary := folder.path_join(target + ".tmp")
	var destination := folder.path_join(target)
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Could not write save file (%d)" % FileAccess.get_open_error()}
	file.store_string(_canonical(envelope))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return {"ok": false, "message": "Save write failed (%d); previous generation retained" % write_error}
	var verified := _read_generation(temporary)
	if not bool(verified.get("ok", false)) or int(verified.sequence) != sequence:
		return {"ok": false, "message": "New save failed verification; previous generation retained"}
	var checked := _validate_generation(verified.envelope as Dictionary, run_id)
	if not bool(checked.get("ok", false)):
		return {"ok": false, "message": "New save failed verification: %s; previous generation retained" % str(checked.message)}
	var source_path := ProjectSettings.globalize_path(temporary)
	var target_path := ProjectSettings.globalize_path(destination)
	var rename_error := DirAccess.rename_absolute(source_path, target_path)
	if rename_error != OK and FileAccess.file_exists(destination):
		var remove_error := DirAccess.remove_absolute(target_path)
		if remove_error == OK:
			rename_error = DirAccess.rename_absolute(source_path, target_path)
	if rename_error != OK:
		return {"ok": false, "message": "Could not publish save (%d); previous generation retained" % rename_error}
	# The file just written was fully verified above; later saves and menus need not parse it again.
	var stamp := _file_stamp(destination)
	_remember_generation(folder, target, stamp, {"read": true, "valid": true, "sequence": sequence})
	var progress := _progress_summary(snapshot)
	_cache_lock.lock()
	_summaries[destination] = [stamp, {"ok": true, "sequence": sequence, "saved_at": float(body.saved_at), "seed": str(snapshot.get("seed_text", "")), "completed": progress.completed, "required": progress.required}]
	_cache_lock.unlock()
	return {"ok": true, "sequence": sequence, "slot_id": str(slot_id), "saved_at": body.saved_at}


## Whether a generation file parses (read) and validates for this run, and its sequence. A file
## this process already checked or wrote is not parsed again while its size and time match.
func _generation_status(folder: String, file_name: String, run_id: String) -> Dictionary:
	var path := folder.path_join(file_name)
	var stamp := _file_stamp(path)
	_cache_lock.lock()
	var known: Variant = (_known_generations.get(folder, {}) as Dictionary).get(file_name)
	_cache_lock.unlock()
	if known is Array and (known as Array)[0] == stamp:
		return (known as Array)[1] as Dictionary
	var generation := _read_generation(path)
	var read := bool(generation.get("ok", false))
	var status := {
		"read": read,
		"valid": read and bool(_validate_generation(generation.envelope as Dictionary, run_id).get("ok", false)),
		"sequence": int(generation.get("sequence", 0)),
	}
	_remember_generation(folder, file_name, stamp, status)
	return status


func _remember_generation(folder: String, file_name: String, stamp: Array, status: Dictionary) -> void:
	_cache_lock.lock()
	if not _known_generations.has(folder):
		_known_generations[folder] = {}
	(_known_generations[folder] as Dictionary)[file_name] = [stamp, status]
	_cache_lock.unlock()


static func _file_stamp(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return [0, -1]
	var file := FileAccess.open(path, FileAccess.READ)
	var length := file.get_length() if file != null else -1
	if file != null:
		file.close()
	return [FileAccess.get_modified_time(path), length]


func load_slot(target_beach: StringName, run_id: String, slot_id: StringName) -> Dictionary:
	if not _valid_id(str(target_beach)) or not _valid_id(run_id) or not _valid_id(str(slot_id)):
		return {"ok": false, "message": "Invalid save ID"}
	wait_for_autosave()
	var folder := _slot_folder(target_beach, run_id, slot_id)
	var candidates := [_read_generation(folder.path_join("A.json")), _read_generation(folder.path_join("B.json"))]
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("sequence", 0)) > int(b.get("sequence", 0)))
	var latest_error := "No valid save generation; files were left untouched"
	for index in candidates.size():
		var candidate := candidates[index] as Dictionary
		if not bool(candidate.get("ok", false)):
			continue
		var checked := _validate_generation(candidate.envelope as Dictionary, run_id)
		if bool(checked.get("ok", false)):
			checked["sequence"] = int(candidate.sequence)
			checked["notice"] = "Recovered an earlier valid save generation" if FileAccess.file_exists(folder.path_join("A.json")) and FileAccess.file_exists(folder.path_join("B.json")) and (index > 0 or not bool(candidates[1].get("ok", false))) else ""
			return checked
		latest_error = str(checked.message)
	return {"ok": false, "message": latest_error}


func _validate_generation(envelope: Dictionary, run_id: String) -> Dictionary:
	var payload := envelope.payload as Dictionary
	if int(envelope.schema) != FORMAT_SCHEMA or int(payload.get("schema_version", -1)) != FORMAT_SCHEMA:
		return {"ok": false, "message": "Incompatible save schema"}
	if str(payload.get("run_id", "")) != run_id or str(payload.get("seed_text", "")).to_utf8_buffer().size() > 64:
		return {"ok": false, "message": "Save identity or seed is invalid"}
	var manifest := _manifest_for(str(payload.seed_text))
	var generated := manifest.generated as Dictionary
	if not bool(generated.ok) or str(envelope.content_hash) != str(generated.content_hash) or str(payload.get("initial_manifest_hash", "")) != str(generated.manifest_hash):
		return {"ok": false, "message": "Save content is incompatible with this beach build"}
	var shape_error := _validate_payload_shape(payload, manifest)
	if not shape_error.is_empty():
		return {"ok": false, "message": shape_error}
	var state := RunState.from_snapshot(payload)
	var errors := state.validate_invariants(generated.definitions as Dictionary)
	if not errors.is_empty():
		return {"ok": false, "message": "Saved run failed validation: %s" % errors[0]}
	return {"ok": true, "state": state, "definitions": generated.definitions, "saved_at": float(envelope.saved_at)}


## The manifest generated for a seed with its canonical text and row index, built once per process.
## Returns {"generated": ...} alone when generation fails.
func _manifest_for(seed_text: String) -> Dictionary:
	_cache_lock.lock()
	var cached: Variant = _manifests.get(seed_text)
	var entry := (cached as Dictionary).duplicate() if cached != null else {}
	_cache_lock.unlock()
	if entry.is_empty():
		var generated := ManifestGenerator.new().generate(seed_text)
		if not bool(generated.get("ok", false)):
			return {"generated": generated}
		remember_manifest(generated)
		entry = {"generated": generated}
	if not entry.has("expected"):
		var generated_rows := (entry.generated as Dictionary).rows as Array
		var expected := {}
		for row in generated_rows:
			expected[str((row as Dictionary).id)] = row
		entry["canonical_rows"] = _canonical(JSON.parse_string(_canonical(generated_rows)))
		entry["expected"] = expected
		_cache_lock.lock()
		if _manifests.has(seed_text):
			_manifests[seed_text] = entry.duplicate()
		_cache_lock.unlock()
	return entry


## Keeps a run's freshly generated manifest so saving it never regenerates the same seed.
static func remember_manifest(generated: Dictionary) -> void:
	if not bool(generated.get("ok", false)):
		return
	_cache_lock.lock()
	if not _manifests.has(str(generated.seed)):
		if _manifests.size() >= MANIFEST_CACHE_LIMIT:
			_manifests.clear()
		_manifests[str(generated.seed)] = {"generated": generated}
	_cache_lock.unlock()


func list_slots(target_beach: StringName) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not _valid_id(str(target_beach)):
		return entries
	wait_for_autosave()
	var root_folder := save_root.path_join(str(target_beach))
	var directory := DirAccess.open(root_folder)
	if directory == null:
		return entries
	for run_id in directory.get_directories():
		if not _valid_id(run_id):
			continue
		var run_directory := DirAccess.open(root_folder.path_join(run_id))
		if run_directory == null:
			continue
		for slot_name in run_directory.get_directories():
			if not _valid_id(slot_name):
				continue
			var selected := _select_generation(_slot_folder(target_beach, run_id, StringName(slot_name)))
			if not bool(selected.get("ok", false)):
				entries.append({"beach_id": str(target_beach), "run_id": run_id, "slot_id": slot_name, "seed": "Unknown seed", "saved_at": 0.0, "sequence": 0, "damaged": true})
				continue
			var summary := selected.summary as Dictionary
			entries.append({"beach_id": str(target_beach), "run_id": run_id, "slot_id": slot_name, "seed": str(summary.seed), "saved_at": float(summary.saved_at), "sequence": int(summary.sequence), "completed": summary.completed, "required": summary.required, "damaged": false})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.run_id) > str(b.run_id) if int(a.saved_at) == int(b.saved_at) else int(a.saved_at) > int(b.saved_at)
	)
	return entries


func checkpoint_summaries() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for slot_id in [&"manual", &"manual_2", &"manual_3"]:
		var selected := _select_generation(_slot_folder(beach_id, session.state.run_id, slot_id))
		if not bool(selected.get("ok", false)):
			summaries.append({})
			continue
		var summary := selected.summary as Dictionary
		summaries.append({"saved_at": int(summary.saved_at), "completed": summary.completed, "required": summary.required})
	return summaries


func _progress_summary(payload: Dictionary) -> Dictionary:
	var completed := 0
	for section_value in (payload.get("section_states", {}) as Dictionary).values():
		var section := section_value as Dictionary
		completed += int(section.get("collected_waste", 0)) + int(section.get("slotted_props", 0))
	return {"completed": completed, "required": int(payload.get("required_total", 0))}


func _select_generation(folder: String) -> Dictionary:
	var a := _generation_summary(folder.path_join("A.json"))
	var b := _generation_summary(folder.path_join("B.json"))
	var a_valid := bool(a.get("ok", false))
	var b_valid := bool(b.get("ok", false))
	if not a_valid and not b_valid:
		return {"ok": false, "message": "No valid save generation; files were left untouched" if FileAccess.file_exists(folder.path_join("A.json")) or FileAccess.file_exists(folder.path_join("B.json")) else "No save in this slot"}
	var chosen := a if a_valid and (not b_valid or int(a.sequence) >= int(b.sequence)) else b
	var notice := "Recovered an earlier valid save generation" if (a_valid != b_valid and (FileAccess.file_exists(folder.path_join("A.json")) and FileAccess.file_exists(folder.path_join("B.json")))) else ""
	return {"ok": true, "summary": chosen, "notice": notice}


## A generation file's listing details (parse and checksum only, like the listing always used),
## kept while the file's size and time are unchanged so menus do not re-parse multi-megabyte saves.
func _generation_summary(path: String) -> Dictionary:
	var stamp := _file_stamp(path)
	_cache_lock.lock()
	var known: Variant = _summaries.get(path)
	_cache_lock.unlock()
	if known is Array and (known as Array)[0] == stamp:
		return (known as Array)[1] as Dictionary
	var generation := _read_generation(path)
	var summary := {"ok": false}
	if bool(generation.get("ok", false)):
		var envelope := generation.envelope as Dictionary
		var payload := envelope.payload as Dictionary
		var progress := _progress_summary(payload)
		summary = {"ok": true, "sequence": int(envelope.sequence), "saved_at": float(envelope.saved_at), "seed": str(payload.get("seed_text", "")), "completed": progress.completed, "required": progress.required}
	_cache_lock.lock()
	_summaries[path] = [stamp, summary]
	_cache_lock.unlock()
	return summary


func _read_generation(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false}
	var length := file.get_length()
	if length <= 0 or length > MAX_FILE_BYTES:
		file.close()
		return {"ok": false}
	var raw := file.get_buffer(length).get_string_from_utf8()
	file.close()
	var decoder := JSON.new()
	if decoder.parse(raw) != OK:
		return {"ok": false}
	var parsed: Variant = decoder.data
	if parsed is not Dictionary:
		return {"ok": false}
	var envelope := parsed as Dictionary
	if not envelope.has("checksum") or not envelope.has("payload") or envelope.payload is not String or not envelope.has("sequence") or not envelope.has("schema") or not envelope.has("content_hash") or not envelope.has("saved_at"):
		return {"ok": false}
	var checksum := str(envelope.checksum)
	if checksum.length() != 64 or _generation_checksum(envelope) != checksum or int(envelope.sequence) < 1:
		return {"ok": false}
	if decoder.parse(envelope.payload) != OK:
		return {"ok": false}
	var payload: Variant = decoder.data
	if payload is not Dictionary:
		return {"ok": false}
	envelope.payload = payload
	return {"ok": true, "sequence": int(envelope.sequence), "envelope": envelope}


func _generation_checksum(body: Dictionary) -> String:
	return ("%d\n%d\n%s\n%d\n%s" % [int(body.sequence), int(body.schema), str(body.content_hash), int(body.saved_at), str(body.payload)]).sha256_text()


func _validate_payload_shape(payload: Dictionary, manifest: Dictionary) -> String:
	var generated := manifest.generated as Dictionary
	if not _bounded_value(payload, 0):
		return "Save contains oversized, non-finite or deeply nested data"
	if payload.get("items") is not Array or (payload.items as Array).size() != (generated.rows as Array).size() or payload.get("players") is not Array or (payload.players as Array).size() != 1:
		return "Saved item or player count is invalid"
	for key in ["next_recovery_serial", "next_runtime_bag_serial", "next_collection_serial", "revision", "required_total", "elapsed_active_seconds"]:
		if payload.get(key) is not int and payload.get(key) is not float:
			return "Saved %s value is invalid" % key
	if payload.has("faint_count"):
		var count: Variant = payload.faint_count
		if (count is not int and count is not float) or float(count) != floorf(float(count)) or float(count) < -1.0:
			return "Saved faint count is invalid"
	if payload.get("initial_manifest") is not Array or _canonical(payload.initial_manifest) != str(manifest.canonical_rows):
		return "Saved manifest differs from authored content"
	for key in ["table_records", "bin_records", "bag_records", "container_records", "recovery_piles", "rescue_states", "section_states", "group_states", "zone_states", "completion_receipt"]:
		if payload.get(key) is not Dictionary:
			return "Save field %s has an invalid structure" % key
	for table in (payload.table_records as Dictionary).values():
		if table is not Dictionary or table.get("cells") is not Dictionary or table.get("tray") is not Array:
			return "Saved sorting table is invalid"
	for bin in (payload.bin_records as Dictionary).values():
		if bin is not Dictionary or bin.get("items") is not Array:
			return "Saved sorting bin is invalid"
	for container in (payload.container_records as Dictionary).values():
		if container is not Dictionary:
			return "Saved container is invalid"
		match str(container.get("kind", "")):
			"output_rack":
				if container.get("slots") is not Dictionary:
					return "Saved rack is invalid"
				for slot in (container.slots as Dictionary):
					if not str(slot).is_valid_int() or int(slot) < 0 or int(slot) >= SortingStation.RACK_CAPACITY:
						return "Saved rack slot is invalid"
			"waste_container":
				if container.get("bags") is not Array:
					return "Saved waste container is invalid"
			"placement_pool":
				if container.get("occupants") is not Dictionary:
					return "Saved placement pool is invalid"
			_:
				return "Saved container kind is unknown"
	for bag in (payload.bag_records as Dictionary).values():
		if bag is not Dictionary or bag.get("item_ids") is not Array or not _finite_array(bag.get("world_transform"), 12) or not _finite_array(bag.get("linear_velocity"), 3) or not _finite_array(bag.get("angular_velocity"), 3):
			return "Saved disposal bag is invalid"
	for pile in (payload.recovery_piles as Dictionary).values():
		if pile is not Dictionary or pile.get("item_ids") is not Array or pile.get("bag_ids") is not Array or not _finite_array(pile.get("origin"), 3):
			return "Saved recovery marker is invalid"
	for rescue in (payload.rescue_states as Dictionary).values():
		if rescue is not Dictionary or rescue.get("attachment_ids") is not Array:
			return "Saved rescue is invalid"
	for key in ["section_states", "group_states", "zone_states"]:
		for record in (payload[key] as Dictionary).values():
			if record is not Dictionary:
				return "Saved progress record is invalid"
	for key in ["discoveries", "guidance_seen", "optional_finds", "valuable_sales", "collection_receipts"]:
		if payload.get(key) is not Array:
			return "Saved %s list is invalid" % key
	for receipt in payload.valuable_sales as Array:
		if receipt is not Dictionary:
			return "Saved sale receipt is invalid"
	for receipt in payload.collection_receipts as Array:
		if receipt is not Dictionary:
			return "Saved collection receipt is invalid"
	if (payload.bag_records as Dictionary).size() > 5400 or (payload.recovery_piles as Dictionary).size() > 5400 or payload.get("collection_receipts") is not Array or (payload.collection_receipts as Array).size() > 5400:
		return "Saved container or receipt count is invalid"
	var expected := manifest.expected as Dictionary
	var seen := {}
	for item_value in payload.items as Array:
		if item_value is not Dictionary:
			return "Saved item row is invalid"
		var item := item_value as Dictionary
		var item_id := str(item.get("item_id", ""))
		if not expected.has(item_id) or seen.has(item_id):
			return "Saved item identity is invalid"
		seen[item_id] = true
		var authored := expected[item_id] as Dictionary
		if str(item.get("definition_id", "")) != str(authored.definition_id) or str(item.get("home_section_id", "")) != str(authored.section_id) or str(item.get("home_zone_id", "")) != str(authored.zone_id) or bool(item.get("required", false)) != bool(authored.required):
			return "Saved item does not match its authored identity"
		if StringName(str(item.get("location", ""))) not in ItemRecord.LOCATION_NAMES:
			return "Saved item has an unknown location"
		if item.get("dirty_patches_remaining") is not Array:
			return "Saved item dirt is invalid"
		if not _finite_array(item.get("last_world_transform"), 12) or not _finite_array(item.get("linear_velocity"), 3) or not _finite_array(item.get("angular_velocity"), 3) or not _finite_array(item.get("dig_surface_position"), 3) or not _finite_array(item.get("reveal_transform"), 12):
			return "Saved item has an invalid pose"
	var player_value: Variant = (payload.players as Array)[0]
	if player_value is not Dictionary:
		return "Saved player is invalid"
	var saved_player := player_value as Dictionary
	if str(saved_player.get("player_id", "")) != "local" or not _finite_array(saved_player.get("transform"), 12) or not _finite_array(saved_player.get("velocity"), 3):
		return "Saved player pose is invalid"
	for key in ["bag_capacity", "hand_capacity", "active_slot", "selected_held_index", "money", "air_remaining"]:
		if saved_player.get(key) is not int and saved_player.get(key) is not float:
			return "Saved player %s is invalid" % key
	for key in ["trash_bag", "valuable_bag", "held_objects", "owned_tools", "owned_gear", "equipped_handheld_ids", "discoveries"]:
		if saved_player.get(key) is not Array:
			return "Saved player inventory is invalid"
	if saved_player.has("bag_order") and saved_player.bag_order is not Array:
		return "Saved bag order is invalid"
	if saved_player.get("upgrade_levels") is not Dictionary:
		return "Saved player upgrades are invalid"
	for held in saved_player.held_objects as Array:
		if held is not Dictionary:
			return "Saved held-object reference is invalid"
	return ""


func _bounded_value(value: Variant, depth: int) -> bool:
	if depth > 9:
		return false
	if value is String or value is StringName:
		return str(value).length() <= 256
	if value is float or value is int:
		return is_finite(float(value)) and absf(float(value)) <= 1000000000.0
	if value is Array:
		if value.size() > 6000:
			return false
		for child in value:
			if not _bounded_value(child, depth + 1):
				return false
	if value is Dictionary:
		if value.size() > 6000:
			return false
		for key in value:
			if not _bounded_value(key, depth + 1) or not _bounded_value(value[key], depth + 1):
				return false
	return true


func _finite_array(value: Variant, length: int) -> bool:
	if value is not Array or (value as Array).size() != length:
		return false
	for number in value as Array:
		if number is not int and number is not float:
			return false
		if not is_finite(float(number)) or absf(float(number)) > 1000000.0:
			return false
	return true


func _slot_folder(target_beach: StringName, run_id: String, slot_id: StringName) -> String:
	return save_root.path_join(str(target_beach)).path_join(run_id).path_join(str(slot_id))


func _valid_id(value: String) -> bool:
	if value.is_empty() or value.length() > MAX_ID_LENGTH:
		return false
	for index in value.length():
		var code := value.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code == 95 or code == 45):
			return false
	return true


## This build's content hash, computed once per process (the content cannot change while running).
func _content_hash() -> String:
	_cache_lock.lock()
	var value := _content_hash_value
	_cache_lock.unlock()
	if value.is_empty():
		var generator := ManifestGenerator.new()
		value = generator.compute_content_hash(generator.load_catalog(), load(ManifestGenerator.BEACH_PATH) as BeachDefinition, load(ManifestGenerator.QUOTAS_PATH) as Resource, load(ManifestGenerator.ANCHORS_PATH) as Resource)
		_cache_lock.lock()
		_content_hash_value = value
		_cache_lock.unlock()
	return value


static func _canonical(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)
