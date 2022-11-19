@tool
extends RefCounted
class_name HexCell

# HexCell
# A Godot 4.0 tool script for working with Hexigon cells in a grid.
#
# This script is heavily based off information on Hexagonal Grids by Red Blob Games
# https://www.redblobgames.com/grids/hexagons/
#
# This script is open source under the MIT License
# Copyright (c) 2022 Bryan Miller
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the “Software”), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
# to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
# BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# ------------------------------------------------------------------------

# ABOUT:
#
# HexCell is a self contained class for the manipulation of coordinates within a 2D
# Hexigonal grid-space.
#
# Where a Vector3 is composed of the coordinates (X,Y,Z), a Hexigonal coordinate used in
# HexCell is composed of the coordinates (Q, R, S) with a very special rule that Q+R+S = 0
# Internally HexCell stores its QRS coordinates in a Vector3i where Q=X, R=Z, S=Y
#
# Hexigonal coordinates can have one of two orientations.
# Pointy [default] - Q is the diagnal \ , R sits on the X-axis, S is the diagnal /
#   /\
#  /  \      Q
# |    |      \ __ R
# |    |      /
#  \  /      S
#   \/
#
# Flat - Q sits on the Y-axis, R is the diagnal \ , S is the diagnal /
#   ---        Q
#  /   \       |
#  \   /      / \
#   ---      S   R

# ADDING TO PROJECT:
#
# To add HexCell to a project simply copy this script somewhere under the project's resource folder.
# Once added to the project, a HexCell can be created with HexCell.new()

# USAGE EXAMPLES:
#
# # Creating a Pointy HexCell at coordinate 0,0,0
# var cell = HexCell.new()
# # Alternatively
# var cell_pointy = HexCell.Pointy()
#
# ---
#
# # Creating a Flat HexCell at coordinate 0,0,0
# var cell = HexCell.new(null, false, HexCell.ORIENTATION.Flat)
# # Alternatively
# var cell_flat = HexCell.Flat()
#
# ---
#
# # Creating a (Pointy) HexCell from a QRS coordinate. NOTE: QRS is passed as QSR in a Vector
# var cell = HexCell.new(Vector3i(1, 2, -1))
# # Alternatively
# var cell2 = HexCell.Pointy(Vector3i(1, 2, -1))
#
# ---
#
# # Creating a copy of a HexCell
# var cell1 = HexCell.Pointy(Vector3i(1, 2, -1))
# var cell2 = HexCell.new(cell1)
# # Alternatively
# var cell2b = cell1.clone()
#
# ---
#
# # Changing HexCell Orientation from Pointy to Flat
# var cell = HexCell.Pointy()
# cell.orientation = HexCell.ORIENTATION.Flat
# # Alternatively going back to Pointy...
# cell.swap_orientation()
# # Creating a duplicate HexCell with a specific orientation (back to Flat in this example)
# var cell2 = HexCell.Flat(cell)
#
# ---
#
# # Checking if two cells are the same. NOTE: Orientation must match as well
# var cellA = HexCell.new()
# var cellB == HexCell.new()
# if cellA.eq(cellB):
#   print("Cells Match!")
#
# ---
#
# # Checking if two cells are the same coordinate regardless of orientation...
# var cellA = HexCell.Pointy()
# var cellB = HexCell.Flat()
# if cellA.qrs == callB.qrs:
#   print("Cell coordinates match!")
#
# ---
#
# # Adding the coordinates of one HexCell to another.
# var cellA = HexCell.Pointy(Vector3i(4, -2, -2))
# var cellB = HexCell.Flat(Vector3i(2, 2, -4))
# cellA.qrs += cellB.qrs
# print(cellA.as_string()) # Should print "Hex(6, -6, 0):P"
#
# ---
#
# # Setting a HexCell from a world space Vector2
# var cell = HexCell.new()
# cell.from_point(Vector2(8.2, 4.8))
#
# ---
#
# # Creating a HexCell from a world space Vector2
# var cell = HexCell.new(Vector2(8.2, 4.8), true)

# -------------------------------------------------------------------------
# Constants and ENUMs
# -------------------------------------------------------------------------
const SQRT3 : float = sqrt(3)

const NEIGHBOR_OFFSET : Array[Vector3i] = [
	Vector3i(0, -1, 1),
	Vector3i(-1, 0, 1),
	Vector3i(-1, 1, 0),
	Vector3i(0, 1, -1),
	Vector3i(1, 0, -1),
	Vector3i(1, -1, 0)
]

