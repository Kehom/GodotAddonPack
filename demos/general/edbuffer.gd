# This demo is meant to showcase/test an addon and may even look like a "silly
# example".
# * Target Addon: keh_general/data/encdecbuffer.gd (EncDecBuffer)
# * What is going on: Ok so, basically this demo "simulates" the idea of
# encoding data into PoolByteArray (through the use of EncDecBuffer class)
# and send the bytes to another place (could be a remote machine through the
# network). The left panel allows you to setup some properties. Once the test
# button is pressed the data will be encoded and displayed on the right panel.
# Both in "raw" and decoded.
# As part of the test an extra PoolByteArray is created using the common
# var2bytes() function but only to display the size (in bytes) difference.
# All of the available compression methods are also compared and shown on the
# right panel.

extends Control


# Since there is no "static variables", we externally hold the instances of
# EncDecBuffer in order to avoid multiple creations of the internal data.
# If supposing client-server, this encoder could just be on the server
var encoder: EncDecBuffer = null
# If supposing client-server, this decoder could just be on the client
var decoder: EncDecBuffer = null
# Just to compare the size difference, this byte array will be created
# by using var2bytes taking the exact same values as input.
var comparer: PoolByteArray = PoolByteArray()

# LineEdit does not have an "easy" way to validate input. Namely, when the
# text_changed() signal is fired, the internal text property has already
# been changed. So, this variable will cache the last valid input and when
# the text_changed() is fired, the new value will be tested and if invalid
# revert back to the cached value
var last_valid_floatstr: String

var lv_uint32: String

var last_valid_v2x: String
var last_valid_v2y: String

var lv_rec2_px: String
var lv_rec2_py: String
var lv_rec2_sx: String
var lv_rec2_sy: String

var lv_vec3x: String
var lv_vec3y: String
var lv_vec3z: String

var lv_quatx: String
var lv_quaty: String
var lv_quatz: String
var lv_quatw: String

var lv_colr: String
var lv_colg: String
var lv_colb: String
var lv_cola: String


