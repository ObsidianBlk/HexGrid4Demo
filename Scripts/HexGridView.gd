@tool
extends Node2D
class_name HexGridView


# ------------------------------------------------------------------------------
# Internal Class
# ------------------------------------------------------------------------------
class Edge:
	var from : Vector2 = Vector2.ZERO
	var to : Vector2 = Vector2.ZERO
	var owners : Array = []
	
	func _init(a : Vector2, b : Vector2):
		if a.x > b.x or a.y > b.y:
			from = a
			to = b
		else:
			from = b
			to = a
	
	func draw(surf : CanvasItem, offset : Vector2, color : Color, width : float = 1.0) -> void:
		surf.draw_line(from + offset, to + offset, color, width)
	
	func add_owner(cell : HexCell) -> void:
		if not cell.qrs in owners:
			owners.append(cell.qrs)
	
	func dist_to_center() -> float:
		var vmid : Vector2 = to - from
		vmid = from + (vmid * 0.5)
		return vmid.distance_to(Vector2.ZERO)


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal origin_changed(new_origin)

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const RAD_60 : float = deg_to_rad(60.0)

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export_category("HexGridView")
@export var hex_grid : HexGrid = null :								set = set_hex_grid
@export var cell_size : int = 1 : 									set = set_cell_size
@export var grid_alpha_curve : Curve = null
@export var enable_base_grid : bool = true :						set = set_enable_base_grid
@export var base_grid_range : int = 20 : 							set = set_base_grid_range
@export var base_grid_color : Color = Color.AQUAMARINE : 			set = set_base_grid_color
@export var enable_cursor : bool = true : 							set = set_enable_cursor
@export var cursor_color : Color = Color.YELLOW : 					set = set_cursor_color
@export var cursor_region_priority : int = 100

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _grid_origin : HexCell = HexCell.new()
var _scratch_cell : HexCell = HexCell.new()
var _grid_data : Dictionary = {
	"cells": {},
	"edges": []
}

# ------------------------------------------------------------------------------
# Setters / Getters
# ------------------------------------------------------------------------------
func set_hex_grid(hg : HexGrid) -> void:
	if hex_grid != null:
		hex_grid.disconnect("orientation_changed", _on_orientation_changed)
		hex_grid.disconnect("bounds_updated", _on_bounds_updated)
		hex_grid.disconnect("region_added", _on_region_added)
		hex_grid.disconnect("region_removed", _on_region_removed)
		hex_grid.disconnect("region_changed", _on_region_changed)
	hex_grid = hg
	if hex_grid != null:
		hex_grid.connect("orientation_changed", _on_orientation_changed)
		hex_grid.connect("bounds_updated", _on_bounds_updated)
		hex_grid.connect("region_added", _on_region_added)
		hex_grid.connect("region_removed", _on_region_removed)
		hex_grid.connect("region_changed", _on_region_changed)
		
		_UpdateCellOrientation()
		if enable_cursor:
			_AddCursorHighlightRegion()
		_BuildGridData()


func set_cell_size(s : int) -> void:
	if s > 0:
		cell_size = s
		_BuildGridData()

func set_base_grid_range(r : int) -> void:
	if r > 0:
		base_grid_range = r
		_BuildGridData()

func set_enable_base_grid(e : bool) -> void:
	if enable_base_grid != e:
		enable_base_grid = e
		queue_redraw()

func set_base_grid_color(c : Color) -> void:
	base_grid_color = c
	queue_redraw()

func set_enable_cursor(enable : bool) -> void:
	if enable_cursor != enable:
		enable_cursor = enable
		if enable_cursor:
			_AddCursorHighlightRegion()
		elif hex_grid != null:
			hex_grid.remove_region("cursor")
		queue_redraw()

func set_cursor_color(c : Color) -> void:
	cursor_color = c
	queue_redraw()

func set_cursor_region_priority(p : int) -> void:
	cursor_region_priority = p
	if hex_grid != null:
		hex_grid.change_region_priority("cursor", cursor_region_priority)

# ------------------------------------------------------------------------------
# Override methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	if enable_cursor:
		_AddCursorHighlightRegion()
	_UpdateCellOrientation()
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process(false)

func _draw() -> void:
	if hex_grid == null:
		return
	
	var offset = _grid_origin.to_point() * cell_size
	for e in _grid_data.edges:
		if not _IsEdgeVisible(e):
			continue
		
		var alpha : float = 1.0
		if grid_alpha_curve != null:
			alpha = max(0.0, min(1.0, ((e.dist_to_center() / cell_size) / (base_grid_range * 1.7) )))
			alpha = grid_alpha_curve.sample(alpha)
		if alpha > 0.0:
			var color : Color = base_grid_color
			var region_name : StringName = _GetEdgeDominantRegion(e)
			var process = enable_base_grid or region_name != &""
			if region_name != &"":
				color = hex_grid.get_region_color(region_name)
			if process:
				color.a = alpha
				e.draw(self, offset, color)

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------

