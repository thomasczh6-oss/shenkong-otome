shader_type canvas_item;
// 立绘融入场景：底部与两侧柔和淡出、整体染上场景色调、边缘加一圈环境轮廓光。
uniform float fade_start = 0.78;
uniform float side_fade = 0.05;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.8, 0.9, 1.0);
uniform float rim = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (rim > 0.0) {
		vec2 px = TEXTURE_PIXEL_SIZE * 6.0;
		float a = 0.0;
		a += texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
		a += texture(TEXTURE, UV - vec2(px.x, 0.0)).a;
		a += texture(TEXTURE, UV + vec2(0.0, px.y)).a;
		a += texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		float edge = clamp(c.a - a * 0.25, 0.0, 1.0) + clamp(1.0 - a * 0.25, 0.0, 1.0) * c.a;
		c.rgb = mix(c.rgb, rim_color.rgb, clamp(edge * rim, 0.0, 0.8));
	}
	c.rgb *= tint.rgb;
	c *= COLOR;
	c.a *= 1.0 - smoothstep(fade_start, 1.0, UV.y);
	c.a *= smoothstep(0.0, side_fade, UV.x) * smoothstep(0.0, side_fade, 1.0 - UV.x);
	COLOR = c;
}
