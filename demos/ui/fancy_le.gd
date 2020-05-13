# Simple demo for the FancyLineEdit custom control
# This control is part of the UI controls (keh_ui directory) and is defined in
# the fancy_line_edit.gd script file.

# The examples using "dynamic formatting" will first catch the request within the
# specified function but will then relay the request into another function. This is
# done mostly because the code is the same for all examples in order to generate the
# correct renderable objects.


extends Node2D

# Preload the smily textures
var tex_smile: Texture = load("res://shared/textures/smile_32x32.png")
var tex_wink: Texture = load("res://shared/textures/wink_32x32.png")
var tex_tongueo: Texture = load("res://shared/textures/tongueout_32x32.png")

# Predefine the colors to make things easier to work with in the code
const c_yellow: Color = Color(1, 0.86, 0.39)
const c_red: Color = Color(0.8, 0.2, 0.1)
const c_green: Color = Color(0.1, 0.86, 0.1)

# This dictionary will hold some of the pattern formats for the emojis
# key = emoji ID
# Fields:
# - texture
# - color
var emoji_data: Dictionary


func _ready() -> void:
	### Configure Example 1.
	# Add 3 (4 actually) strict words that will be converted into yellow emojis
	# Because the internal comparison is case sensitive, add one for :P and another for :p
	$example1/fle.add_strict_image(":)", tex_smile, c_yellow)
	$example1/fle.add_strict_image(";)", tex_wink, c_yellow)
	$example1/fle.add_strict_image(":p", tex_tongueo, c_yellow)
	$example1/fle.add_strict_image(":P", tex_tongueo, c_yellow)
	
	
	### Configure Example 2.
	# Attach the on_autoformat_example2() function to the control in order to generate
	# smiles that are typed within ":"
	# Argument 1 indicates the character that will trigger the "pattern function" call
	# Argument 2 indicates the character that will end this "pattern"
	# Argument 3 set to true tells this "pattern" can occur anywhere in the typed string
	# Argument 4 is the function reference pointing to on_autoformat_example2()
	$example2/fle.add_pattern_autoformat(":", ":", true, funcref(self, "on_autoformat_example2"))
	
	### Configure Example 3.
	# This is simply a combination of examples 1 and 2
	$example3/fle.add_strict_image(":)", tex_smile, c_green)
	$example3/fle.add_strict_image(";)", tex_wink, c_green)
	$example3/fle.add_strict_image(":p", tex_tongueo, c_green)
	$example3/fle.add_strict_image(":P", tex_tongueo, c_green)
	$example3/fle.add_pattern_autoformat(":", ":", true, funcref(self, "on_autoformat_example3"))
	
	### Configure Example 4.
	# This is a combination of examples 1 and 2, but with the addition of buttons to generate
	# smiles inside the text box. The "pattern" in this case also allows different colors for
	# the emojis, based on how the "id" is built. As an example, :smile: = yellow, :smile_r: = red
	$example4/fle.add_strict_image(":)", tex_smile, c_yellow)
	$example4/fle.add_strict_image(";)", tex_wink, c_yellow)
	$example4/fle.add_strict_image(":p", tex_tongueo, c_yellow)
	$example4/fle.add_strict_image(":P", tex_tongueo, c_yellow)
	$example4/fle.add_pattern_autoformat(":", ":", true, funcref(self, "on_autoformat_example4"))
	
	SharedUtils.connector($example4/bt_smiley, "pressed", self, "_on_bt_emoji_pressed", [$example4/fle, ":smile:"])
	SharedUtils.connector($example4/bt_smileg, "pressed", self, "_on_bt_emoji_pressed", [$example4/fle, ":smile_g:"])
	SharedUtils.connector($example4/bt_smiler, "pressed", self, "_on_bt_emoji_pressed", [$example4/fle, ":smile_r:"])
	SharedUtils.connector($example4/bt_winky, "pressed", self, "_on_bt_emoji_pressed", [$example4/fle, ":wink:"])
	SharedUtils.connector($example4/bt_winkg, "pressed", self, "_on_bt_emoji_pressed", [$example4/fle, ":wink_g:"])
	SharedUtils.connector($example4/bt_winkr, "pressed", self, "_on_bt_emoji_pressed", [$example4/fle, ":wink_r:"])
	SharedUtils.connector($example4/bt_tonguey, "pressed", self, "_on_bt_emoji_pressed", [$example4/fle, ":tongueout:"])
	SharedUtils.connector($example4/bt_tongueg, "pressed", self, "_on_bt_emoji_pressed", [$example4/fle, ":tongueout_g:"])
	SharedUtils.connector($example4/bt_tonguer, "pressed", self, "_on_bt_emoji_pressed", [$example4/fle, ":tongueout_r:"])
	
	### Configure Example 5
	# This example uses '/' to trigger the auto-format and call the custom function meant to generate
	# the renderable object. The idea here is to emulate commands in a console box, which only makes
	# sense if they are at the beginning of the string. To that end, the third argument is set to false
	$example5/fle.add_pattern_autoformat("/", "", false, funcref(self, "on_autoformat_example5"))
	
	
	### Configure Example 6.
	# This example combines all of the previous examples, plus some additional things.
	# - Valid commands are green and bold
	# - Invalid commands are red italic
	# - Invalid emoji (through patterns) are red, italic and underline
	$example6/fle.add_strict_image(":)", tex_smile, c_yellow)
	$example6/fle.add_strict_image(";)", tex_wink, c_yellow)
	$example6/fle.add_strict_image(":p", tex_tongueo, c_yellow)
	$example6/fle.add_strict_image(":P", tex_tongueo, c_yellow)
	$example6/fle.add_pattern_autoformat(":", ":", true, funcref(self, "on_autoformat_example6_smile"))
	$example6/fle.add_pattern_autoformat("/", " ", false, funcref(self, "on_autoformat_example6_comm"))
	
	$example6/fle.add_strict_text("FancyLineEdit", c_green, false, true, true, true)
	
	SharedUtils.connector($example6/bt_smiley, "pressed", self, "_on_bt_emoji_pressed", [$example6/fle, ":smile:"])
	SharedUtils.connector($example6/bt_smileg, "pressed", self, "_on_bt_emoji_pressed", [$example6/fle, ":smile_g:"])
	SharedUtils.connector($example6/bt_smiler, "pressed", self, "_on_bt_emoji_pressed", [$example6/fle, ":smile_r:"])
	SharedUtils.connector($example6/bt_winky, "pressed", self, "_on_bt_emoji_pressed", [$example6/fle, ":wink:"])
	SharedUtils.connector($example6/bt_winkg, "pressed", self, "_on_bt_emoji_pressed", [$example6/fle, ":wink_g:"])
	SharedUtils.connector($example6/bt_winkr, "pressed", self, "_on_bt_emoji_pressed", [$example6/fle, ":wink_r:"])
	SharedUtils.connector($example6/bt_tonguey, "pressed", self, "_on_bt_emoji_pressed", [$example6/fle, ":tongueout:"])
	SharedUtils.connector($example6/bt_tongueg, "pressed", self, "_on_bt_emoji_pressed", [$example6/fle, ":tongueout_g:"])
	SharedUtils.connector($example6/bt_tonguer, "pressed", self, "_on_bt_emoji_pressed", [$example6/fle, ":tongueout_r:"])
	
	
	# Initialize the emoji data dictionary
	emoji_data = {
		"smile": { "texture": tex_smile, "color": c_yellow },
		"wink": { "texture": tex_wink, "color": c_yellow },
		"tongueout": { "texture": tex_tongueo, "color": c_yellow },
		
		"smile_r": { "texture": tex_smile, "color": c_red },
		"wink_r": { "texture": tex_wink, "color": c_red },
		"tongueout_r": { "texture": tex_tongueo, "color": c_red },
		
		"smile_g": { "texture": tex_smile, "color": c_green },
		"wink_g": { "texture": tex_wink, "color": c_green },
		"tongueout_g": { "texture": tex_tongueo, "color": c_green },
	}



