shader_type canvas_item;
// 战斗敌人：受击闪白、预警泛红、死亡像素溶解、边缘描一圈发光。
uniform float flash = 0.0;
uniform vec4 warn_color : source_color = vec4(1.0, 0.25, 0.3, 1.0);
uniform float warn = 0.0;
uniform float dissolve = 0.0;
uniform vec4 rim_color : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float rim = 0.8;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	// 边缘发光：取周围 8 个方向的透明度，自己透明而邻居不透明的地方就是轮廓外沿
	vec2 px = TEXTURE_PIXEL_SIZE * 6.0;
	float around = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		around = max(around, texture(TEXTURE, UV + vec2(cos(a), sin(a)) * px).a);
	}
	float edge = clamp(around - c.a, 0.0, 1.0) * rim;
	vec4 glow = mix(rim_color, warn_color, warn);
	c.rgb = mix(c.rgb, warn_color.rgb, warn * 0.45 * c.a);
	c.rgb = mix(c.rgb, vec3(1.0), flash * c.a);
	c = vec4(mix(glow.rgb, c.rgb, c.a), max(c.a, edge * glow.a));
	float n = hash(floor(UV * 90.0));
	if (n < dissolve) { c.a = 0.0; }
	else if (n < dissolve + 0.06 && dissolve > 0.0) { c.rgb = glow.rgb * 2.0; }
	COLOR = c;
}
