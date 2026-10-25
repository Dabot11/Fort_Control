extends SceneTree
## Offline GLB texture preparation; mesh, skin and animation bytes stay unchanged.
## godot --headless --path /tmp/empty_project --script /path/to/prepare_character.gd -- SOURCE_SKELETON SOURCE_SWORD OUTPUT_ASSETS_MODELS


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 3:
		push_error("Expected source skeleton.glb, source sword.glb, and output assets/models directory.")
		quit(1)
		return
	var output_root := arguments[2].trim_suffix("/")
	if not _prepare_glb(arguments[0], output_root + "/skeleton/warrior.glb", 1024):
		quit(1)
		return
	if not _prepare_glb(arguments[1], output_root + "/sword/shardblade.glb", 512):
		quit(1)
		return
	quit()


func _prepare_glb(source: String, destination: String, texture_size: int) -> bool:
	var original := FileAccess.get_file_as_bytes(source)
	if original.size() < 28 or original.decode_u32(0) != 0x46546C67 or original.decode_u32(4) != 2:
		push_error("Input is not a GLB 2.0 file: " + source)
		return false
	var json_size := int(original.decode_u32(12))
	if original.decode_u32(16) != 0x4E4F534A or 28 + json_size > original.size():
		push_error("Invalid GLB JSON chunk: " + source)
		return false
	var parsed = JSON.parse_string(original.slice(20, 20 + json_size).get_string_from_utf8())
	if not parsed is Dictionary:
		push_error("Could not parse GLB JSON: " + source)
		return false
	var document: Dictionary = parsed
	if document.get("buffers", []).size() != 1 or original.decode_u32(24 + json_size) != 0x004E4942:
		push_error("Expected a single embedded GLB binary buffer: " + source)
		return false
	var binary_size := int(original.decode_u32(20 + json_size))
	var binary := original.slice(28 + json_size, 28 + json_size + binary_size)
	var replacements: Dictionary = {}
	for image_record: Dictionary in document.get("images", []):
		if not image_record.has("bufferView") or image_record.get("mimeType") != "image/jpeg":
			push_error("This preparation expects embedded JPEG textures: " + source)
			return false
		var view_index := int(image_record["bufferView"])
		var view: Dictionary = document["bufferViews"][view_index]
		var offset := int(view.get("byteOffset", 0))
		var texture_bytes := binary.slice(offset, offset + int(view["byteLength"]))
		var texture := Image.new()
		if texture.load_jpg_from_buffer(texture_bytes) != OK:
			push_error("Could not decode an embedded texture: " + source)
			return false
		var largest_side := maxi(texture.get_width(), texture.get_height())
		if largest_side > texture_size:
			var ratio := float(texture_size) / float(largest_side)
			texture.resize(maxi(1, roundi(texture.get_width() * ratio)), maxi(1, roundi(texture.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
		replacements[view_index] = texture.save_jpg_to_buffer(0.88)
	var packed_binary := PackedByteArray()
	for view_index in range(document["bufferViews"].size()):
		var view: Dictionary = document["bufferViews"][view_index]
		var old_offset := int(view.get("byteOffset", 0))
		var payload: PackedByteArray = replacements.get(view_index, binary.slice(old_offset, old_offset + int(view["byteLength"])))
		while packed_binary.size() % 4 != 0:
			packed_binary.append(0)
		view["byteOffset"] = packed_binary.size()
		view["byteLength"] = payload.size()
		packed_binary.append_array(payload)
	document["buffers"][0]["byteLength"] = packed_binary.size()
	while packed_binary.size() % 4 != 0:
		packed_binary.append(0)
	var packed_json := JSON.stringify(document, "", true, true).to_utf8_buffer()
	while packed_json.size() % 4 != 0:
		packed_json.append(0x20)
	var output := PackedByteArray()
	output.resize(12)
	output.encode_u32(0, 0x46546C67)
	output.encode_u32(4, 2)
	output.encode_u32(8, 28 + packed_json.size() + packed_binary.size())
	_append_chunk(output, packed_json, 0x4E4F534A)
	_append_chunk(output, packed_binary, 0x004E4942)
	if DirAccess.make_dir_recursive_absolute(destination.get_base_dir()) != OK:
		push_error("Cannot create output directory: " + destination.get_base_dir())
		return false
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		push_error("Cannot open output file: " + destination)
		return false
	file.store_buffer(output)
	file.close()
	print("Prepared %s: %d -> %d bytes; textures <= %d; mesh, skin and clips preserved." % [destination, original.size(), output.size(), texture_size])
	return true


func _append_chunk(output: PackedByteArray, payload: PackedByteArray, kind: int) -> void:
	var header := PackedByteArray()
	header.resize(8)
	header.encode_u32(0, payload.size())
	header.encode_u32(4, kind)
	output.append_array(header)
	output.append_array(payload)
