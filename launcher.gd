extends Node2D

@onready var http = $HTTPRequest               # For version.json
@onready var file_downloader = $FileDownloader # For downloading files
@onready var play_button = $Control/HBoxContainer/PlayButton
@onready var Progress = $Control/HBoxContainer/VBoxContainer/ProgressBar

var remote_version_data
var files_to_download = []
var current_file_index = 0

# Fallback path for Documents (Godot 4+ does not have get_user_documents_dir)
var INSTALL_PATH = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS) + "/Genshin_DnD_Client/"
var VERSION_FILE = INSTALL_PATH + "version.txt"
var progress_steps_done = 0
var progress_target = 0

func _ready():
	print("Launcher started.")
	Progress.value = 0
	Progress.max_value = 100
	Progress.visible = true
	play_button.disabled = true

	ensure_install_folder_exists()
	if has_local_version():
		print("A game version is already installed. No full install needed.")
		fetch_version_info()
		# launch_game()
	else:
		print("No game version found — downloading full install.")
		fetch_version_info()

func ensure_install_folder_exists():
	if not DirAccess.dir_exists_absolute(INSTALL_PATH):
		var err = DirAccess.make_dir_recursive_absolute(INSTALL_PATH)
		if err != OK:
			print("Failed to create install folder.")
		else:
			print("Created install folder at: ", INSTALL_PATH)
	advance_progress()

func has_local_version() -> bool:
	return FileAccess.file_exists(VERSION_FILE)
	advance_progress()

func get_local_version() -> String:
	if has_local_version():
		var file = FileAccess.open(VERSION_FILE, FileAccess.READ)
		var version = file.get_as_text().strip_edges()
		file.close()
		return version
	return ""
	advance_progress()

func fetch_version_info():
	var url = "https://godot-airtable-backend.onrender.com/get_version"  # 🔁 Replace with your Render URL
	var err = http.request(url)
	if err != OK:
		print("Failed to send request for version.json")
	advance_progress()

func save_local_version():
	var file = FileAccess.open(VERSION_FILE, FileAccess.WRITE)
	if file:
		file.store_string(remote_version_data)  # now just a string
		file.close()
		print("Saved version file: ", VERSION_FILE)
	play_button.disabled = false


func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		print("Failed to fetch version info:", response_code)
		return

	var remote_version = body.get_string_from_utf8().strip_edges()
	remote_version_data = body.get_string_from_utf8().strip_edges()
	var local_version = get_local_version()

	print("Local version:", local_version)
	print("Remote version:", remote_version)

	if local_version == "":
		print("No local version found — downloading full install.")
		download_game_client()
		advance_progress()
	elif local_version != remote_version:
		print("Update available. Downloading new version.")
		download_game_client()
		advance_progress()
	else:
		print("Game is up-to-date.")
		play_button.disabled = false
		var tween = create_tween()
		tween.tween_property(Progress, "value", Progress.max_value, 0.1)
		fade_out_progress_bar()

	

func download_game_client():
	var download_url = "https://godot-airtable-backend.onrender.com/download"
	var err = file_downloader.request(download_url)
	if err != OK:
		print("Failed to send download request.")
	advance_progress()

func _on_file_downloader_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		print("Failed to download client:", response_code)
		return

	var file_path = INSTALL_PATH + "Genshin DnD Client.exe"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_buffer(body)
		file.close()
		print("Saved client.exe to: ", file_path)
		play_button.disabled = false
	else:
		print("Failed to save client.exe.")
		play_button.disabled = false

	save_local_version()
	var tween = create_tween()
	tween.tween_property(Progress, "value", Progress.max_value, 0.1)
	fade_out_progress_bar()

func advance_progress():
	var step_fill = randi_range(10, 25)
	progress_target += step_fill
	progress_target = min(progress_target, 99)  # Never hit 100 early


	var tween = create_tween()
	tween.tween_property(Progress, "value", progress_target, 0.1)

func fade_out_progress_bar():
	var tween = create_tween()
	tween.tween_interval(0.5)  # Wait for 1 second
	tween.tween_property(Progress, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func(): Progress.visible = false)


func _on_play_button_pressed() -> void:
	var game_path = INSTALL_PATH + "Genshin DnD Client.exe"
	print("Trying to launch game from:", game_path)

	if not FileAccess.file_exists(game_path):
		print("EXE file not found at:", game_path)
		return

	var success = OS.create_process(game_path, [])
	if success:
		print("Game launched successfully. Closing launcher.")
		await get_tree().create_timer(2.0).timeout
		get_tree().quit()
	else:
		print("Failed to launch game with create_process.")
