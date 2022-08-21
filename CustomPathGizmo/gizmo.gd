extends EditorSpatialGizmoPlugin

const DIRS := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
const DIST := 4096
const SNAP := 0.1

var xtent := 1.0
var closed := false
var hide := false
var curve :Curve3D

signal set_menu_visible
signal set_open_visible
signal set_tilt_visible
signal set_tilt_value


func _init() -> void:
	var mat :SpatialMaterial
	create_material("lines", Color.white)
	mat = get_material("lines")
	mat.set_flag(SpatialMaterial.FLAG_DISABLE_DEPTH_TEST, true)
	
	create_handle_material("handles")
	mat = get_material("handles")
	mat.set_render_priority(3)
	mat.set_albedo(Color.cyan)
	
	create_handle_material("points")
	mat = get_material("points")
	mat.set_render_priority(2)
	mat.set_albedo(Color.magenta)
	
	create_handle_material("points_x")
	mat = get_material("points_x")
	mat.set_render_priority(1)
	mat.set_albedo(Color.yellow)
	
	create_handle_material("first")
	mat = get_material("first")
	mat.set_render_priority(4)
	mat.set_albedo(Color.black)


func set_curr_path(p:Path) -> void:
	var _curve :Curve3D= p.get_curve()
	var points := _curve.get_point_count()
	if !points:
		emit_signal("set_menu_visible", false)
		emit_signal("set_open_visible", false)
		set_gizmo_info(_curve, -1, 0)
		return
	
	emit_signal("set_menu_visible", true)
	emit_signal(
		"set_open_visible", 
		points > 1 and _curve.get_point_position(0).is_equal_approx(
			_curve.get_point_position(points - 1)
		)
	)
	set_gizmo_info(_curve, _curve.get_meta("last_point", 0), _curve.get_meta("x", 0))
	hide = false
	if !curve:
		curve = _curve
	
	_hack()


func set_gizmo_info(c:Curve3D, idx:int, x:int) -> void:
	c.set_meta("last_point", idx)
	c.set_meta("x", x)
	if idx >= 0:
		if x == 0:
			emit_signal("set_tilt_visible", true)
			emit_signal("set_tilt_value", str(rad2deg(c.get_point_tilt(idx))))
		else:
			emit_signal("set_tilt_visible", false)


func set_gizmo_xtent(s:float) -> void:
	xtent = clamp(s, 0.5, 10.0)
	_hack()


func set_tilt(t:float, UR:UndoRedo) -> void:
	var last :int= curve.get_meta("last_point", 0)
	UR.create_action("Set tilt")
	UR.add_do_method(curve, "set_point_tilt", last, deg2rad(t))
	UR.add_undo_method(curve, "set_point_tilt", last, curve.get_point_tilt(last))
	UR.add_undo_method(
		self, 
		"emit_signal", 
		"set_tilt_value", 
		str(rad2deg(curve.get_point_tilt(last)))
	)
	UR.commit_action()


func open_loop(UR:UndoRedo) -> void:
	var points := curve.get_point_count()
	if points < 2:
		return
	
	var last := curve.get_point_position(points - 1)
	if curve.get_point_position(0).is_equal_approx(last):
		UR.create_action("Open loop")
		UR.add_do_property(self, "closed", false)
		UR.add_undo_property(self, "closed", true)
		UR.add_do_method(curve, "set_point_position", points - 1, last + Vector3.FORWARD)
		UR.add_undo_method(curve, "set_point_position", points - 1, last)
		UR.add_do_method(self, "emit_signal", "set_open_visible", false)
		UR.add_undo_method(self, "emit_signal", "set_open_visible", true)
		UR.commit_action()


func has_gizmo(spatial:Spatial) -> bool:
	return spatial is Path


func get_name() -> String:
	return "CustomPathGizmo"


