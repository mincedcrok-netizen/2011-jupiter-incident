class_name RetroStyle
extends RefCounted
## Shared look for narrative UI: dark CRT-terminal panels, neon-green accent, monospace
## text and a scanline overlay (Lore Bible: CRT monitors, retro interfaces, neon
## indicators on cold interiors). Placeholder art; the structure is what matters.

const BG := Color(0.02, 0.06, 0.05, 0.94)
const ACCENT := Color(0.25, 1.0, 0.65)
const DIM := Color(0.42, 0.7, 0.6)
const WARN := Color(1.0, 0.72, 0.2)
const TEXT := Color(0.85, 1.0, 0.92)

const SCANLINE_SHADER := """
shader_type canvas_item;
void fragment() {
	float line = step(0.5, fract(FRAGCOORD.y * 0.5));
	COLOR = vec4(0.0, 0.0, 0.0, 0.14 * line);
}
"""

static var _font: Font = null


static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Courier New", "monospace"])
		_font = f
	return _font


static func box(border: Color = ACCENT, bg: Color = BG, margin: float = 14.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_content_margin_all(margin)
	return sb


static func label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_focus_color", ACCENT)
	b.add_theme_stylebox_override("normal", box(DIM, Color(0.03, 0.1, 0.08, 0.9), 8))
	b.add_theme_stylebox_override("hover", box(ACCENT, Color(0.05, 0.18, 0.13, 0.95), 8))
	b.add_theme_stylebox_override("focus", box(ACCENT, Color(0.05, 0.18, 0.13, 0.95), 8))
	b.add_theme_stylebox_override("pressed", box(ACCENT, Color(0.08, 0.28, 0.2, 1.0), 8))
	return b


static func scanlines() -> ColorRect:
	var r := ColorRect.new()
	var shader := Shader.new()
	shader.code = SCANLINE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	r.material = mat
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Full-screen transparent Control that does not eat mouse input.
static func overlay_root() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Centered panel taking `fraction` of the screen; returns the panel (content container inside).
static func centered_panel(fraction: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.anchor_left = 0.5 - fraction.x / 2.0
	p.anchor_right = 0.5 + fraction.x / 2.0
	p.anchor_top = 0.5 - fraction.y / 2.0
	p.anchor_bottom = 0.5 + fraction.y / 2.0
	p.offset_left = 0
	p.offset_right = 0
	p.offset_top = 0
	p.offset_bottom = 0
	p.add_theme_stylebox_override("panel", box())
	return p


static func character_name(speaker: String) -> String:
	var ch := NarrativeDatabase.get_character(StringName(speaker))
	if ch == null:
		return speaker.to_upper()
	return ch.display_name.to_upper() if ch.callsign == "" else ("%s \"%s\"" % [ch.display_name, ch.callsign]).to_upper()


static func mmss(seconds: float) -> String:
	var s := int(seconds)
	return "%02d:%02d" % [s / 60, s % 60]