func _ready() -> void:
	last_valid_floatstr = str($srv_panel/txt_float.text)
	lv_uint32 = str($srv_panel/txt_uint32.text)
	last_valid_v2x = str($srv_panel/txt_vec2x.text)
	last_valid_v2y = str($srv_panel/txt_vec2y.text)
	lv_rec2_px = str($srv_panel/txt_rec2px.text)
	lv_rec2_py = str($srv_panel/txt_rec2py.text)
	lv_rec2_sx = str($srv_panel/txt_rec2sx.text)
	lv_rec2_sy = str($srv_panel/txt_rec2sy.text)
	lv_vec3x = str($srv_panel/hboxvec3/txt_vec3x.text)
	lv_vec3y = str($srv_panel/hboxvec3/txt_vec3y.text)
	lv_vec3z = str($srv_panel/hboxvec3/txt_vec3z.text)
	lv_quatx = str($srv_panel/hboxquat/txt_quatx.text)
	lv_quaty = str($srv_panel/hboxquat/txt_quaty.text)
	lv_quatz = str($srv_panel/hboxquat/txt_quatz.text)
	lv_quatw = str($srv_panel/hboxquat/txt_quatw.text)
	lv_colr = str($srv_panel/hboxcolor/txt_colr.text)
	lv_colg = str($srv_panel/hboxcolor/txt_colg.text)
	lv_colb = str($srv_panel/hboxcolor/txt_colb.text)
	lv_cola = str($srv_panel/hboxcolor/txt_cola.text)
	
	encoder = EncDecBuffer.new()
	decoder = EncDecBuffer.new()
	
	encode_data()
	decode_data(encoder.buffer)
	
	# warning-ignore:return_value_discarded
	$srv_panel/txt_float.connect("text_changed", self, "_on_text_changed", [$srv_panel/txt_float, "last_valid_floatstr"])
	# warning-ignore:return_value_discarded
	$srv_panel/txt_uint32.connect("text_changed", self, "_on_uint_changed", [$srv_panel/txt_uint32, "lv_uint32"])
	# warning-ignore:return_value_discarded
	$srv_panel/txt_vec2x.connect("text_changed", self, "_on_text_changed", [$srv_panel/txt_vec2x, "last_valid_v2x"])
	# warning-ignore:return_value_discarded
	$srv_panel/txt_vec2y.connect("text_changed", self, "_on_text_changed", [$srv_panel/txt_vec2y, "last_valid_v2y"])
	
	# warning-ignore:return_value_discarded
	$srv_panel/txt_rec2px.connect("text_changed", self, "_on_text_changed", [$srv_panel/txt_rec2px, "lv_rec2_px"])
	# warning-ignore:return_value_discarded
	$srv_panel/txt_rec2py.connect("text_changed", self, "_on_text_changed", [$srv_panel/txt_rec2py, "lv_rec2_py"])
	# warning-ignore:return_value_discarded
	$srv_panel/txt_rec2sx.connect("text_changed", self, "_on_text_changed", [$srv_panel/txt_rec2sx, "lv_rec2_sx"])
	# warning-ignore:return_value_discarded
	$srv_panel/txt_rec2sy.connect("text_changed", self, "_on_text_changed", [$srv_panel/txt_rec2sy, "lv_rec2_sy"])
	
	#warning-ignore:return_value_discarded
	$srv_panel/hboxvec3/txt_vec3x.connect("text_changed", self, "_on_text_changed", [$srv_panel/hboxvec3/txt_vec3x, "lv_vec3x"])
	#warning-ignore:return_value_discarded
	$srv_panel/hboxvec3/txt_vec3y.connect("text_changed", self, "_on_text_changed", [$srv_panel/hboxvec3/txt_vec3y, "lv_vec3y"])
	#warning-ignore:return_value_discarded
	$srv_panel/hboxvec3/txt_vec3z.connect("text_changed", self, "_on_text_changed", [$srv_panel/hboxvec3/txt_vec3z, "lv_vec3z"])
	
	#warning-ignore:return_value_discarded
	$srv_panel/hboxquat/txt_quatx.connect("text_changed", self, "_on_text_changed", [$srv_panel/hboxquat/txt_quatx, "lv_quatx"])
	#warning-ignore:return_value_discarded
	$srv_panel/hboxquat/txt_quaty.connect("text_changed", self, "_on_text_changed", [$srv_panel/hboxquat/txt_quaty, "lv_quaty"])
	#warning-ignore:return_value_discarded
	$srv_panel/hboxquat/txt_quatz.connect("text_changed", self, "_on_text_changed", [$srv_panel/hboxquat/txt_quatz, "lv_quatz"])
	#warning-ignore:return_value_discarded
	$srv_panel/hboxquat/txt_quatw.connect("text_changed", self, "_on_text_changed", [$srv_panel/hboxquat/txt_quatw, "lv_quatw"])
	
	#warning-ignore:return_value_discarded
	$srv_panel/hboxcolor/txt_colr.connect("text_changed", self, "_on_text_changed", [$srv_panel/hboxcolor/txt_colr, "lv_colr"])
	#warning-ignore:return_value_discarded
	$srv_panel/hboxcolor/txt_colg.connect("text_changed", self, "_on_text_changed", [$srv_panel/hboxcolor/txt_colg, "lv_colg"])
	#warning-ignore:return_value_discarded
	$srv_panel/hboxcolor/txt_colb.connect("text_changed", self, "_on_text_changed", [$srv_panel/hboxcolor/txt_colb, "lv_colb"])
	#warning-ignore:return_value_discarded
	$srv_panel/hboxcolor/txt_cola.connect("text_changed", self, "_on_text_changed", [$srv_panel/hboxcolor/txt_cola, "lv_cola"])




