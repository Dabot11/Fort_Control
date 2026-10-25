extends SceneTree
## Configure only the disposable project created by export_web.sh.


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 1 or not FileAccess.file_exists("res://.fort-web-staging"):
		push_error("Use scripts/export_web.sh to prepare a disposable Web project.")
		quit(1)
		return
	var project_path: String = ProjectSettings.globalize_path("res://project.godot")
	if project_path != arguments[0]:
		push_error("Web staging path does not match the current project.")
		quit(1)
		return
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(project_path)
	if error != OK:
		push_error("Cannot read Web staging configuration: %s" % error_string(error))
		quit(1)
		return
	config.set_value("application", "config/features", PackedStringArray(["4.6", "GL Compatibility"]))
	config.set_value("rendering", "renderer/rendering_method", "gl_compatibility")
	config.set_value("rendering", "renderer/rendering_method.mobile", "gl_compatibility")
	config.set_value("rendering", "renderer/rendering_method.web", "gl_compatibility")
	config.set_value("rendering", "textures/vram_compression/import_s3tc_bptc", true)
	config.set_value("rendering", "textures/vram_compression/import_etc2_astc", true)
	error = config.save(project_path)
	if error != OK:
		push_error("Cannot save Web staging configuration: %s" % error_string(error))
		quit(1)
		return
	quit(0)
