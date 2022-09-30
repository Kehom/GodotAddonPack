extends Reference
class_name Replay

const save_path: String = "user://replays/"
const debug_save_path: String = "res://replays/"

static func replay_to_compressed_buffer(replay: Array) -> PoolByteArray:
	return var2bytes(replay).compress(File.COMPRESSION_GZIP)

static func decompress_data(file: File, end: int) -> PoolByteArray:
	return file.get_buffer(end).decompress_dynamic(-1,File.COMPRESSION_GZIP)

static func read_compressed_replay_file(filepath: String) -> Array:
	var file := File.new()
	print("Reading compressed replay file...")
	if file.open(filepath, File.READ) == OK:
		return open_compressed(file)
	else:
		print("Error reading compressed replay file!")
		return []

static func open_compressed(file: File) -> Array:
	print("Decompressing replay file...")
	var replay = bytes2var(decompress_data(file,file.get_len()))
	print("Data successfully decompressed!")
	assert(replay is Array)
	return replay

static func make_file_name(title: String) -> String:
	return str("%s %s %s.REPLAY"%[title, get_datetime_string(), OS.get_unique_id()])

static func get_datetime_string() -> String:
	return Time.get_datetime_string_from_system(false, true).replace(":", "-")

static func open_file_at_directory(file: File, file_name: String, directory: String) -> void:
	make_dir_if_doesnt_exist(directory)
	file.open(directory + file_name, File.WRITE)

static func save_compressed(file: File, replay: Array, title: String) -> void:
	# diverges behavior based on if the game is exported or not
	if !OS.has_feature("standalone"):
		open_file_at_directory(file,make_file_name(title),debug_save_path)
	else:
		open_file_at_directory(file,make_file_name(title),save_path)
	print("Storing compressed replay file...")
	file.store_buffer(replay_to_compressed_buffer(replay))
	
	prints("Closing compressed replay file",make_file_name(title),"...")
	file.close()
	prints("File closed.")

static func make_dir_if_doesnt_exist(path: String) -> void:
	var dir:= Directory.new()
	if !dir.dir_exists(path):
		if dir.make_dir(path) != OK:
			# this is mad barebones
			printerr("make_dir failed!")

static func save(replay: Array,name: String = "Replay") -> void:
	save_compressed(File.new(),replay,name)