func get_handle_name(gizmo:EditorSpatialGizmo, index:int) -> String:
	var curve :Curve3D= gizmo.get_spatial_node().get_curve()
	var point_count := curve.get_point_count()
	if index <= 3 * (point_count - 1):
		if index < point_count:
			return "Point %s" % index
		
		index -= point_count - 1
		var idx :int= index / 2
		var t :int= index % 2
		return "Point %s (%s)" % [idx, "Out" if t else "In"]
	
	var last :int= curve.get_meta("last_point", 0)
	var x :int= curve.get_meta("x", 0)
	if x == 0:
		return "Point %s" % last
	
	return "Point %s (%s)" % [last, "Out" if x > 0 else "In"]


func get_handle_value(gizmo:EditorSpatialGizmo, index:int) -> Vector3:
	var curve :Curve3D= gizmo.get_spatial_node().get_curve()
	var point_count := curve.get_point_count()
	if index <= 3 * (point_count - 1):
		if index < point_count:
			return curve.get_point_position(index)
		
		index -= point_count - 1
		var idx :int= index / 2
		var t :int= index % 2
		return curve.get_point_out(idx) if t else curve.get_point_in(idx)
	
	var last :int= curve.get_meta("last_point", 0)
	var x :int= curve.get_meta("x", 0)
	if x == 0:
		return curve.get_point_position(last)
	
	return curve.get_point_out(last) if x > 0 else curve.get_point_in(last)


func hide_gizmos() -> void:
	if !curve:
		return
	
	if !curve.get_point_count():
		return
	
	hide = true
	_hack()


func redraw(gizmo:EditorSpatialGizmo) -> void:
	gizmo.clear()
	curve = gizmo.get_spatial_node().get_curve()
	var point_count :int= curve.get_point_count()
	if !point_count:
		hide = false
		set_gizmo_info(curve, -1, 0)
		emit_signal("set_menu_visible", false)
		return
	elif !hide:
		emit_signal("set_menu_visible", true)
	
	var curve_last_point :int= curve.get_meta("last_point", 0)
	if curve_last_point == -1 or curve_last_point >= point_count:
		curve_last_point = point_count - 1
		set_gizmo_info(curve, curve_last_point, 0)
	
	if Input.is_mouse_button_pressed(BUTTON_RIGHT):
		emit_signal("set_tilt_value", str(rad2deg(curve.get_point_tilt(curve_last_point))))
		set_gizmo_info(curve, curve_last_point, 0)
	
	var line_points := []
	for p in curve.tessellate():
		line_points.push_back(p)
		line_points.push_back(p)
	
	if line_points.pop_back().is_equal_approx(line_points.pop_front()):
		if !closed and point_count > 1:
			closed = true
			emit_signal("set_open_visible", closed)
	elif closed:
		closed = false
		emit_signal("set_open_visible", closed)
	
	var mat_lines :SpatialMaterial= get_material("lines")
	if line_points:
		gizmo.add_lines(line_points, mat_lines)
		gizmo.add_lines(line_points, mat_lines)
		gizmo.add_lines(line_points, mat_lines)
		line_points.clear()
	elif curve.get_point_out(0) or curve.get_point_in(point_count - 1):
		curve.set_point_out(0, Vector3.ZERO)
		curve.set_point_in(point_count - 1, Vector3.ZERO)
	
	var points := []
	var points_x := []
	for p in point_count:
		var p_pos :Vector3= curve.get_point_position(p)
		points.push_back(p_pos)
		if p:
			var p_x :Vector3= p_pos + curve.get_point_in(p)
			line_points.push_back(p_pos)
			line_points.push_back(p_x)
			if p == curve_last_point or (closed and p == point_count - 1 and curve_last_point == 0):
				points_x.push_back(p_x)
			else:
				points_x.push_back(p_pos)
		
		if p < point_count - 1:
			var p_x :Vector3= p_pos + curve.get_point_out(p)
			line_points.push_back(p_pos)
			line_points.push_back(p_x)
			if p == curve_last_point or (closed and p == 0 and curve_last_point == point_count - 1):
				points_x.push_back(p_x)
			else:
				points_x.push_back(p_pos)
	
	if !hide:
		gizmo.add_lines(line_points, mat_lines)
		gizmo.add_lines(line_points, mat_lines)
		gizmo.add_handles([points.pop_front()], get_material("first"))
		if !points.empty():
			gizmo.add_handles(points, get_material("points"))
			gizmo.add_handles(points_x, get_material("points_x"))
	
	if curve_last_point > -1:
		points.clear()
		line_points.clear()
		var pos :Vector3= curve.get_point_position(curve_last_point)
		if !hide:
			if curve.get_meta("x", 0) == -1:
				pos += curve.get_point_in(curve_last_point)
			elif curve.get_meta("x", 0) == 1:
				pos += curve.get_point_out(curve_last_point)
		
		for d in DIRS:
			line_points.push_back(pos)
			line_points.push_back(pos + d * xtent)
			points.push_back(pos + d * xtent)
		
		gizmo.add_lines(line_points, mat_lines)
		if !hide:
			gizmo.add_handles(points, get_material("handles"))
	
	if hide:
		hide = false


