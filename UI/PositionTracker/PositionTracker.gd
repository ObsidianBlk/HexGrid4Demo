extends Control

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var qrs_value : Label = $MC/HBC/QRS/Value
@onready var xy_value : Label = $MC/HBC/Pixel/Value

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func set_position_hex(cell : HexCell) -> void:
	var qrs : Vector3i = cell.qrs
	var pos : Vector2 = cell.to_point()
	
	if qrs_value:
		qrs_value.text = "%s,%s,%s"%[qrs.x, qrs.z, qrs.y]
	if xy_value:
		xy_value.text = "%s,%s"%[pos.x, pos.y]