func _AddCursorHighlightRegion() -> void:
	if hex_grid != null:
		hex_grid.add_region("cursor", [_grid_origin.clone()], cursor_color, cursor_region_priority)

func _UpdateCellOrientation() -> void:
	if hex_grid != null:
		if hex_grid.orientation != _grid_origin.orientation:
			_scratch_cell.orientation = hex_grid.orientation
			_grid_origin.orientation = hex_grid.orientation
			_BuildGridData()

func _IsEdgeVisible(e : Edge) -> bool:
	for cell_qrs in e.owners:
		_scratch_cell.set_qrs(cell_qrs + _grid_origin.qrs)
		if hex_grid.cell_in_bounds(_scratch_cell):
			return true
	return false


func _GetEdgeDominantRegion(e : Edge) -> StringName:
	var highest_qrs : Vector3i = Vector3i.ZERO
	var highest_priority : int = -1
	for cell_qrs in e.owners:
		var qrs : Vector3i = cell_qrs + _grid_origin.qrs
		var priority = hex_grid.get_qrs_priority(qrs)
		if priority > highest_priority:
			highest_priority = priority
			highest_qrs = qrs
	if highest_priority >= 0:
		return hex_grid.get_qrs_active_region(highest_qrs, highest_priority)
	return &""


func _AddCellToGrid(cell : HexCell) -> void:
	if not cell.qrs in _grid_data.cells:
		_grid_data.cells[cell.qrs] = [null, null, null, null, null, null]

func _BuildGridData() -> void:
	if hex_grid == null:
		return
	
	_grid_data.edges.clear()
	var origin : HexCell = HexCell.new(null, false, hex_grid.orientation)
	var region : Array = origin.get_region(base_grid_range)
	for cell in region:
		_HexToGridData(cell)
	_grid_data.cells.clear()
	queue_redraw()

func _StoreEdge(cell : HexCell, eid : int, from : Vector2, to : Vector2) -> void:
	var e : Edge = Edge.new(from, to)
	var eidx : int = -1
	if _grid_data.cells[cell.qrs][eid] == null:
		eidx = _grid_data.edges.size()
		_grid_data.cells[cell.qrs][eid] = eidx
		_grid_data.edges.append(e)
		e.add_owner(cell)
	else:
		eidx = _grid_data.cells[cell.qrs][eid]
	
	var ncell : HexCell = cell.get_neighbor(eid)
	_AddCellToGrid(ncell)
	var neid : int = (eid + 3) % 6
	if _grid_data.cells[ncell.qrs][neid] == null:
		_grid_data.cells[ncell.qrs][neid] = eidx
		_grid_data.edges[eidx].add_owner(ncell)

func _HexToGridData(cell : HexCell) -> void:
	_AddCellToGrid(cell)
	var pos : Vector2 = cell.to_point()
	var offset : Vector2 = pos * cell_size
	var eid : int = 4 if cell.orientation == HexCell.ORIENTATION.Pointy else 2 # It is known... lol
	var point : Vector2 = Vector2(0, -cell_size) if cell.orientation == HexCell.ORIENTATION.Pointy else Vector2(-cell_size, 0)
	var last_point : Vector2 = point + offset
	for i in range(1, 6):
		var rad = RAD_60 * i
		var npoint : Vector2 = point.rotated(rad) + offset
		_StoreEdge(cell, eid, last_point, npoint)
		eid = (eid + 1) % 6
		last_point = npoint
	_StoreEdge(cell, eid, last_point, point + offset)


# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func set_origin_cell(origin : HexCell) -> void:
	if origin.is_valid() and not origin.eq(_grid_origin):
		_grid_origin.qrs = origin.qrs
		if hex_grid != null:
			if enable_cursor:
				hex_grid.change_region_cells("cursor", [_grid_origin.clone()])
			queue_redraw()
		origin_changed.emit(_grid_origin.clone())

func set_origin_from_point(p : Vector2) -> void:
	_scratch_cell.from_point(p / cell_size)
	set_origin_cell(_scratch_cell)

func get_origin() -> HexCell:
	return _grid_origin.clone()

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
# Yes... I realize how repeatative these handlers are. This was whipped quick. May go back and
# optimize all of this later!
func _on_orientation_changed(_new_orientation : HexCell.ORIENTATION) -> void:
	_UpdateCellOrientation()
	queue_redraw()

func _on_region_added(_region_name : StringName) -> void:
	queue_redraw()

func _on_region_removed(_region_name : StringName) -> void:
	queue_redraw()

func _on_region_changed(_region_name : StringName) -> void:
	queue_redraw()

func _on_bounds_updated() -> void:
	queue_redraw()


