###############################################################################
# Copyright (c) 2022 Miles Mazzotta
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
###############################################################################

extends Reference
class_name Replay

var _history: Array
var _tickrate: int
var _full_snapshot_tickrate: int
var edec: EncDecBuffer = get_net_edec()
var _scene_path: String

func _init(tickrate: int,full_snapshot_tickrate: int,scene_path: String) -> void:
	setup(tickrate,full_snapshot_tickrate, scene_path)

func setup(tickrate: int,full_snapshot_tickrate: int, scene_path: String) -> void:
	_tickrate = tickrate
	_full_snapshot_tickrate = full_snapshot_tickrate
	_scene_path = scene_path

func add_snapshot(snapshot: NetSnapshot) -> void:
	_history.append(snapshot)

func is_full_snapshot(snapshot: NetSnapshot) -> bool:
	return snapshot.signature%_full_snapshot_tickrate == 0

func get_snapshot_is_full(idx: int) -> bool:
	return is_full_snapshot(get_snapshot(idx))

func get_snapshot(idx: int) -> NetSnapshot:
	return _history[idx]

func encode_snapshot(snapshot: NetSnapshot) -> PoolByteArray:
	# There is no practical reason to cache this as a local variable.
	# This is simply here to make some of the lower lines of code shorter.
	var sd: NetSnapshotData = network.snapshot_data
	edec.buffer = PoolByteArray()
	if is_full_snapshot(snapshot):
		sd.encode_full(snapshot,edec,snapshot.input_sig)
	else:
		sd.encode_delta(snapshot,sd._history[-1],edec,snapshot.input_sig)
	return edec.buffer

func reset() -> void:
	_history.clear()
	# Every time a new replay is loaded, the tickrate and full_snapshot_tickrate
	# SHOULD be set to something new. No point in setting them to 0, because
	# if a replay is loaded and these are incorrect, something has definitely
	# gone wrong.
#	tickrate = 0
#	full_snapshot_tickrate = 0

func save(name: String, directory: String) -> void:
	print("Attempting to save replay...")
	if !_history.empty():
		print("Generating serialized history...")
		var newarray: Array
		var temp: Array = _history
		newarray.resize(_history.size())
		for i in newarray.size():
			newarray[i] = encode_snapshot(_history[i])
		print("Serialized history encoded and stored.")
		_history = newarray
		print("Attempting to write replay to disk...")
		save_compressed(File.new(),self,name,directory)
		_history = temp
	else:
		print("Attempted to save Replay %s at %s but couldn't. Replay history is empty!"%[name,directory])

func save_and_reset(name: String, directory: String) -> void:
	save(name,directory)
	reset()

# Maybe rename to denote that it's related to files
func load_replay(filepath: String) -> void:
	deserialize(read_compressed_replay_file(filepath))
	# Could totally just be this instead:
#	_history = convert_to_snapshots(read_compressed_replay_file(filepath),buffer)

# Theoretically this is faster than reading a replay file, converting that
# array from an array of poolbytearrays to an array of snapshots, and then
# assigning the history var to the array of snapshots. Why do I say theoretically?
# Because I have ZERO clue if that's actually true or not.
func deserialize(serialized: Array) -> void:
	assert_enumerated_array_correct(serialized)
	assert(_history.empty())
	setup(serialized[TICKRATE],serialized[FULL_SNAPSHOT_TICKRATE],serialized[SCENE_PATH])
	call_deferred("deserialize_history",serialized[HISTORY])

func deserialize_history(serialized_history: Array) -> void:
	for s_snap in serialized_history:
		assert(s_snap is PoolByteArray)
		edec.buffer = s_snap
		if _history.empty():
			_history.append(network.snapshot_data.decode_full(edec))
		else:
			_history.append(network.snapshot_data.decode_delta(edec))

func get_current_time_unix(idx: int) -> int:
	return idx/_tickrate

func get_current_time_as_string(idx: int) -> String:
	return Time.get_time_string_from_unix_time(get_current_time_unix(idx))

func get_total_time_unix() -> int:
	return (_history.size()-1)/_tickrate

func get_total_time_as_string() -> String:
	return Time.get_time_string_from_unix_time(get_total_time_unix())



# STATIC AND HELPER FUNCS //////////////////////////////////////////////////////

static func get_net_edec() -> EncDecBuffer:
	return network._update_control.edec

static func get_net_buffer() -> PoolByteArray:
	return network._update_control.edec.buffer

const default_save_path: String = "user://replays/"
# over-engineering stuff for fun
const explodingreplays = "exploding_addons/replays/"
const recsetting = "record_replays"
const capratesetting = "capture_rate"
const fullratesetting = "full_snapshot_capture_rate"
const defaultdiresetting = "default_replay_directory"

static func get_default_directory() -> String:
	if ProjectSettings.has_setting(explodingreplays+defaultdiresetting):
		return ProjectSettings.get_setting(explodingreplays+defaultdiresetting)
	else:
		return default_save_path
	

static func convert_to_snapshots(replay: Array, buffer: EncDecBuffer) -> Array:
	assert_enumerated_array_correct(replay)
	var history: Array = replay[HISTORY]
	for idx in history.size():
		assert(history[idx] is PoolByteArray)
		buffer.buffer = history[idx]
		if idx%replay[FULL_SNAPSHOT_TICKRATE] == 0:
			history[idx] = network.snapshot_data.decode_full(buffer)
		else:
			history[idx] = network.snapshot_data.decode_delta(buffer)
	# doesn't need to return necessarily, this func operates over the actual array itself
	return replay

enum {TICKRATE,FULL_SNAPSHOT_TICKRATE,SCENE_PATH,HISTORY,REPLAY_MAX}
static func to_enumerated_array(replay: Replay) -> Array:
	return [replay._tickrate,replay._full_snapshot_tickrate,replay._scene_path,replay._history]

static func assert_enumerated_array_correct(array: Array) -> void:
	assert(array.size() == REPLAY_MAX)
	assert(array[TICKRATE] is int and array[FULL_SNAPSHOT_TICKRATE] is int and array[HISTORY] is Array)

static func replay_to_compressed_buffer(replay: Replay) -> PoolByteArray:
	return var2bytes(to_enumerated_array(replay)).compress(File.COMPRESSION_GZIP)

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

static func default_file(title: String) -> String:
	return title + get_datetime_string() + OS.get_unique_id()

static func as_replay_file(filename: String) -> String:
	return str("%s.REPLAY"%[filename])

static func get_datetime_string() -> String:
	return Time.get_datetime_string_from_system(false, true).replace(":", "-")

static func open_file_at_directory(file: File, file_name: String, directory: String) -> void:
	make_dir_if_doesnt_exist(directory)
	file.open(directory + file_name, File.WRITE)

static func save_compressed(file: File, replay: Replay, title: String, directory: String) -> void:
	open_file_at_directory(file,as_replay_file(title),directory)
	print("Storing compressed replay file...")
	file.store_buffer(replay_to_compressed_buffer(replay))
	
	prints("Closing compressed replay file",as_replay_file(title),"...")
	file.close()
	prints("File closed.")

static func make_dir_if_doesnt_exist(path: String) -> void:
	var dir:= Directory.new()
	if !dir.dir_exists(path):
		if dir.make_dir(path) != OK:
			# this is mad barebones
			printerr("make_dir failed!")