func set_handle(gizmo:EditorSpatialGizmo, index:int, camera:Camera, point:Vector2) -> void:
	var node :Spatial= gizmo.get_spatial_node() as Path
	var curve :Curve3D= node.get_curve()
	var point_count :int= curve.get_point_count()
	var idx_limit :int= 3 * (point_count - 1)
	if index <= idx_limit:
		return
	
	var last :int= curve.get_meta("last_point", 0)
	var x :int= curve.get_meta("x", 0)
	var point_pos :Vector3= curve.get_point_position(last)
	if x > 0:
		point_pos += curve.get_point_out(last)
	elif x < 0:
		point_pos += curve.get_point_in(last)
	
	var pos_end :Vector3
	if true:
		var loc_dir := node.get_global_transform().basis[index - idx_limit - 1]
		var proj_orig := camera.project_ray_origin(point)
		var res :Vector3= Geometry.get_closest_points_between_segments(
			(node.to_global(point_pos) + xtent * loc_dir) + (loc_dir * DIST), 
			(node.to_global(point_pos) + xtent * loc_dir) - (loc_dir * DIST), 
			proj_orig, 
			proj_orig + (camera.project_ray_normal(point) * DIST)
		)[0]
		if is_nan(res[0]):
			return
		
		pos_end = (node.to_local(res - loc_dir * xtent) - point_pos)
	
	var snap_vector :Vector3= Vector3.ONE
	if !Input.is_physical_key_pressed(KEY_CONTROL):
		snap_vector *= SNAP
	
	var final :Vector3= (point_pos + pos_end).snapped(snap_vector)
	var space_is_pressed := Input.is_physical_key_pressed(KEY_SPACE)
	if x == 0:
		if !space_is_pressed:
			curve.set_point_position(last, final)
			if closed:
				if last == 0:
					curve.set_point_position(point_count - 1, final)
				elif last == point_count - 1:
					curve.set_point_position(0, final)
		else:
			for p in curve.get_point_count():
				curve.set_point_position(
					p, 
					(curve.get_point_position(p) + pos_end).snapped(snap_vector)
				)
		
		return
	
	final -= curve.get_point_position(last).snapped(snap_vector)
	if x > 0:
		curve.set_point_out(last, final)
		if space_is_pressed:
			return
		elif last == 0:
			if closed:
				curve.set_point_in(point_count - 1, -final)
			
			curve.set_point_in(0, Vector3.ZERO)
			return
		
		curve.set_point_in(last, -final)
	else:
		curve.set_point_in(last, final)
		if space_is_pressed:
			return
		elif last == point_count - 1:
			if closed:
				curve.set_point_out(0, -final)
			
			curve.set_point_out(point_count - 1, Vector3.ZERO)
			return
		
		curve.set_point_out(last, -final)


func _hack() -> void:
	# Can't call redraw without a gizmo :(
	# Setting points calls set_handle, which should call redraw :)
	if curve.get_point_count():
		curve.set_point_tilt(0, curve.get_point_tilt(0))
