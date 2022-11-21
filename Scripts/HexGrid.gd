@tool
extends Node2D
class_name HexGrid


# ------------------------------------------------------------------------------
# Internal Class
# ------------------------------------------------------------------------------
class Edge:
	var from : Vector2 = Vector2.ZERO
	var to : Vector2 = Vector2.ZERO
	var owners : Dictionary = {}
	var _last_draw_frame : int = -1
	
	func _init(a : Vector2, b : Vector2):
		if a.x > b.x or a.y > b.y:
			from = a
			to = b
		else:
			from = b
			to = a
	
	func draw(surf : CanvasItem, offset : Vector2, color : Color, width : float = 1.0) -> void:
		var cframe : int = Engine.get_process_frames()
		if cframe == _last_draw_frame:
			return # We've already been drawn!
		_last_draw_frame = cframe
		surf.draw_line(from + offset, to + offset, color, width)
	
	func add_owner(cell : HexCell) -> void:
		if not cell.qrs in owners:
			owners[cell.qrs] = cell
	
	func get_name() -> String:
		return "%s<>%s"%[from, to]


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal origin_changed(origin)
signal region_added(region_name)
signal region_removed(region_name)
signal region_changed(region_name)

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const HR_CELLS : StringName = &"cells"
const HR_COLOR : StringName = &"color"
const HR_PRIORITY : StringName = &"priority"
const RAD_60 : float = deg_to_rad(60.0)

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export_category("HexGrid")
@export var cell_orientation : HexCell.ORIENTATION = HexCell.ORIENTATION.Pointy : set = set_cell_orientation
@export var cell_size : int = 1 : 									set = set_cell_size
@export_range(0.0, 1.0) var grid_color_edge_alpha : float = 0.1 :	set = set_grid_color_edge_alpha
@export var enable_base_grid : bool = true :						set = set_enable_base_grid
@export var base_grid_range : int = 20 : 							set = set_base_grid_range
@export var base_grid_color : Color = Color.AQUAMARINE : 			set = set_base_grid_color
@export var enable_cursor : bool = true : 							set = set_enable_cursor
@export var cursor_color : Color = Color.YELLOW : 					set = set_cursor_color
@export var cursor_region_priority : int = 100
@export var enable_focus_dot : bool = true : 							set = set_enable_focus_dot
@export var focus_dot_color : Color = Color.RED : 					set = set_focus_dot_color
@export_node_path(Camera2D) var target_camera_path : NodePath = ""

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _grid_origin : HexCell = HexCell.new()
var _highlight_regions : Dictionary = {}
var _active_cells : Dictionary = {}
var _grid_data : Dictionary = {}

var _target_camera : WeakRef = weakref(null)

# ------------------------------------------------------------------------------
# Setters / Getters
# ------------------------------------------------------------------------------
func set_cell_orientation(o : int) -> void:
	if HexCell.ORIENTATION.values().find(o) >= 0:
		if cell_orientation != o:
			cell_orientation = o
			_UpdateCellOrientation(cell_orientation)

func set_cell_size(s : int) -> void:
	if s > 0:
		cell_size = s
		_BuildGridData()
		#queue_redraw()

func set_base_grid_range(r : int) -> void:
	if r > 0:
		base_grid_range = r
		_BuildGridData()
		#queue_redraw()

func set_enable_base_grid(e : bool) -> void:
	if enable_base_grid != e:
		enable_base_grid = e
		_BuildGridData()
		#queue_redraw()

func set_base_grid_color(c : Color) -> void:
	base_grid_color = c
	queue_redraw()

func set_grid_color_edge_alpha(a : float) -> void:
	if a >= 0.0 and a <= 1.0:
		grid_color_edge_alpha = a
		queue_redraw()

func set_target_camera_path(tp : NodePath) -> void:
	target_camera_path = tp
	_CheckTargetCamera()

func set_enable_cursor(enable : bool) -> void:
	if enable_cursor != enable:
		enable_cursor = enable
		if enable_cursor:
			_AddCursorHighlightRegion()
		else:
			remove_highlight_region("cursor")
		_BuildGridData()

func set_cursor_color(c : Color) -> void:
	cursor_color = c
	queue_redraw()

func set_cursor_region_priority(p : int) -> void:
	cursor_region_priority = p
	change_highlight_region_priority("cursor", cursor_region_priority)

func set_enable_focus_dot(show : bool) -> void:
	if enable_focus_dot != show:
		enable_focus_dot = show
		queue_redraw()

func set_focus_dot_color(c : Color) -> void:
	focus_dot_color = c
	queue_redraw()

# ------------------------------------------------------------------------------
# Override methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	_CheckTargetCamera()
	if enable_cursor:
		_AddCursorHighlightRegion()
	if _grid_origin.orientation != cell_orientation:
		_UpdateCellOrientation(cell_orientation)
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process(false)

