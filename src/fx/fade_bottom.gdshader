shader_type canvas_item;
// 立绘底部柔和淡出，避免在对话框上方出现硬边。
uniform float fade_start = 0.8;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.a *= 1.0 - smoothstep(fade_start, 1.0, UV.y);
	COLOR = c;
}
