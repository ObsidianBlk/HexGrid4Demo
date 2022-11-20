extends Control


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal operation_requested(req)

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var control_select : MenuButton = $MC/VBC/ControlSelect
@onready var controls_container : Control = $MC/VBC/Controls

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	var pop : PopupMenu = control_select.get_popup()
	for child in controls_container.get_children():
		if child.has_method("show_if_named"):
			pop.add_item(child.name)
			pop.set_item_metadata(pop.item_count - 1, child.name)
			pop.index_pressed.connect(self._on_popup_index_pressed)
		if child.has_signal("operation_requested"):
			child.operation_requested.connect(self._on_menu_operation_requested)


# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_popup_index_pressed(idx : int) -> void:
	var pop : PopupMenu = control_select.get_popup()
	var ctrl_name : String = pop.get_item_metadata(idx)
	for child in controls_container.get_children():
		if child.has_method("show_if_named"):
			child.show_if_named(ctrl_name)

func _on_menu_operation_requested(req : Dictionary) -> void:
	operation_requested.emit(req)