func encode_data() -> void:
	# Ensure the buffer is empty
	encoder.buffer = PoolByteArray()
	# And the "comparer" too
	comparer = PoolByteArray()
	
	# Encode the first value, a single byte
	encoder.write_byte($srv_panel/sp_byte.value)
	comparer.append_array(var2bytes($srv_panel/sp_byte.value))
	
	# Encode boolean 1
	encoder.write_bool($srv_panel/chk_bool1.pressed)
	comparer.append_array(var2bytes($srv_panel/chk_bool1.pressed))
	
	# Encode boolean 2
	encoder.write_bool($srv_panel/chk_bool2.pressed)
	comparer.append_array(var2bytes($srv_panel/chk_bool2.pressed))
	
	# Encode int32
	encoder.write_int($srv_panel/sp_int32.value)
	comparer.append_array(var2bytes($srv_panel/sp_int32.value))
	
	# Encode uint32
	# The String's to_int() function is returning a 32 bit integer and thus is
	# not entirely compatible with the full range of the variant's 64 bit integers
	encoder.write_uint(int($srv_panel/txt_uint32.text))
	comparer.append_array(var2bytes(int($srv_panel/txt_uint32.text)))
	
	# Encode float
	encoder.write_float($srv_panel/txt_float.text.to_float())
	comparer.append_array(var2bytes($srv_panel/txt_float.text.to_float()))
	
	# Encode vector2
	var vec2: Vector2 = Vector2($srv_panel/txt_vec2x.text.to_float(), $srv_panel/txt_vec2y.text.to_float())
	encoder.write_vector2(vec2)
	comparer.append_array(var2bytes(vec2))
	
	# Encode rect2
	var r2_pos: Vector2 = Vector2($srv_panel/txt_rec2px.text.to_float(), $srv_panel/txt_rec2py.text.to_float())
	var r2_siz: Vector2 = Vector2($srv_panel/txt_rec2sx.text.to_float(), $srv_panel/txt_rec2sy.text.to_float())
	var rec2: Rect2 = Rect2(r2_pos, r2_siz)
	encoder.write_rect2(rec2)
	comparer.append_array(var2bytes(rec2))
	
	# Encode vector3
	var vec3: Vector3 = Vector3($srv_panel/hboxvec3/txt_vec3x.text.to_float(), $srv_panel/hboxvec3/txt_vec3y.text.to_float(), $srv_panel/hboxvec3/txt_vec3z.text.to_float())
	encoder.write_vector3(vec3)
	comparer.append_array(var2bytes(vec3))
	
	# Encode quaternion
	var qx: float = $srv_panel/hboxquat/txt_quatx.text.to_float()
	var qy: float = $srv_panel/hboxquat/txt_quaty.text.to_float()
	var qz: float = $srv_panel/hboxquat/txt_quatz.text.to_float()
	var qw: float = $srv_panel/hboxquat/txt_quatw.text.to_float()
	var quat: Quat = Quat(qx, qy, qz, qw)
	encoder.write_quat(quat)
	comparer.append_array(var2bytes(quat))
	
	# Encode color
	var cr: float = $srv_panel/hboxcolor/txt_colr.text.to_float()
	var cg: float = $srv_panel/hboxcolor/txt_colg.text.to_float()
	var cb: float = $srv_panel/hboxcolor/txt_colb.text.to_float()
	var ca: float = $srv_panel/hboxcolor/txt_cola.text.to_float()
	var col: Color = Color(cr, cg, cb, ca)
	encoder.write_color(col)
	comparer.append_array(var2bytes(col))
	
	# Encode string
	var thestr: String = $srv_panel/txt_str.text
	encoder.write_string(thestr)
	comparer.append_array(var2bytes(thestr))