const NEIGHBOR_OFFSET_DIAG : Array[Vector3i] = [
	Vector3i(1, -2, 1),
	Vector3i(-1, -1, 2),
	Vector3i(-2, 1, 1),
	Vector3i(-1, 2, -1),
	Vector3i(1, 1, -2),
	Vector3i(2, -1, -1)
]

enum ORIENTATION {Pointy=0, Flat=1}
enum AXIS {Q=0, R=1, S=2}

# -------------------------------------------------------------------------
# Export Variables
# -------------------------------------------------------------------------
@export_category("HexCell")
@export var qrs : Vector3i : get = get_qrs, set = set_qrs
@export var orientation : ORIENTATION = ORIENTATION.Pointy : set = set_orientation

# -------------------------------------------------------------------------
# Public Variables
# -------------------------------------------------------------------------
var qr : Vector2i : get = get_qr, set = set_qr

# Read Only
# --------------
var q : int : get = get_q, set = _no_set
var r : int : get = get_r, set = _no_set
var s : int : get = get_s, set = _no_set


# -------------------------------------------------------------------------
# Private Variables
# -------------------------------------------------------------------------
var _c : Vector3i = Vector3i.ZERO
var _sname : StringName = &""


# -------------------------------------------------------------------------
# Setters / Gettes
# -------------------------------------------------------------------------
func _no_set(_v) -> void:
	pass # Hopefully this is good for a "read only" variable

func set_qrs(v : Vector3i) -> void:
	if _IsValid(v):
		_c = v
		_UpdateStringName()

func get_qrs() -> Vector3i:
	return _c

func set_qr(v : Vector2i) -> void:
	set_qrs(Vector3i(v.x, (-v.x)-v.y, v.y))

func get_qr() -> Vector2i:
	return Vector2i(_c.x, _c.z)

func set_orientation(o : int) -> void:
	if ORIENTATION.values().find(o) >= 0:
		if orientation != o:
			orientation = o
			_UpdateStringName()

func get_q() -> int:
	return _c.x

func get_r() -> int:
	return _c.z

func get_s() -> int:
	return _c.y

# -------------------------------------------------------------------------
# Static Methods
# -------------------------------------------------------------------------
static func Pointy(value = null, point_is_spacial : bool = false) -> HexCell:
	return HexCell.new(value, point_is_spacial, ORIENTATION.Pointy)

static func Flat(value = null, point_is_spacial : bool = false) -> HexCell:
	return HexCell.new(value, point_is_spacial, ORIENTATION.Flat)

# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _init(value = null, point_is_spacial : bool = false, orien : int = -1) -> void:
	value = value # This is a hack to prevent the analyzer from catching an error... grrr
	if ORIENTATION.values().find(orien) >= 0:
		orientation = orien
	
	if typeof(value) == TYPE_OBJECT and value.has_method("is_valid") and value.is_valid():
		set_qrs(value.qrs)
		orientation = value.orientation
	elif typeof(value) == TYPE_VECTOR3 or typeof(value) == TYPE_VECTOR3I:
		set_qrs(_RoundVec(Vector3i(value)))
	elif typeof(value) == TYPE_VECTOR2:
		if point_is_spacial:
			from_point(value)
		else:
			set_qr(value)
	elif typeof(value) == TYPE_VECTOR2I:
		set_qr(value)
	else:
		# By default, C is origin, which is valid, so...
		_UpdateStringName()

# -------------------------------------------------------------------------
# Private Methods
# -------------------------------------------------------------------------
func _IsValid(v : Vector3i) -> bool:
	return v.x + v.y + v.z == 0

func _UpdateStringName() -> void:
	_sname = StringName("%s,%s,%s:%s"%[_c.x, _c.z, _c.y, orientation])

func _RoundVec(v : Vector3) -> Vector3i:
	var _q : float = round(v.x)
	var _r : float = round(v.z)
	var _s : float = round(v.y)
	
	var dq : float = abs(v.x - _q)
	var dr : float = abs(v.z - _r)
	var ds : float = abs(v.y - _s)
	
	if dq > dr and dq > ds:
		_q = -_r -_s
	elif dr > ds:
		_r = -_q -_s
	else:
		_s = -_q -_r
	
	#print("Rounded Float: ", Vector3(_q,_s,_r), " | Int: ", Vector3i(int(_q), int(_s), int(_r)))
	return Vector3i(int(_q), int(_s), int(_r))

