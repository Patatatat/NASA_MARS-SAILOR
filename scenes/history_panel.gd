extends TextEdit
## Panel de lectura: las actualizaciones no deben mover al usuario.

func _init() -> void:
	editable = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func update_history(content: String, reset_position: bool = false) -> void:
	if text == content and not reset_position:
		return
	var vertical := 0.0 if reset_position else scroll_vertical
	var horizontal := 0 if reset_position else scroll_horizontal
	text = content
	scroll_vertical = vertical
	scroll_horizontal = horizontal
