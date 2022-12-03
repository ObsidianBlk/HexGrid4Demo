extends Resource
class_name HexGrid


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal orientation_changed(new_orientation)
signal bounds_updated()
signal region_added(region_name)
signal region_removed(region_name)
signal region_changed(region_name)

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const _R_CELLS : StringName = &"cells"
const _R_COLOR : StringName = &"color"
const _R_PRIORITY : StringName = &"priority"

enum BOUND_TYPE {None=0, Radial=1, Rect=2}

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export_category("HexGrid")
@export var orientation : HexCell.ORIENTATION = HexCell.ORIENTATION.Pointy :	set = set_orientation
@export var grid_boundry : BOUND_TYPE = BOUND_TYPE.None :						set = set_grid_boundry
@export var bound_radius : int = 1 :											set = set_bound_radius
@export var bound_rect : Rect2 = Rect2() :										set = set_bound_rect
@export var rect_cell_count : bool = true :										set = set_rect_cell_count

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _origin : HexCell = HexCell.new()
var _regions : Dictionary = {}
var _active_cells : Dictionary = {}

var _actual_bound_rect : Rect2 = Rect2()

# ------------------------------------------------------------------------------
# Setters / Getters
# ------------------------------------------------------------------------------
func set_orientation(o : HexCell.ORIENTATION) -> void:
	orientation = o
	_origin.orientation = o
	orientation_changed.emit(orientation)

func set_grid_boundry(b : BOUND_TYPE) -> void:
	grid_boundry = b
	_UpdateBoundRect()
	bounds_updated.emit()

func set_bound_radius(r : int) -> void:
	if r > 0:
		bound_radius = r
		if grid_boundry == BOUND_TYPE.Radial:
			bounds_updated.emit()

func set_bound_rect(r : Rect2) -> void:
	bound_rect = r
	if grid_boundry == BOUND_TYPE.Rect:
		_UpdateBoundRect()
		bounds_updated.emit()

func set_rect_cell_count(e : bool) -> void:
	rect_cell_count = e
	if grid_boundry == BOUND_TYPE.Rect:
		_UpdateBoundRect()
		bounds_updated.emit()

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _UpdateBoundRect() -> void:
	if rect_cell_count:
		if bound_rect.size.x <= 0 or bound_rect.size.y <= 0:
			return
		
		var vdir : int = 0
		var hdir : int = 5
		var origin : HexCell = HexCell.new(bound_rect.position, false, orientation)
		print("Origin: ", origin.qrs)
		var position : Vector2 = origin.to_point()
		var lr : Vector2 = Vector2.ZERO
		
		# Calculating vertical bounds
		var cell : HexCell = origin.get_neighbor(vdir, int(bound_rect.size.y))
		print("Y Cell: ", cell.qrs)
		var point : Vector2 = cell.to_point()
		lr.y = point.y
		cell = origin.get_neighbor(hdir, int(bound_rect.size.x))
		print("X Cell: ", cell.qrs)
		point = cell.to_point()
		lr.x = point.x
		
		_actual_bound_rect = Rect2(position, lr - position)
		print("Rect: ", _actual_bound_rect)
	else:
		_actual_bound_rect = bound_rect

func _IsWithinRect(cell : HexCell) -> bool:
	return _actual_bound_rect.has_point(cell.to_point())

func _IsWithinRadius(cell : HexCell) -> bool:
	#sreturn cell.distance_to(HexCell.new()) <= bound_radius
	return cell.distance_to(_origin) <= bound_radius

func _ActivateCellRegion(cell : HexCell, region_name : StringName, priority : int) -> void:
	if not region_name in _regions:
		return
	if not cell_in_bounds(cell):
		return # Outside the currently defined bounds.
	if not cell.qrs in _active_cells:
		_active_cells[cell.qrs] = {}
	if not priority in _active_cells[cell.qrs]:
		_active_cells[cell.qrs][priority] = []
	_active_cells[cell.qrs][priority].append(region_name)