func _CellLerp(a : HexCell, b : HexCell, t : float) -> HexCell:
	var _q = lerp(float(a.q), float(b.q), t)
	var _r = lerp(float(a.r), float(b.r), t)
	var _s = lerp(float(a.s), float(b.s), t)
	return get_script().new(_RoundVec(Vector3(_q, _s, _r)), false, orientation)

func _ReflectQRSVec(v : Vector3i, haxis : int, mirrored : bool = false) -> Vector3i:
	var nqrs : Vector3i = v
	match haxis:
		AXIS.Q:
			if v.x != 0:
				nqrs.x = v.x
				nqrs.y = v.z
				nqrs.z = v.y
		AXIS.R:
			if v.z != 0:
				nqrs.z = v.z
				nqrs.x = v.y
				nqrs.y = v.x
		AXIS.S:
			if v.y != 0:
				nqrs.y = v.y
				nqrs.z = v.x
				nqrs.x = v.z
	if mirrored:
		nqrs *= -1
	return nqrs

# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------
func is_valid() -> bool:
	return _IsValid(_c)

func clone() -> HexCell:
	return get_script().new(_c, false, orientation)

func swap_orientation() -> void:
	match orientation:
		ORIENTATION.Pointy:
			set_orientation(ORIENTATION.Flat)
		ORIENTATION.Flat:
			set_orientation(ORIENTATION.Pointy)

func eq(v, point_is_spacial : bool = false) -> bool:
	match typeof(v):
		TYPE_OBJECT:
			if v.has_method("get_string_name"):
				return _sname == v.get_string_name()
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return _c == Vector3i(v)
		TYPE_VECTOR2, TYPE_VECTOR2I:
			if point_is_spacial and typeof(v) == TYPE_VECTOR2:
				return to_point().is_equal_approx(v)
			return _c == Vector3i(v.x, -v.x-v.y, v.y)
	return false

func distance_to(cell : HexCell) -> float:
	if is_valid() and cell != null and cell.is_valid():
		var subc : Vector3 = Vector3(_c) - Vector3(cell.qrs)
		return (abs(subc.x) + abs(subc.y) + abs(subc.z)) * 0.5
	return 0.0

func to_point() -> Vector2:
	var x : float = 0.0
	var y : float = 0.0
	if is_valid():
		match orientation:
			ORIENTATION.Pointy:
				x = (SQRT3 * _c.x) + ((SQRT3 * 0.5) * _c.z)
				y = 1.5 * _c.z
			ORIENTATION.Flat:
				x = 1.5 * _c.x
				y = ((SQRT3 * 0.5) * _c.x) + (SQRT3 * _c.z)
	return Vector2(x,y)

func to_point3D(height : float = 0.0) -> Vector3:
	var point = to_point()
	return Vector3(point.x, height, point.y)

func from_point(point : Vector2) -> void:
	var fq : float = 0.0
	var fr : float = 0.0
	match orientation:
		ORIENTATION.Pointy:
			fq = ((SQRT3/3.0) * point.x) - ((1.0/3.0) * point.y)
			fr = (2.0/3.0) * point.y
		ORIENTATION.Flat:
			fq = (2.0/3.0) * point.x
			fr = ((-1.0/3.0) * point.x) + ((SQRT3/3.0) * point.y)
	var fs : float = -fq -fr
	set_qrs(_RoundVec(Vector3(fq, fs, fr)))
	#print("From Point: ", point, " | pre Round: ", Vector3(fq, fs, fr), " | post Round: ", _c)

func from_point3D(point : Vector3) -> void:
	from_point(Vector2(point.x, point.z))

func rotated_60(ccw : bool = false) -> HexCell:
	# q/x, r/z, s/y
	# r/z, s/y, q/x
	# s/y, q/x, r/z
	var nqrs : Vector3i = Vector3i.ZERO
	if ccw:
		nqrs = Vector3i(-_c.y, -_c.z, -_c.x)
	else:
		nqrs = Vector3i(-_c.z, -_c.x, -_c.y)
	return get_script().new(nqrs, false, orientation)

