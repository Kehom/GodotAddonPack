extends MenuButton

var _pname: String = "Player"
var _avatar: Texture
var _ping: float = 0.0




func set_player_name(n: String) -> void:
	_pname = n
	_update_name_label()

func set_stamina(s: float) -> void:
	$box/innerbox/pb_stamina.value = clamp(s, 0.0, 1.0)

func set_avatar(t: Texture) -> void:
	_avatar = t
	$box/icon.texture = _avatar

func set_ping(p: float) -> void:
	_ping = p
	_update_name_label()


func _update_name_label() -> void:
	$box/innerbox/lbl_name.text = "%s (%d ms)" % [_pname, int(_ping)]