func _DeactivateCellRegion(cell : HexCell, region_name : StringName, priority : int) -> void:
	if not region_name in _regions:
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

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func cell_in_bounds(cell : HexCell) -> bool:
	match grid_boundry:
		BOUND_TYPE.Radial:
			return _IsWithinRadius(cell)
		BOUND_TYPE.Rect:
			return _IsWithinRect(cell)
	return true

func get_qrs_priority(qrs : Vector3i) -> int:
	if qrs in _active_cells:
		var priorities : Array = _active_cells[qrs].keys()
		priorities.sort()
		return priorities[priorities.size() - 1]
	return -1

func get_cell_priority(cell : HexCell) -> int:
	return get_qrs_priority(cell.qrs)

func get_qrs_active_region(qrs : Vector3i, priority : int = -1) -> StringName:
	if priority < 0:
		priority = get_qrs_priority(qrs)
	if priority >= 0:
		return _active_cells[qrs][priority][0]
	return &""

func get_cell_active_region(cell : HexCell, priority : int = -1) -> StringName:
	return get_qrs_active_region(cell.qrs, priority)

func add_region(region_name : StringName, cells : Array, color : Color = Color.BISQUE, priority : int = 0) -> int:
	if region_name in _regions:
		return ERR_ALREADY_EXISTS
		
	_regions[region_name] = {_R_CELLS: cells, _R_COLOR: color, _R_PRIORITY:priority}
	for cell in cells:
		_ActivateCellRegion(cell, region_name, priority)
	region_added.emit(region_name)
	return OK

func remove_region(region_name : StringName) -> void:
	if region_name in _regions:
		var priority : int = _regions[region_name][_R_PRIORITY]
		for cell in _regions[region_name][_R_CELLS]:
			_DeactivateCellRegion(cell, region_name, priority)
		_regions.erase(region_name)
		region_removed.emit(region_name)

func replace_region(region_name : StringName, cells : Array, color : Color = Color.BISQUE, priority : int = 0) -> int:
	remove_region(region_name)
	return add_region(region_name, cells, color, priority)

func has_region(region_name : StringName) -> bool:
	return region_name in _regions

func change_region_cells(region_name : StringName, cells : Array) -> void:
	if region_name in _regions:
		var priority : int = _regions[region_name][_R_PRIORITY]
		for cell in _regions[region_name][_R_CELLS]:
			_DeactivateCellRegion(cell, region_name, priority)
		_regions[region_name][_R_CELLS] = cells
		for cell in _regions[region_name][_R_CELLS]:
			_ActivateCellRegion(cell, region_name, priority)
		region_changed.emit(region_name)

func add_cell_to_region(region_name : StringName, cell : HexCell) -> void:
	if region_name in _regions:
		if not _regions[region_name][_R_CELLS].any(func(rcell): return rcell.eq(cell)):
			_regions[region_name][_R_CELLS].append(cell)
			region_changed.emit(region_name)

func remove_cell_from_region(region_name : StringName, cell : HexCell) -> void:
	if region_name in _regions:
		var old_size : int = _regions[region_name][_R_CELLS].size()
		_regions[region_name][_R_CELLS] = _regions[region_name][_R_CELLS].filter(func(rcell): return not rcell.eq(cell))
		if old_size != _regions[region_name][_R_CELLS].size():
			region_changed.emit(region_name)

func change_region_color(region_name : StringName, color : Color) -> void:
	if region_name in _regions:
		_regions[region_name][_R_COLOR] = color
		region_changed.emit(region_name)

func change_region_priority(region_name : StringName, priority : int) -> void:
	if region_name in _regions:
		if _regions[region_name][_R_PRIORITY] != priority:
			var old_priority : int = _regions[region_name][_R_PRIORITY]
			for cell in _regions[region_name][_R_CELLS]:
				_DeactivateCellRegion(cell, region_name, old_priority)
				_ActivateCellRegion(cell, region_name, priority)
			_regions[region_name][_R_PRIORITY] = priority
			region_changed.emit(region_name)

func get_region_color(region_name : StringName) -> Color:
	if region_name in _regions:
		return _regions[region_name][_R_COLOR]
	return Color.BLACK

func get_region_priority(region_name : StringName) -> int:
	if region_name in _regions:
		return _regions[region_name][_R_PRIORITY]
	return -1
