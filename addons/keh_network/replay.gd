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
	print("reading compressed replay file...")
	if file.open(filepath, File.READ) == OK:
		return open_compressed(file)
	else:
		print("error reading compressed replay file!")
		return []

static func open_compressed(file: File) -> Array:
	print("opening compressed replay file")
	file.seek_end()
	var end := file.get_position()
	assert(end == file.get_len())
	file.seek(0)
	print("decompressing replay file...")
	var replay = bytes2var(decompress_data(file,end))
	print("data successfully decompressed!")
	assert(replay is Array)
	return replay

static func get_file_name(title: String) -> String:
	return str("%s %s %s.REPLAY"%[title, get_datetime_string(), OS.get_unique_id()])

static func get_datetime_string() -> String:
	return Time.get_datetime_string_from_system(false, true).replace(":", "-")

static func file_path_debug(name: String) -> String:
	return debug_save_path + name

static func file_path_normal(name: String) -> String:
	return save_path + name

static func save_compressed(file: File, replay: Array, title: String) -> void:
	# diverges behavior based on if the game is exported or not
	if !OS.has_feature("standalone"):
		make_dir_if_doesnt_exist(debug_save_path)
		file.open(file_path_debug(get_file_name(title)), File.WRITE)
	else:
		make_dir_if_doesnt_exist(save_path)
		file.open(file_path_normal(get_file_name(title)), File.WRITE)
	print("storing compressed replay file...")
	file.store_buffer(replay_to_compressed_buffer(replay))
	
	print("closing compressed replay file...")
	print(get_file_name(title))
	file.close()

static func make_dir_if_doesnt_exist(path: String) -> void:
	var dir:= Directory.new()
	if !dir.dir_exists(path):
		if dir.make_dir(path) != OK:
			# this is mad barebones
			printerr("make_dir failed!")

static func save(replay: Array) -> void:
	save_compressed(File.new(),replay,"replay")
