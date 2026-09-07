extends Control
class_name ShooterCanvas

## Draws the center crosshair (with live spread) and hitmarker flashes.
## Driven by ShooterHud.

var spread_px: float = 5.0
var hitmarker_active: bool = false
var color: Color = Color(1, 1, 1, 0.9)


func _draw() -> void:
	var center := size * 0.5
	var gap := spread_px + 6.0
	var arm := gap + 7.0
	# Dot
	draw_circle(center, 1.6, color)
	# Four ticks
	draw_line(center + Vector2(0, -gap), center + Vector2(0, -arm), color, 2.0)
	draw_line(center + Vector2(0, gap), center + Vector2(0, arm), color, 2.0)
	draw_line(center + Vector2(-gap, 0), center + Vector2(-arm, 0), color, 2.0)
	draw_line(center + Vector2(gap, 0), center + Vector2(arm, 0), color, 2.0)
	if hitmarker_active:
		var hm := Color(1.0, 0.32, 0.24, 0.95)
		var h_arm := 12.0
		var h_gap := 5.0
		draw_line(center + Vector2(-h_arm, -h_arm), center + Vector2(-h_gap, -h_gap), hm, 2.5)
		draw_line(center + Vector2(h_arm, -h_arm), center + Vector2(h_gap, -h_gap), hm, 2.5)
		draw_line(center + Vector2(-h_arm, h_arm), center + Vector2(-h_gap, h_gap), hm, 2.5)
		draw_line(center + Vector2(h_arm, h_arm), center + Vector2(h_gap, h_gap), hm, 2.5)
