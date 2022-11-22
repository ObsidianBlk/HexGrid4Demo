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

var operation_mode : String = ""
var region_radius : int = 1
var line_started : bool = false
var line_pos : HexCell = HexCell.new()

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

	match operation_mode:
		"Region":
			if event.is_action_pressed("interact"):
				var origin : HexCell = hexgrid.get_origin()
				if event is InputEventMouseButton:
					origin.from_point(get_global_mouse_position() / hexgrid.cell_size)
				hexgrid.replace_highlight_region("Region", origin.get_region(region_radius), Color.TOMATO, 1)
			elif event.is_action_pressed("interact_alt"):
				_ClearOp()
		"Line":
			if line_started and event is InputEventMouseMotion:
				var mouse_cell : HexCell = HexCell.new(null, false, hexgrid.cell_orientation)
				mouse_cell.from_point(get_global_mouse_position() / hexgrid.cell_size)
				if not mouse_cell.eq(line_pos):
					hexgrid.replace_highlight_region("Line", line_pos.get_line_to_cell(mouse_cell), Color.LIGHT_STEEL_BLUE, 1)
			if event.is_action_pressed("interact"):
				var cell : HexCell = hexgrid.get_origin()
				if event is InputEventMouseButton:
					cell.from_point(get_global_mouse_position() / hexgrid.cell_size)
				if line_started:
					hexgrid.remove_highlight_region("Line_Start")
					hexgrid.replace_highlight_region("Line", line_pos.get_line_to_cell(cell), Color.ORANGE, 1)
					line_started = false
				else:
					line_started = true
					line_pos = cell
					hexgrid.add_highlight_region("Line_Start", [cell], Color.ORANGE, 2)
			elif event.is_action_pressed("interact_alt"):
				_ClearOp()

func _draw():
	draw_line(Vector2(-10, 0), Vector2(10, 0), Color.AZURE)
	draw_line(Vector2(0, -10), Vector2(0, 10), Color.AZURE)

func _physics_process(delta : float) -> void:
	var dir : Vector2 = _dir_br - _dir_tl
	if dir.length_squared() > 0.1:
		camera_node.global_position += dir * CAMERA_SPEED * delta
		if operation_mode == "Line" and line_started:
			var cell : HexCell = hexgrid.get_origin()
			cell.from_point(camera_node.global_position / hexgrid.cell_size)
			hexgrid.replace_highlight_region("Line", line_pos.get_line_to_cell(cell), Color.LIGHT_STEEL_BLUE, 1)


# --------------------------------------------------------------------------------------------------
# Private Methods
# --------------------------------------------------------------------------------------------------
func _ClearOp() -> void:
	match operation_mode:
		"Region":
			hexgrid.remove_highlight_region("Region")
		"Line":
			hexgrid.remove_highlight_region("Line_start")
			hexgrid.remove_highlight_region("Line")
			line_started = false

# --------------------------------------------------------------------------------------------------
# Handler Methods
# --------------------------------------------------------------------------------------------------

func _on_toolbar_operation_requested(req):
	if "op" in req:
		if req["op"] != operation_mode:
			_ClearOp()
			operation_mode = req["op"]
			match req["op"]:
				"Region":
					if "r" in req:
						region_radius = req["r"]
				"Line":
					pass # Technically taken care of already :D
				_:
					operation_mode = ""
	if "cmd" in req:
		match req["cmd"]:
			"full_grid":
				if "enable" in req:
					hexgrid.enable_base_grid = req["enable"]



