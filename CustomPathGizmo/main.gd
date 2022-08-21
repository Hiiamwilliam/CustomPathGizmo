tool
extends EditorPlugin

const GIZMO := preload("res://addons/CustomPathGizmo/gizmo.gd")
const MENU := preload("res://addons/CustomPathGizmo/menu_bar.tscn")
const PICK_LENGTH := 4096
const PICK_MAX_DIST := 0.049

var gizmo := GIZMO.new() as EditorSpatialGizmoPlugin
var menu := MENU.instance() as Control
var selection :EditorSelection= get_editor_interface().get_selection()
var last :Path


func _enter_tree():
	selection.connect("selection_changed", self, "check_selection")
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, menu)
	menu.set_visible(false)
	
	add_spatial_gizmo_plugin(gizmo)
	menu.xtent.connect("value_changed", gizmo, "set_gizmo_xtent")
	menu.open.connect("pressed", gizmo, "open_loop", [get_undo_redo()])
	menu.connect("tilted", gizmo, "set_tilt", [get_undo_redo()])
	
	gizmo.connect("set_menu_visible", menu, "set_visible")
	gizmo.connect("set_open_visible", menu.top_open, "set_visible")
	gizmo.connect("set_tilt_visible", menu.top_tilt, "set_visible")
	gizmo.connect("set_tilt_value", menu.tilt, "set_text")


func _exit_tree():
	menu.set_visible(false)
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, menu)
	menu.free()
	remove_spatial_gizmo_plugin(gizmo)


func check_selection() -> void:
	var arr :Array= selection.get_selected_nodes()
	var size := arr.size()
	if size != 1 or (size == 1 and arr[0].get_class() != "Path"):
		gizmo.call_deferred("hide_gizmos")
		menu.call_deferred("set_visible", false)


func handles(object:Object) -> bool:
	if object is Path:
		last = object
		gizmo.set_curr_path(last)
		return true
	
	gizmo.hide_gizmos()
	menu.set_visible(false)
	return false


func forward_spatial_gui_input(camera:Camera, event:InputEvent) -> bool:
	if !event is InputEventMouseButton:
		return false
	elif event.get_button_index() != BUTTON_LEFT or !event.is_pressed():
		return false
	
	var curve :Curve3D= last.get_curve()
	var point_count := curve.get_point_count()
	if !point_count:
		return false
	
	var idx := -1
	var cam_from :Vector3= camera.project_ray_origin(event.get_position())
	var cam_to :Vector3= cam_from + camera.project_ray_normal(event.get_position()) * PICK_LENGTH
	var cam_orig :Vector3= camera.get_global_transform().origin
	if true: # Checks if clicked near a curve point
		var last_cam_dist := INF
		for p in point_count:
			var glob_point :Vector3= last.to_global(curve.get_point_position(p))
			var res :Vector3= Geometry.get_closest_point_to_segment(glob_point, cam_from, cam_to)
			var dist_to_cam :float= glob_point.distance_squared_to(cam_orig)
			if res.distance_squared_to(glob_point) <= PICK_MAX_DIST and dist_to_cam <= last_cam_dist:
				last_cam_dist = dist_to_cam
				idx = p
	
	var x := 0
	var to_print := ""
	if idx >= 0: # Checks Handles and Colliders
		to_print = "Point %s at: %s" % [idx, curve.get_point_position(idx)]
		if event.get_shift():
			if !event.get_control(): # Add Handles if needed
				var is_closed :bool= last.get_gizmo().get_plugin().closed
				var add_i_closed :bool= is_closed and idx == 0 and !curve.get_point_in(point_count - 1)
				var add_o_closed :bool= is_closed and idx == point_count - 1 and !curve.get_point_out(0)
				var add_i := idx and !curve.get_point_in(idx)
				var add_o := idx < point_count - 1 and !curve.get_point_out(idx)
				if add_i or add_o or add_i_closed or add_o_closed:
					var UR :UndoRedo= get_undo_redo()
					UR.create_action("Create In/Out handles")
					if add_i:
						UR.add_do_method(curve, "set_point_in", idx, Vector3.LEFT * 2)
						UR.add_undo_method(curve, "set_point_in", idx, Vector3.ZERO)
					
					if add_o:
						UR.add_do_method(curve, "set_point_out", idx, Vector3.RIGHT * 2)
						UR.add_undo_method(curve, "set_point_out", idx, Vector3.ZERO)
					
					if add_i_closed:
						UR.add_do_method(curve, "set_point_in", point_count - 1, Vector3.LEFT * 2)
						UR.add_undo_method(curve, "set_point_in", point_count - 1, Vector3.ZERO)
					elif add_o_closed:
						UR.add_do_method(curve, "set_point_out", 0, Vector3.RIGHT * 2)
						UR.add_undo_method(curve, "set_point_out", 0, Vector3.ZERO)
					
					UR.commit_action()
			else: # Snap to Collider if there is one
				var pdss :PhysicsDirectSpaceState= last.get_world().get_direct_space_state()
				var res :Dictionary= pdss.intersect_ray(cam_from, cam_to)
				if res:
					var pos :Vector3= curve.get_point_position(idx)
					var new_pos :Vector3= last.to_local(res["position"])
					var UR :UndoRedo= get_undo_redo()
					UR.create_action("Snap to collider")
					UR.add_do_method(curve, "set_point_position", idx, new_pos)
					UR.add_undo_method(curve, "set_point_position", idx, pos)
					UR.commit_action()
	else: # Didnt click near curve points, check if near in/out Handles
		idx = curve.get_meta("last_point")
		if !(curve.get_point_in(idx) or curve.get_point_out(idx)):
			return false
		
		var glob_point := last.to_global(curve.get_point_position(idx))
		var in_out := [
			glob_point + (curve.get_point_in(idx)),
			glob_point + (curve.get_point_out(idx))
		]
		point_count -= 1
		var closed :bool= last.get_gizmo().get_plugin().closed
		if closed:
			if idx == 0:
				in_out[0] = glob_point + last.to_global(curve.get_point_in(point_count))
			elif idx == point_count:
				in_out[1] = glob_point + last.to_global(curve.get_point_out(0))
		
		x = 2
		if true:
			var last_cam_dist := INF
			for p in 2:
				var res :Vector3= Geometry.get_closest_point_to_segment(in_out[p], cam_from, cam_to)
				var dist_to_cam :float= in_out[p].distance_squared_to(cam_orig)
				if res.distance_squared_to(in_out[p]) <= PICK_MAX_DIST and dist_to_cam <= last_cam_dist:
					last_cam_dist = dist_to_cam
					x = p
		
		if x == 2:
			return false
		elif x == 0:
			x = -1
		
		if closed:
			if idx == 0 and x < 0:
				idx = point_count
			elif idx == point_count and x > 0:
				idx = 0
		
		to_print = "Point %s at: %s, handle %s at: %s" % [
			idx, 
			curve.get_point_position(idx),
			"In" if x < 0 else "Out",
			curve.get_point_in(idx) if x < 0 else curve.get_point_out(idx)
		]
	
	last.get_gizmo().get_plugin().set_gizmo_info(curve, idx, x)
	last.update_gizmo()
	if event.is_doubleclick():
		print(to_print)
	
	return true