func decode_data(incoming: PoolByteArray) -> void:
	# First update the "var2bytes" label
	$cl_panel/lbl_var2bytes.text = "Using only var2bytes. Byte count = " + str(comparer.size()) + " bytes"
	$cl_panel/lbl_stripped.text = "EncDecBuffer. Byte count = " + str(incoming.size()) + " bytes"
	
	# Setup the decoder
	decoder.buffer = incoming
	
	# Prepare the string that will be used in the "decoded" box
	var dt: String = "Single byte: %s\n"
	dt +=	"Boolean 1: %s\n"
	dt += "Boolean 2: %s\n"
	dt += "Integer 32: %s\n"
	dt += "uint32: %s\n"
	dt += "Float: %s\n"
	dt += "Vector2: %s\n"
	dt += "Rect2: %s\n"
	dt += "Vector3: %s\n"
	dt += "Quat: %s\n"
	dt += "Color: %s\n"
	dt += "String: %s\n"
	
	dt = dt % [
		decoder.read_byte(),
		decoder.read_bool(),
		decoder.read_bool(),
		decoder.read_int(),
		decoder.read_uint(),
		decoder.read_float(),
		decoder.read_vector2(),
		decoder.read_rect2(),
		decoder.read_vector3(),
		decoder.read_quat(),
		decoder.read_color(),
		decoder.read_string(),
	]
	
	# Update the text box
	$cl_panel/txt_decoded.text = dt
	
	# And the raw text box
	$cl_panel/txt_raw.text = ""
	
	for b in incoming:
		$cl_panel/txt_raw.text += "%02X " % b
	
	
	# Comparing copression methods
	var compr_str: String = ""
	compr_str += "* Compression method: FastLZ\n"
	compr_str += "var2bytes array: " + str(comparer.compress(File.COMPRESSION_FASTLZ).size()) + " bytes\n"
	compr_str += "encoded array: " + str(decoder.buffer.compress(File.COMPRESSION_FASTLZ).size()) + " bytes\n\n"
	
	compr_str += "* Compression method: Deflate\n"
	compr_str += "var2bytes array: " + str(comparer.compress(File.COMPRESSION_DEFLATE).size()) + " bytes\n"
	compr_str += "encoded array: " + str(decoder.buffer.compress(File.COMPRESSION_DEFLATE).size()) + " bytes\n\n"
	
	compr_str += "* Compression method: Zstd\n"
	compr_str += "var2bytes array: " + str(comparer.compress(File.COMPRESSION_ZSTD).size()) + " bytes\n"
	compr_str += "encoded array: " + str(decoder.buffer.compress(File.COMPRESSION_ZSTD).size()) + " bytes\n\n"
	
	compr_str += "* Compression method: GZip\n"
	compr_str += "var2bytes array: " + str(comparer.compress(File.COMPRESSION_GZIP).size()) + " bytes\n"
	compr_str += "encoded array: " + str(decoder.buffer.compress(File.COMPRESSION_GZIP).size()) + " bytes\n\n"
	
	
	$cl_panel/txt_compression.text = compr_str




func _on_bt_test_pressed():
	encode_data()
	decode_data(encoder.buffer)



func _on_text_changed(txt: String, ctrl: LineEdit, lvalid: String) -> void:
	if (txt.is_valid_float()):
		set(lvalid, txt)
	else:
		if (txt == ""):
			set(lvalid, "0")
			ctrl.text = "0"
			ctrl.select(0, 1)
		else:
			var valid_val: String = get(lvalid)
			ctrl.text = valid_val
			ctrl.caret_position = valid_val.length()


func _on_uint_changed(txt: String, ctrl: LineEdit, lvalid: String) -> void:
	if (txt.is_valid_integer()):
		# String.to_int() does not give the desired result here because it restricts the
		# range to 32 bit signed integers.
		var i: int = int(txt)
		if (i < 0 || i > 0xFFFFFFFF):
			var valid_val: String = get(lvalid)
			ctrl.text = valid_val
			ctrl.caret_position = valid_val.length()
		
		else:
			set(lvalid, txt)
		
	
	else:
		if (txt == ""):
			set(lvalid, "0")
			ctrl.text = "0"
			ctrl.select(0, 1)
		
		else:
			var valid_val: String = get(lvalid)
			ctrl.text = valid_val
			ctrl.caret_position = valid_val.length()



func _on_bt_back_pressed() -> void:
	# warning-ignore:return_value_discarded
	get_tree().change_scene("res://main.tscn")

