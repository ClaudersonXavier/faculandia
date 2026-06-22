shader_type canvas_item;

const int MAX_VISION_POINTS = 192;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec2 player_screen_pos;
uniform vec2 vision_points[MAX_VISION_POINTS];
uniform int vision_point_count = 0;
uniform float inner_light_radius = 80.0;
uniform float darkness_alpha : hint_range(0.0, 1.0) = 0.7;
uniform float outside_saturation : hint_range(0.0, 1.0) = 0.24;
uniform float outside_brightness : hint_range(0.0, 1.0) = 0.34;
uniform float fade_edge = 26.0;
uniform vec3 warm_light = vec3(1.0, 0.78, 0.42);

bool point_in_polygon(vec2 point) {
	bool inside = false;
	for (int i = 0; i < MAX_VISION_POINTS; i++) {
		if (i >= vision_point_count) {
			break;
		}
		int j = i - 1;
		if (i == 0) {
			j = vision_point_count - 1;
		}
		vec2 pi = vision_points[i];
		vec2 pj = vision_points[j];
		float dy = pj.y - pi.y;
		if (abs(dy) < 0.0001) {
			continue;
		}
		bool intersect = ((pi.y > point.y) != (pj.y > point.y)) && (point.x < (pj.x - pi.x) * (point.y - pi.y) / dy + pi.x);
		if (intersect) {
			inside = !inside;
		}
	}
	return inside;
}

float distance_to_segment(vec2 point, vec2 a, vec2 b) {
	vec2 pa = point - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
	return length(pa - ba * h);
}

float polygon_edge_fade(vec2 point) {
	float nearest = 999999.0;
	for (int i = 1; i < MAX_VISION_POINTS; i++) {
		if (i >= vision_point_count) {
			break;
		}
		nearest = min(nearest, distance_to_segment(point, vision_points[i - 1], vision_points[i]));
	}
	if (vision_point_count > 2) {
		nearest = min(nearest, distance_to_segment(point, vision_points[vision_point_count - 1], vision_points[0]));
	}
	return smoothstep(0.0, fade_edge, nearest);
}

void fragment() {
	vec2 pixel_pos = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec4 base = texture(screen_texture, SCREEN_UV);
	float cone_visible = 0.0;
	if (vision_point_count > 2 && point_in_polygon(pixel_pos)) {
		cone_visible = polygon_edge_fade(pixel_pos);
	}

	float inner_dist = length(pixel_pos - player_screen_pos);
	float inner_visible = 1.0 - smoothstep(inner_light_radius * 0.45, inner_light_radius, inner_dist);
	float visible_amount = clamp(max(cone_visible, inner_visible), 0.0, 1.0);

	float gray = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	float outside_darkness = mix(1.0, outside_brightness, darkness_alpha);
	vec3 desaturated = mix(vec3(gray), base.rgb, outside_saturation) * outside_darkness;
	float noise = fract(sin(dot(pixel_pos, vec2(12.9898, 78.233))) * 43758.5453);
	desaturated *= 0.94 + noise * 0.08;

	vec3 lit = base.rgb + warm_light * visible_amount * 0.16;
	vec3 final_color = mix(desaturated, lit, visible_amount);
	COLOR = vec4(final_color, base.a);
}
