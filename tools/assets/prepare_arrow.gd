extends SceneTree
## Repack the original GLB with 256 px textures; geometry and materials are retained.
## Usage: godot --headless --script prepare_arrow.gd -- source.glb output.glb

const TEXTURE_SIZE := 256


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		push_error("Expected original arrow GLB and destination GLB paths.")
		quit(2)
		return
	var input := FileAccess.get_file_as_bytes(arguments[0])
	if input.size() < 28 or input.decode_u32(0) != 0x46546C67 or input.decode_u32(4) != 2:
		push_error("The source must be a glTF 2 binary file.")
		quit(1)
		return
	var json_length := input.decode_u32(12)
	var document: Dictionary = JSON.parse_string(input.slice(20, 20 + json_length).get_string_from_utf8())
	var binary_start := 28 + json_length
	var binary := input.slice(binary_start)
	var image_views: Dictionary = {}
	for entry: Dictionary in document.get("images", []):
		image_views[int(entry.bufferView)] = entry
	var output_binary := PackedByteArray()
	var texture_count := 0
	for index in range(document.bufferViews.size()):
		var view: Dictionary = document.bufferViews[index]
		var offset := int(view.get("byteOffset", 0))
		var data := binary.slice(offset, offset + int(view.byteLength))
		if image_views.has(index):
			var image := Image.new()
			var entry: Dictionary = image_views[index]
			var result := image.load_jpg_from_buffer(data) if entry.mimeType == "image/jpeg" else image.load_png_from_buffer(data)
			if result != OK:
				push_error("Cannot decode original texture %d." % index)
				quit(1)
				return
			image.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
			data = image.save_png_to_buffer()
			entry.mimeType = "image/png"
			texture_count += 1
		while output_binary.size() % 4 != 0:
			output_binary.append(0)
		view.byteOffset = output_binary.size()
		view.byteLength = data.size()
		output_binary.append_array(data)
	document.buffers[0].byteLength = output_binary.size()
	document.nodes[0].name = "CrystalArrowMesh"
	var output_json := JSON.stringify(document).to_utf8_buffer()
	while output_json.size() % 4 != 0:
		output_json.append(32)
	while output_binary.size() % 4 != 0:
		output_binary.append(0)
	var output := PackedByteArray()
	output.resize(20)
	output.encode_u32(0, 0x46546C67)
	output.encode_u32(4, 2)
	output.encode_u32(8, 28 + output_json.size() + output_binary.size())
	output.encode_u32(12, output_json.size())
	output.encode_u32(16, 0x4E4F534A)
	output.append_array(output_json)
	var binary_header := PackedByteArray()
	binary_header.resize(8)
	binary_header.encode_u32(0, output_binary.size())
	binary_header.encode_u32(4, 0x004E4942)
	output.append_array(binary_header)
	output.append_array(output_binary)
	DirAccess.make_dir_recursive_absolute(arguments[1].get_base_dir())
	var file := FileAccess.open(arguments[1], FileAccess.WRITE)
	if file == null:
		push_error("Cannot write optimized arrow GLB.")
		quit(1)
		return
	file.store_buffer(output)
	file.close()
	print("Arrow: %d -> %d bytes; %d textures resized to %d px; geometry unchanged." % [input.size(), output.size(), texture_count, TEXTURE_SIZE])
	quit()
