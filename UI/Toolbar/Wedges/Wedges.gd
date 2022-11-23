extends Control

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal operation_requested(req)

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var slider : HSlider = $HSlider
@onready var slidervalue_label : Label = $SliderValue

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	visible = false

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func show_if_named(op_name : String) -> void:
	if op_name == name:
		operation_requested.emit({
			"op":"Wedge",
			"r": int(slider.value)
		})
		visible = true
	else:
		visible = false

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_h_slider_value_changed(value : float) -> void:
	slidervalue_label.text = "[ %s%s ]"%["0" if value < 10 else "", int(value)]
	operation_requested.emit({
		"op":"Wedge",
		"r": int(value)
	})
