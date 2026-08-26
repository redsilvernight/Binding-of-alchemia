class_name StatBar
extends RefCounted

const SWATCH_WIDTH: float = 20.0
const VALUE_LABEL_WIDTH: float = 26.0
const DELTA_LABEL_WIDTH: float = 26.0

static func build_delta_value(current_value: float, combined_value: float, max_value: float, color: Color, format: String) -> Control:
	var wrap := HBoxContainer.new()
	wrap.add_theme_constant_override("separation", 4)

	var swatch := Control.new()
	swatch.custom_minimum_size = Vector2(SWATCH_WIDTH, 10)

	var bg := ColorRect.new()
	bg.color = Color(1.0, 1.0, 1.0, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	swatch.add_child(bg)

	var current_ratio: float = clampf(current_value / max_value, 0.0, 1.0)
	var combined_ratio: float = clampf(combined_value / max_value, 0.0, 1.0)
	var base_ratio: float = minf(current_ratio, combined_ratio)

	var fill := ColorRect.new()
	fill.color = color
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.offset_top = 0.0
	fill.offset_bottom = 0.0
	fill.offset_left = 0.0
	fill.offset_right = SWATCH_WIDTH * base_ratio
	swatch.add_child(fill)

	if combined_ratio > current_ratio:
		var growth := ColorRect.new()
		growth.color = Color(1.0, 1.0, 1.0, 0.75)
		growth.anchor_top = 0.0
		growth.anchor_bottom = 1.0
		growth.offset_top = 0.0
		growth.offset_bottom = 0.0
		growth.offset_left = SWATCH_WIDTH * base_ratio
		growth.offset_right = SWATCH_WIDTH * combined_ratio
		swatch.add_child(growth)
	elif combined_ratio < current_ratio:
		var loss := ColorRect.new()
		loss.color = Color(0.95, 0.2, 0.15, 0.85)
		loss.anchor_top = 0.0
		loss.anchor_bottom = 1.0
		loss.offset_top = 0.0
		loss.offset_bottom = 0.0
		loss.offset_left = SWATCH_WIDTH * base_ratio
		loss.offset_right = SWATCH_WIDTH * current_ratio
		swatch.add_child(loss)

	wrap.add_child(swatch)

	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 10)
	value_label.custom_minimum_size = Vector2(VALUE_LABEL_WIDTH, 0)
	value_label.text = format % current_value
	wrap.add_child(value_label)

	var delta: float = combined_value - current_value
	var delta_label := Label.new()
	delta_label.add_theme_font_size_override("font_size", 9)
	delta_label.custom_minimum_size = Vector2(DELTA_LABEL_WIDTH, 0)
	if not is_equal_approx(delta, 0.0):
		delta_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55) if delta > 0.0 else Color(0.95, 0.55, 0.45))
		delta_label.text = ("+" if delta > 0.0 else "") + (format % delta)
	wrap.add_child(delta_label)

	return wrap


static func delta_suffix(current_value: float, combined_value: float, format: String) -> String:
	var delta: float = combined_value - current_value
	if is_equal_approx(delta, 0.0):
		return ""
	return " (%s%s)" % ["+" if delta > 0.0 else "", format % delta]