## Multiple FancyLineEdit controls within this scene/script demo use the "pattern auto-formatting",
## which requires helper functions. Since the code is mostly the same for each demo, the registered
## function will then relay the request into those helpers.

# Helper function to build smile when using the correct triggered text
func helper_build_smile(word: String, is_closed: bool, fle: FancyLineEdit, scol: Color, icol: Color) -> FancyLineEdit.RenderableData:
	if (is_closed):
		# Strip out starting and ending characters
		var id: String = word.substr(1, word.length() - 2)
		var edata: Dictionary = {}
		
		# This specific example does not use explicit colored emojis, so using a subset of the
		# dictionary. The modulated color will be the one specified by "scol" rather than the
		# one found in the emoji_data
		match id:
			"smile", "wink", "tongueout":
				edata = emoji_data.get(id, {})
		
		if (edata.size() > 0):
			# The pattern is valid, so return the emoji with specified modulation color
			return FancyLineEdit.ImageRenderable.new(edata.texture, fle.get_normal_font(), scol)
		else:
			# The pattern is not valid, so return red colored text.
			return FancyLineEdit.TextRenderable.new(word, fle.get_normal_font(), icol, false)
	
	# The pattern is not even closed, so return default text
	return FancyLineEdit.TextRenderable.new(word, fle.get_normal_font(), fle.get_default_font_color(), false)


