shader_type canvas_item;
// 立绘融入场景：底部与两侧柔和淡出、整体染上场景色调、边缘加一圈环境轮廓光。
uniform float fade_start = 0.78;
uniform float side_fade = 0.05;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.8, 0.9, 1.0);
uniform float rim = 0.0;
uniform float rim_width = 8.0;
uniform float lift = 0.22; // 提亮暗部，深色衣服不会和夜景糊在一起

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (rim > 0.0) {
		// 轮廓光：周围一圈里只要有透明像素，就说明这里是人物边缘
		vec2 px = TEXTURE_PIXEL_SIZE * rim_width;
		float m = 1.0;
		for (int i = 0; i < 12; i++) {
			float ang = float(i) * 0.5236;
			m = min(m, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px).a);
		}
		float edge = (1.0 - m) * c.a;
		c.rgb = mix(c.rgb, rim_color.rgb, clamp(edge * rim * 0.75, 0.0, 0.75));
	}
	c.rgb = mix(c.rgb, sqrt(max(c.rgb, vec3(0.0))), lift);
	c.rgb *= tint.rgb;
	c *= COLOR;
	c.a *= 1.0 - smoothstep(fade_start, 1.0, UV.y);
	c.a *= smoothstep(0.0, side_fade, UV.x) * smoothstep(0.0, side_fade, 1.0 - UV.x);
	COLOR = c;
}
