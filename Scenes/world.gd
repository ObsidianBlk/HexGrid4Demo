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
var wedge_edge : int = 0
var wedge_visible : bool = false
var region_radius : int = 1
var line_started : bool = false
var line_pos : HexCell = HexCell.new()

var hexgrid : HexGrid = null

# --------------------------------------------------------------------------------------------------
# Onready Variables
# --------------------------------------------------------------------------------------------------
@onready var camera_node : Camera2D = $Camera2D
@onready var hexgridview : HexGridView = $HexGridView
@onready var toolbar : Control = $UI/Toolbar
@onready var pos_tracker : Control = $UI/PositionTracker

# --------------------------------------------------------------------------------------------------
# Override Methods
# --------------------------------------------------------------------------------------------------
func _ready() -> void:
	hexgridview.connect("origin_changed", _on_origin_changed)
	hexgrid = HexGrid.new()
	hexgrid.orientation = HexCell.ORIENTATION.Flat
	#hexgrid.grid_boundry = HexGrid.BOUND_TYPE.Radial
	#hexgrid.bound_radius = 8
	#hexgrid.grid_boundry = HexGrid.BOUND_TYPE.Rect
	#hexgrid.bound_rect = Rect2(-20, -20, 40, 40)
	#var origin : HexCell = HexCell.new(Vector3i(-20,40,-20), false, hexgrid.orientation)
	#var celllist : Array = origin.get_line_to_qrs(Vector3i(-20,0,20))
	#celllist.append_array(origin.get_line_to_qrs(Vector3i(20,0,-20)))
	#hexgrid.add_region("boundry", celllist, Color.LIGHT_PINK)
	hexgridview.hex_grid = hexgrid


func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var vp : Viewport = get_viewport()
		if vp:
			var fowner = vp.gui_get_focus_owner()
			if fowner:
				fowner.release_focus()
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
				var origin : HexCell = hexgridview.get_origin()
				if event is InputEventMouseButton:
					origin.from_point(get_global_mouse_position() / hexgrid.cell_size)
				hexgrid.replace_region("Region", origin.get_region(region_radius), Color.TOMATO, 1)
			elif event.is_action_pressed("interact_alt"):
				_ClearOp()
		"Wedge":
			var origin : HexCell = hexgridview.get_origin()
			if event.is_action_pressed("interact"):
				wedge_visible = true
				hexgrid.replace_region("Wedge_%s"%[wedge_edge + 1], origin.get_wedge_region(wedge_edge, region_radius), Color.WHEAT)
			elif event.is_action_pressed("cycle_up"):
				hexgrid.remove_region("Wedge_%s"%[wedge_edge + 1])
				wedge_edge = (wedge_edge + 1) % 6
				hexgrid.add_region("Wedge_%s"%[wedge_edge + 1], origin.get_wedge_region(wedge_edge, region_radius), Color.WHEAT)
			elif event.is_action_pressed("cycle_down"):
				hexgrid.remove_region("Wedge_%s"%[wedge_edge + 1])
				wedge_edge = 5 if wedge_edge == 0 else wedge_edge - 1
				hexgrid.add_region("Wedge_%s"%[wedge_edge + 1], origin.get_wedge_region(wedge_edge, region_radius), Color.WHEAT)
			elif event.is_action_pressed("interact_alt"):
				wedge_visible = false
				_ClearOp()
			elif event is InputEventKey:
				var edge : int = -1
				match event.keycode:
					KEY_1:
						edge = 0
					KEY_2:
						edge = 1
					KEY_3:
						edge = 2
					KEY_4:
						edge = 3
					KEY_5:
						edge = 4
					KEY_6:
						edge = 5
				if edge >= 0 and (not wedge_visible or edge != wedge_edge):
					if event.pressed:
						hexgrid.replace_region("Wedge_%s"%[edge + 1], origin.get_wedge_region(edge, region_radius), Color.WHEAT)
					else:
						hexgrid.remove_region("Wedge_%s"%[edge + 1])
		"Line":
			if line_started and event is InputEventMouseMotion:
				var mouse_cell : HexCell = HexCell.new(null, false, hexgrid.orientation)
				mouse_cell.from_point(get_global_mouse_position() / hexgridview.cell_size)
				if not mouse_cell.eq(line_pos):
					hexgrid.replace_region("Line", line_pos.get_line_to_cell(mouse_cell), Color.LIGHT_STEEL_BLUE, 1)
			if event.is_action_pressed("interact"):
				var cell : HexCell = hexgridview.get_origin()
				if event is InputEventMouseButton:
					cell.from_point(get_global_mouse_position() / hexgridview.cell_size)
				if line_started:
					hexgrid.remove_region("Line_Start")
					hexgrid.replace_region("Line", line_pos.get_line_to_cell(cell), Color.ORANGE, 1)
					line_started = false
				else:
					line_started = true
					line_pos = cell
					hexgrid.add_region("Line_Start", [cell], Color.ORANGE, 2)
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
			var cell : HexCell = hexgridview.get_origin()
			cell.from_point(camera_node.global_position / hexgridview.cell_size)
			hexgrid.replace_region("Line", line_pos.get_line_to_cell(cell), Color.LIGHT_STEEL_BLUE, 1)
		if operation_mode == "Wedge":
			_WedgeAtOrigin()


# --------------------------------------------------------------------------------------------------
# Private Methods
# --------------------------------------------------------------------------------------------------
func _WedgeAtOrigin() -> void:
	if wedge_visible:
		var origin : HexCell = hexgridview.get_origin()
		for i in range(6):
			if hexgrid.has_region("Wedge_%s"%[i+1]):
				hexgrid.replace_region("Wedge_%s"%[i + 1], origin.get_wedge_region(i, region_radius), Color.WHEAT)

func _ClearOp() -> void:
	match operation_mode:
		"Region":
			hexgrid.remove_region("Region")
		"Wedge":
			hexgrid.remove_region("Wedge_1")
			hexgrid.remove_region("Wedge_2")
			hexgrid.remove_region("Wedge_3")
			hexgrid.remove_region("Wedge_4")
			hexgrid.remove_region("Wedge_5")
			hexgrid.remove_region("Wedge_6")
			wedge_visible = false
		"Line":
			hexgrid.remove_region("Line_start")
			hexgrid.remove_region("Line")
			line_started = false

# --------------------------------------------------------------------------------------------------
# Handler Methods
# --------------------------------------------------------------------------------------------------
func _on_origin_changed(origin : HexCell) -> void:
	pos_tracker.set_position_hex(origin)

func _on_toolbar_operation_requested(req) -> void:
	if "op" in req:
		if req["op"] != operation_mode:
			_ClearOp()
			operation_mode = req["op"]
		match req["op"]:
			"Region", "Wedge":
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