func rotated_around_60(origin, ccw : bool = false) -> HexCell:
	origin = get_script().new(origin, false, orientation)
	var nqrs : Vector3i = Vector3i(_c.x - origin.q, _c.y - origin.s, _c.z - origin.r)
	if ccw:
		nqrs = Vector3i(-nqrs.y, -nqrs.z, -nqrs.x)
	else:
		nqrs = Vector3i(-nqrs.z, -nqrs.x, -nqrs.y)
	return get_script().new(nqrs + origin.qrs, false, orientation)

func reflected(haxis : int, mirrored : bool = false) -> HexCell:
	var nqrs : Vector3i = _ReflectQRSVec(_c, haxis, mirrored)
	return get_script().new(nqrs, false, orientation)

func reflected_around(origin, haxis : int, mirrored : bool = false) -> HexCell:
	origin = get_script().new(origin, false, orientation)
	var nqrs : Vector3i = _c - origin.qrs
	nqrs = _ReflectQRSVec(nqrs, haxis, mirrored)
	nqrs += origin.qrs
	return get_script().new(nqrs, false, orientation)


func get_neighbor(dir : int, amount : int = 1, diagnal : bool = false) -> HexCell:
	if is_valid() and amount > 0:
		if dir >= 0 and dir < NEIGHBOR_OFFSET.size():
			var narr : Array[Vector3i] = NEIGHBOR_OFFSET_DIAG if diagnal else NEIGHBOR_OFFSET
			var vh : HexCell = get_script().new(_c + (narr[dir] * amount), false, orientation)
			return vh
	return null

func get_region(rng : int) -> Array:
	var res : Array = []
	for _q in range(-rng, rng+1):
		for _r in range(max(-rng, -_q-rng), min(rng, -_q+rng) + 1):
			var _s = -_q-_r
			res.append(get_script().new(Vector3i(_q + _c.x, _s + _c.y, _r + _c.z), false, orientation))
	return res

func get_wedge_region(dir : int, rng : int, diagnal : bool = false) -> Array:
	var res : Array = []
	for _q in range(-rng, rng+1):
		for _r in range(max(-rng, -_q-rng), min(rng, -_q+rng) + 1):
			var _s = -_q-_r
			var dr : int = _r if diagnal else _r-_s
			var dq : int = _q if diagnal else _q-_r
			var ds : int = _s if diagnal else _s-_q
			# NOTE: Q+ and Q- are swapped below to maintain a clean clock-wise rotation with dir values.
			var include : bool = false
			match dir:
				0: # R-S or R
					include = dr >= 0 and abs(dr) >= abs(dq) and abs(dr) >= abs(ds)
				1: # Q-R or Q, Negative
					include = dq <= 0 and abs(dq) >= abs(dr) and abs(dq) >= abs(ds)
				2: # S-Q or S
					include = ds >= 0 and abs(ds) >= abs(dq) and abs(ds) >= abs(dr)
				3: # R-S or R, Negative
					include = dr <= 0 and abs(dr) >= abs(dq) and abs(dr) >= abs(ds)
				4: # Q-R or Q
					include = dq >= 0 and abs(dq) >= abs(dr) and abs(dq) >= abs(ds)
				5: # S-Q or S, Negative
					include = ds <= 0 and abs(ds) >= abs(dq) and abs(ds) >= abs(dr)
			if include:
				res.append(get_script().new(_RoundVec(Vector3(_q, _s, _r)) + _c, false, orientation))
	return res

func get_ring(rng : int) -> Array:
	var res : Array = []
	var cell = get_neighbor(4, rng)
	for i in range(0, 6):
		for _j in range(rng):
			res.append(cell)
			cell = cell.get_neighbor(i)
	return res

func get_line_to_cell(cell : HexCell) -> Array:
	var res : Array = []
	if cell.is_valid():
		var dist = distance_to(cell)
		for i in range(0, dist):
			var ncell = _CellLerp(self, cell, i/dist)
			res.append(ncell)
	return res

func get_line_to_point(point : Vector2) -> Array:
	var ecell = get_script().new(point, true)
	return get_line_to_cell(ecell)

func get_facing_edge(cell : HexCell) -> int:
	if cell.is_valid() and not cell.eq(self):
		var dist : float = distance_to(cell)
		var ncell = _CellLerp(self, cell, 1/dist)
		var idx : int = NEIGHBOR_OFFSET.find(ncell.qrs - _c)
		return idx
	return -1

func as_string() -> String:
	return "Hex(%s, %s, %s):%s"%[_c.x, _c.z, _c.y, "P" if orientation == ORIENTATION.Pointy else "F"]

func get_string_name() -> StringName:
	return _sname


