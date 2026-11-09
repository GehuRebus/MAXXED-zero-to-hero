class_name StatBar
extends Control
## Placeholder stat bar: a labeled solid-color fill, with an optional
## threshold marker line (used for the gloom lockout).

@export var title: String = ""
@export var fill_color: Color = Color.WHITE
@export var back_color: Color = Color(0.1, 0.1, 0.12, 1)
@export var marker_color: Color = Color(1, 0.85, 0.2, 1)
@export var font_size: int = 22

var value: int = 0
var max_value: int = 1
## Marker position in stat units; negative hides it.
var marker: int = -1
var marker_label: String = ""


func set_values(new_value: int, new_max: int, new_marker: int = -1, new_marker_label: String = "") -> void:
	value = new_value
	max_value = maxi(new_max, 1)
	marker = new_marker
	marker_label = new_marker_label
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, back_color)
	var ratio := clampf(float(value) / float(max_value), 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * ratio, size.y)), fill_color)

	var font := get_theme_default_font()
	var text_y := size.y * 0.5 + font_size * 0.35
	if marker >= 0:
		var x := size.x * clampf(float(marker) / float(max_value), 0.0, 1.0)
		draw_line(Vector2(x, -6), Vector2(x, size.y + 6), marker_color, 4.0)
		if not marker_label.is_empty():
			draw_string_outline(font, Vector2(x + 8, text_y), marker_label,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, Color(0, 0, 0, 0.85))
			draw_string(font, Vector2(x + 8, text_y), marker_label,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 17, marker_color)

	draw_string(font, Vector2(12, text_y), "%s: %d" % [title, value],
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	draw_rect(rect, Color(1, 1, 1, 0.6), false, 2.0)
