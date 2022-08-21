tool
extends Control

signal tilted

onready var top_open := $box/top_open as HBoxContainer
onready var top_tilt := $box/top_tilt as HBoxContainer
onready var xtent := $box/top_xtent/xtent as SpinBox
onready var open := $box/top_open/open as Button
onready var tilt := $box/top_tilt/tilt as LineEdit


func _on_tilt_text_entered(new_text:String) -> void:
	if new_text.empty():
		new_text = "0.0"
	
	emit_signal("tilted", float(new_text))
