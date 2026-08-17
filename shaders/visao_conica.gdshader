shader_type canvas_item;

const int MAX_VISION_POINTS = 192;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec2 player_screen_pos;
uniform vec2 vision_points[MAX_VISION_POINTS];
uniform int vision_point_count = 0;

const int MAX_OMNI_POINTS = 1152;
uniform vec2 omni_points[MAX_OMNI_POINTS];
uniform int omni_point_count = 0;

const int MAX_LIGHT_SOURCES = 16;
const int MAX_TOTAL_LIGHT_POINTS = 1024;
uniform int light_count = 0;
uniform int light_starts[MAX_LIGHT_SOURCES];
uniform int light_ends[MAX_LIGHT_SOURCES];
uniform vec2 light_points[MAX_TOTAL_LIGHT_POINTS];
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

bool point_in_omni_polygon(vec2 point) {
	bool inside = false;
	for (int i = 0; i < MAX_OMNI_POINTS; i++) {
		if (i >= omni_point_count) break;
		int j = i - 1;
		if (i == 0) j = omni_point_count - 1;
		vec2 pi = omni_points[i];
		vec2 pj = omni_points[j];
		float dy = pj.y - pi.y;
		if (abs(dy) < 0.0001) continue;
		bool intersect = ((pi.y > point.y) != (pj.y > point.y)) && (point.x < (pj.x - pi.x) * (point.y - pi.y) / dy + pi.x);
		if (intersect) inside = !inside;
	}
	return inside;
}

bool point_in_light_polygon(vec2 point, int start_idx, int end_idx) {
	bool inside = false;
	int count = end_idx - start_idx;
	for(int k = 0; k < MAX_TOTAL_LIGHT_POINTS; k++) {
		if (k >= count) break;
		int i = start_idx + k;
		int j = i - 1;
		if (k == 0) j = end_idx - 1;
		vec2 pi = light_points[i];
		vec2 pj = light_points[j];
		float dy = pj.y - pi.y;
		if (abs(dy) < 0.0001) continue;
		bool intersect = ((pi.y > point.y) != (pj.y > point.y)) && (point.x < (pj.x - pi.x) * (point.y - pi.y) / dy + pi.x);
		if (intersect) inside = !inside;
	}
	return inside;
}

float light_polygon_edge_fade(vec2 point, int start_idx, int end_idx) {
	float nearest = 999999.0;
	int count = end_idx - start_idx;
	for(int k = 0; k < MAX_TOTAL_LIGHT_POINTS; k++) {
		if (k >= count) break;
		int i = start_idx + k;
		int j = i - 1;
		if (k == 0) j = end_idx - 1;
		nearest = min(nearest, distance_to_segment(point, light_points[j], light_points[i]));
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
	
	float total_light_visible = 0.0;
	if (omni_point_count > 2 && point_in_omni_polygon(pixel_pos)) {
		for(int l = 0; l < MAX_LIGHT_SOURCES; l++) {
			if (l >= light_count) break;
			int start = light_starts[l];
			int end = light_ends[l];
			if (end - start > 2 && point_in_light_polygon(pixel_pos, start, end)) {
				float light_visible = light_polygon_edge_fade(pixel_pos, start, end);
				total_light_visible = max(total_light_visible, light_visible);
			}
		}
	}

	float visible_amount = clamp(max(max(cone_visible, inner_visible), total_light_visible), 0.0, 1.0);

	float gray = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	float outside_darkness = mix(1.0, outside_brightness, darkness_alpha);
	vec3 desaturated = mix(vec3(gray), base.rgb, outside_saturation) * outside_darkness;
	float noise = fract(sin(dot(pixel_pos, vec2(12.9898, 78.233))) * 43758.5453);
	desaturated *= 0.94 + noise * 0.08;

	vec3 lit = base.rgb + warm_light * visible_amount * 0.16;
	vec3 final_color = mix(desaturated, lit, visible_amount);
	COLOR = vec4(final_color, base.a);
}
