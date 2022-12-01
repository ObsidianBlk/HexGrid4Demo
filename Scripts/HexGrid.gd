extends Resource
class_name HexGrid


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal orientation_changed(new_orientation)
signal region_added(region_name)
signal region_removed(region_name)
signal region_changed(region_name)

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const _R_CELLS : StringName = &"cells"
const _R_COLOR : StringName = &"color"
const _R_PRIORITY : StringName = &"priority"

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export_category("HexGrid")
@export var orientation : HexCell.ORIENTATION = HexCell.ORIENTATION.Pointy :	set = set_orientation
@export var enable_radial_bounds : bool = false :								set = set_enable_radial_bounds
@export var bound_radius : int = 1 :											set = set_bound_radius
@export var enable_region_bounds : bool = false :								set = set_enable_region_bounds
@export var bound_region : Rect2 = Rect2() :									set = set_bound_region


# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _regions : Dictionary = {}
var _active_cells : Dictionary = {}

# ------------------------------------------------------------------------------
# Setters / Getters
# ------------------------------------------------------------------------------
func set_orientation(o : HexCell.ORIENTATION) -> void:
	orientation = o

func set_enable_radial_bounds(e : bool) -> void:
	enable_radial_bounds = e
	if enable_radial_bounds and enable_region_bounds:
		enable_region_bounds = false

func set_bound_radius(r : int) -> void:
	if r > 0:
		bound_radius = r

func set_enable_region_bounds(e : bool) -> void:
	enable_region_bounds = e
	if enable_region_bounds and enable_radial_bounds:
		enable_radial_bounds = false

func set_bound_region(r : Rect2) -> void:
	bound_region = r


# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _ActivateCellRegion(cell : HexCell, region_name : StringName, priority : int) -> void:
	if not region_name in _regions:
		return
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

func get_qrs_priority(qrs : Vector3i) -> int:
	if qrs in _active_cells:
		var priorities : Array = _active_cells[qrs].keys()
		priorities.sort()
		return priorities[priorities.size() - 1]
	return -1

func get_cell_priority(cell : HexCell) -> int:
	return get_qrs_priority(cell.qrs)

func get_qrs_active_region(qrs : Vector3i) -> StringName:
	var priority = get_qrs_priority(qrs)
	if priority >= 0:
		return _active_cells[qrs][priority][0]
	return &""

func get_cell_active_region(cell : HexCell) -> StringName:
	return get_qrs_active_region(cell.qrs)