# Helper function to build colored smiles when using the correct triggered text
func helper_build_color_smile(word: String, is_closed: bool, fle: FancyLineEdit, icol: Color, ftype: String) -> FancyLineEdit.RenderableData:
	if (is_closed):
		var id: String = word.substr(1, word.length() - 2)
		var edata: Dictionary = emoji_data.get(id, {})
		
		if (edata.size() > 0):
			return FancyLineEdit.ImageRenderable.new(edata.texture, fle.get_normal_font(), edata.color)
		else:
			# Pattern is closed but invalid. Text color is specified by icol, while ftype specify the font decoration
			var uline: bool = false
			var font: Font = fle.get_normal_font()
			
			match ftype:
				"italics":
					font = fle.get_italics_font()
				"bold":
					font = fle.get_bold_font()
				"bold-italics":
					font = fle.get_bold_italics_font()
				"underline-italics":
					font = fle.get_italics_font()
					uline = true
			
			return FancyLineEdit.TextRenderable.new(word, font, icol, uline)
	
	# Pattern is not closed. Return default text
	return FancyLineEdit.TextRenderable.new(word, fle.get_normal_font(), fle.get_default_font_color(), false)


func helper_build_command(word: String, fle: FancyLineEdit, vcol: Color, icol: Color, vfont: String = "normal", ifont: String = "normal") -> FancyLineEdit.RenderableData:
	# The provided "word" argument normally contains both start and end characters, however in this case the
	# ending character is an space, which is not included in the argument. So, just strip the starting character
	var id: String = word.substr(1, word.length() - 1)
	var use_color: Color = icol      # Assume invalid command
	var ft: String = ifont           # Assume invalid font type
	var use_font: Font = fle.get_normal_font()
	
	match id:
		"help", "warpto", "kick":
			use_color = vcol
			ft = vfont
	
	match ft:
		"italics":
			use_font = fle.get_italics_font()
		"bold":
			use_font = fle.get_bold_font()
		"bold_italics":
			use_font = fle.get_bold_italics_font()
	
	return FancyLineEdit.TextRenderable.new(word, use_font, use_color, false)



func on_autoformat_example2(word: String, is_closed: bool) -> FancyLineEdit.RenderableData:
	# Called by the example 2 "pattern auto-formatting". Relay to the helper_build_smile() function
	return helper_build_smile(word, is_closed, $example2/fle, c_yellow, c_red)

func on_autoformat_example3(word: String, is_closed: bool) -> FancyLineEdit.RenderableData:
	return helper_build_smile(word, is_closed, $example3/fle, c_green, c_red)

func on_autoformat_example4(word: String, is_closed: bool) -> FancyLineEdit.RenderableData:
	return helper_build_color_smile(word, is_closed, $example4/fle, c_red, "")

func on_autoformat_example5(word: String, _is_closed: bool) -> FancyLineEdit.RenderableData:
	return helper_build_command(word, $example5/fle, c_green, c_red, "normal", "normal")

func on_autoformat_example6_smile(word: String, is_closed: bool) -> FancyLineEdit.RenderableData:
	return helper_build_color_smile(word, is_closed, $example6/fle, c_red, "underline-italics")

func on_autoformat_example6_comm(word: String, _is_closed: bool) -> FancyLineEdit.RenderableData:
	return helper_build_command(word, $example6/fle, c_green, c_red, "bold", "normal")


func _on_bt_emoji_pressed(fle: FancyLineEdit, code: String) -> void:
	fle.add_text_at(code, fle.get_caret_index())
	fle.grab_focus()


func _on_bt_clear_pressed() -> void:
	$example1/fle.raw_text = ""
	$example2/fle.raw_text = ""
	$example3/fle.raw_text = ""
	$example4/fle.raw_text = ""
	$example5/fle.raw_text = ""
	$example6/fle.raw_text = ""


func _on_bt_back_pressed() -> void:
	# warning-ignore:return_value_discarded
	get_tree().change_scene("res://main.tscn")
