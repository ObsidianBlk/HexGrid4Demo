extends Control


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal operation_requested(req)

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var region_radius : HSlider = $RegionRadius/HSlider
@onready var region_value_label : Label = $RegionRadius/SLabel/Value


# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	visible = false

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func show_if_named(req_name : String) -> void:
	if name == req_name:
		visible = true
	else:
		visible = false

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_RegionRadius_value_changed(value : float):
	region_value_label.text = "%s"%[int(value)]

func _on_create_pressed():
	operation_requested.emit({
		"op": "region_create",
		"r": int(region_radius.value)
	})

func _on_clear_pressed():
	operation_requested.emit({"op": "region_remove"})
