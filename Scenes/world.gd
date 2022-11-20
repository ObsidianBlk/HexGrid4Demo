extends Node2D


# --------------------------------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------------------------------
const CAMERA_SPEED : float = 100.0

# --------------------------------------------------------------------------------------------------
# Variables
# --------------------------------------------------------------------------------------------------
var _dir_tl : Vector2 = Vector2.ZERO
var _dir_br : Vector2 = Vector2.ZERO

# --------------------------------------------------------------------------------------------------
# Onready Variables
# --------------------------------------------------------------------------------------------------
@onready var camera_node : Camera2D = $Camera2D
@onready var hexgrid : HexGrid = $HexGrid

# --------------------------------------------------------------------------------------------------
# Override Methods
# --------------------------------------------------------------------------------------------------
func _ready() -> void:
	var cell : HexCell = HexCell.Pointy()
	print("Pointy: ", cell.as_string())
	var cell2 : HexCell = HexCell.Flat()
	print("Flat: ", cell2.as_string())


func _unhandled_input(event : InputEvent) -> void:
	if event.is_action("camera_left", true):
		_dir_tl.x = event.get_action_strength("camera_left")
	elif event.is_action("camera_right", true):
		_dir_br.x = event.get_action_strength("camera_right")
	elif event.is_action("camera_up", true):
		_dir_tl.y = event.get_action_strength("camera_up")
	elif event.is_action("camera_down", true):
		_dir_br.y = event.get_action_strength("camera_down") 

func _draw():
	draw_line(Vector2(-10, 0), Vector2(10, 0), Color.AZURE)
	draw_line(Vector2(0, -10), Vector2(0, 10), Color.AZURE)

func _physics_process(delta : float) -> void:
	var dir : Vector2 = _dir_br - _dir_tl
	if dir.length_squared() > 0.1:
		camera_node.global_position += dir * CAMERA_SPEED * delta

# --------------------------------------------------------------------------------------------------
# Handler Methods
# --------------------------------------------------------------------------------------------------

func _on_main_operation_requested(req : Dictionary) -> void:
	if "op" in req:
		match req["op"]:
			"region_create":
				if "r" in req and typeof(req["r"]) == TYPE_INT and req["r"] > 0:
					var origin : HexCell = hexgrid.get_origin()
					if not hexgrid.has_highlight_region("demo_region"):
						hexgrid.add_highlight_region("demo_region", origin.get_region(req["r"]), Color.TOMATO)
					else:
						hexgrid.change_highlight_region_cells("demo_region", origin.get_region(req["r"]))
			"region_remove":
				hexgrid.remove_highlight_region("demo_region")