func _draw() -> void:
	var offset = _grid_origin.to_point() * cell_size
	for e in _grid_data.values():
		var color : Color = base_grid_color
		var region_name : StringName = _GetEdgeDominantRegion(e)
		if region_name != &"":
			color = _highlight_regions[region_name][HR_COLOR]
			e.draw(self, offset, color)
		elif enable_base_grid:
			e.draw(self, offset, color)
#	for item in _grid_data:
#		var color : Color = base_grid_color
#		if item[1] != &"":
#			color = _highlight_regions[item[1]][HR_COLOR]
#		if grid_color_edge_alpha < 1.0:
#			color.a = lerp(1.0, grid_color_edge_alpha, item[2] / base_grid_range)
#		draw_polyline(item[0], color, 1.0, true)
	
	if enable_focus_dot:
		var target = _target_camera.get_ref()
		if target:
			draw_circle(target.global_position, 2.0, focus_dot_color)


func _physics_process(_delta : float) -> void:
	var target = _target_camera.get_ref()
	if target:
		_SetOriginFromPoint(target.global_position, true)

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _CheckTargetCamera() -> void:
	if target_camera_path == NodePath(""):
		if _target_camera.get_ref() != null:
			_target_camera = weakref(null)
	else:
		var target = get_node_or_null(target_camera_path)
		if target != _target_camera.get_ref():
			_target_camera = weakref(target)

func _AddCursorHighlightRegion() -> void:
	var origin : HexCell = HexCell.new()
	origin.orientation = cell_orientation
	if _target_camera.get_ref() != null:
		origin.from_point(_target_camera.get_ref().global_position)
	add_highlight_region("cursor", [origin], cursor_color, cursor_region_priority)

func _UpdateCellOrientation(o : int) -> void:
	_grid_origin.orientation = o
	_BuildGridData()


func _ActivateCellRegion(cell : HexCell, region_name : StringName, priority : int) -> void:
	if not region_name in _highlight_regions:
		return
	if not cell.qrs in _active_cells:
		_active_cells[cell.qrs] = {}
	if not priority in _active_cells[cell.qrs]:
		_active_cells[cell.qrs][priority] = []
	_active_cells[cell.qrs][priority].append(region_name)

func _DeactivateCellRegion(cell : HexCell, region_name : StringName, priority : int) -> void:
	if not region_name in _highlight_regions:
		return
	if not cell.qrs in _active_cells:
		return
	if priority in _active_cells[cell.qrs]:
		var idx : int = _active_cells[cell.qrs][priority].find(region_name)
		if idx >= 0:
			_active_cells[cell.qrs][priority].remove_at(idx)
			if _active_cells[cell.qrs][priority].size() <= 0:
				_active_cells[cell.qrs].erase(priority)
				if _active_cells[cell.qrs].size() <= 0:
					_active_cells.erase(cell.qrs)

func _GetEdgeDominantRegion(e : Edge) -> StringName:
	var owners : Array = e.owners.values()
	var highest_cell : HexCell = HexCell.new()
	var highest_priority : int = -1
	for cell in owners:
		var ocell : HexCell = HexCell.new(cell.qrs + _grid_origin.qrs, false, cell_orientation)
		var priority = _GetCellPriority(ocell)
		if priority > highest_priority:
			highest_priority = priority
			highest_cell = ocell
	if highest_priority >= 0:
		return _active_cells[highest_cell.qrs][highest_priority][0]
	return &""


func _GetCellPriority(cell : HexCell) -> int:
	if cell.qrs in _active_cells:
		var priorities : Array = _active_cells[cell.qrs].keys()
		priorities.sort()
		return priorities[priorities.size() - 1]
	return -1


func _GetCellActiveRegion(cell : HexCell) -> StringName:
	var priority = _GetCellPriority(cell)
	if priority >= 0:
		return _active_cells[cell.qrs][priority][0]
	return &""


func _BuildGridData() -> void:
	_grid_data.clear()
	var origin : HexCell = HexCell.new(null, false, cell_orientation)
	for cell in origin.get_region(base_grid_range):
		_HexToGridData(cell)
	queue_redraw()

func _StoreEdgeOwner(cell : HexCell, from : Vector2, to : Vector2) -> void:
	var e : Edge = Edge.new(from, to)
	var edge_name : String = e.get_name()
	if not edge_name in _grid_data:
		_grid_data[edge_name] = e
	_grid_data[edge_name].add_owner(cell)

func _HexToGridData(cell : HexCell) -> void:
	var pos : Vector2 = cell.to_point()
	var offset : Vector2 = pos * cell_size
	if cell.qrs == Vector3i.ZERO:
		print("Here we begin!")
	var point : Vector2 = Vector2(0, -cell_size) if cell.orientation == HexCell.ORIENTATION.Pointy else Vector2(-cell_size, 0)
	var last_point : Vector2 = point + offset
	for i in range(1, 6):
		var rad = RAD_60 * i
		var npoint : Vector2 = point.rotated(rad) + offset
		_StoreEdgeOwner(cell, last_point, npoint)
		last_point = npoint
	_StoreEdgeOwner(cell, last_point, point + offset)

#func _BuildGridData() -> void:
#	_grid_data.clear()
#	var region_cells : Dictionary = {}
#	for cell in _grid_origin.get_region(base_grid_range):
#		var hr : StringName = _GetCellHighlightRegion(cell)
#		if hr != &"":
#			if not hr in region_cells:
#				region_cells[hr] = []
#			region_cells[hr].append(cell)
#		elif enable_base_grid:
#			_grid_data.append([_HexToPackedArray(cell, cell_size), &"", _grid_origin.distance_to(cell)])
#	if not region_cells.is_empty():
#		var keys : Array = region_cells.keys()
#		keys.sort_custom(func(a : StringName, b : StringName):
#			return _highlight_regions[a][HR_PRIORITY] < _highlight_regions[b][HR_PRIORITY]
#		)
#		for key in keys:
#			for cell in region_cells[key]:
#				_grid_data.append([_HexToPackedArray(cell, cell_size), key, _grid_origin.distance_to(cell)])
#	queue_redraw()

#func _HexToPackedArray(cell : HexCell, size : float) -> PackedVector2Array:
#	var pos : Vector2 = cell.to_point()
#	var points : Array = []
#	var point : Vector2 = Vector2(0, -size) if cell.orientation == 0 else Vector2(-size, 0)
#	var offset : Vector2 = pos * size
#	points.append(point + offset)
#	for i in range(1, 6):
#		var rad = RAD_60 * i
#		points.append(point.rotated(rad) + offset)
#	points.append(point + offset)
#	return PackedVector2Array(points)

func _SetOriginFromPoint(p : Vector2, set_as_cursor : bool = false) -> void:
	var new_origin : HexCell = HexCell.new(p / cell_size, true, cell_orientation)
	if not new_origin.eq(_grid_origin):
		_grid_origin = new_origin
		if set_as_cursor and enable_cursor:
			change_highlight_region_cells("cursor", [new_origin])
		origin_changed.emit(_grid_origin.clone())
	queue_redraw()

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func set_origin_cell(origin : HexCell) -> void:
	if _target_camera.get_ref() != null:
		return # Only update the origin this way if we have no target camera.
	
	if origin.is_valid() and not origin.eq(_grid_origin):
		_grid_origin = origin
		if _grid_origin.orientation != cell_orientation:
			_grid_origin.orientation = cell_orientation
		queue_redraw()
		origin_changed.emit(_grid_origin.clone())

func set_origin_from_point(p : Vector2) -> void:
	if _target_camera.get_ref() != null:
		return # Only update the origin this way if we have no target camera.
	set_origin_cell(HexCell.new(p / cell_size, true, cell_orientation))

func get_origin() -> HexCell:
	return _grid_origin.clone()

func add_highlight_region(region_name : StringName, cells : Array, color : Color = Color.BISQUE, priority : int = 0) -> int:
	if region_name in _highlight_regions:
		return ERR_ALREADY_EXISTS
		
	_highlight_regions[region_name] = {HR_CELLS: cells, HR_COLOR: color, HR_PRIORITY:priority}
	for cell in cells:
		_ActivateCellRegion(cell, region_name, priority)
	queue_redraw()
	region_added.emit(region_name)
	return OK

func remove_highlight_region(region_name : StringName) -> void:
	if region_name in _highlight_regions:
		var priority : int = _highlight_regions[region_name][HR_PRIORITY]
		for cell in _highlight_regions[region_name][HR_CELLS]:
			_DeactivateCellRegion(cell, region_name, priority)
		_highlight_regions.erase(region_name)
		queue_redraw()
		region_removed.emit(region_name)

func has_highlight_region(region_name : StringName) -> bool:
	return region_name in _highlight_regions

func change_highlight_region_cells(region_name : StringName, cells : Array) -> void:
	if region_name in _highlight_regions:
		var priority : int = _highlight_regions[region_name][HR_PRIORITY]
		for cell in _highlight_regions[region_name][HR_CELLS]:
			_DeactivateCellRegion(cell, region_name, priority)
		_highlight_regions[region_name][HR_CELLS] = cells
		for cell in _highlight_regions[region_name][HR_CELLS]:
			_ActivateCellRegion(cell, region_name, priority)
		queue_redraw()
		region_changed.emit(region_name)

func change_highlight_region_color(region_name : StringName, color : Color) -> void:
	if region_name in _highlight_regions:
		_highlight_regions[region_name][HR_COLOR] = color
		queue_redraw()
		region_changed.emit(region_name)

func change_highlight_region_priority(region_name : StringName, priority : int) -> void:
	if region_name in _highlight_regions:
		if _highlight_regions[region_name][HR_PRIORITY] != priority:
			var old_priority : int = _highlight_regions[region_name][HR_PRIORITY]
			for cell in _highlight_regions[region_name][HR_CELLS]:
				_DeactivateCellRegion(cell, region_name, old_priority)
				_ActivateCellRegion(cell, region_name, priority)
			_highlight_regions[region_name][HR_PRIORITY] = priority
			queue_redraw()
			region_changed.emit(region_name)


