shader_type canvas_item;

const int MAX_VISION_POINTS = 192;
const int MAX_OMNI_POINTS = 1152;
const int MAX_LIGHT_SOURCES = 16;
const int MAX_TOTAL_LIGHT_POINTS = 1024;

uniform vec2 vision_points[MAX_VISION_POINTS];
uniform int vision_point_count = 0;
uniform vec2 player_screen_pos;
uniform float inner_light_radius = 80.0;
uniform vec2 omni_points[MAX_OMNI_POINTS];
uniform int omni_point_count = 0;
uniform int light_count = 0;
uniform int light_starts[MAX_LIGHT_SOURCES];
uniform int light_ends[MAX_LIGHT_SOURCES];
uniform vec2 light_points[MAX_TOTAL_LIGHT_POINTS];

bool point_in_polygon(vec2 point) {
	bool inside = false;
	for (int i = 0; i < MAX_VISION_POINTS; i++) {
		if (i >= vision_point_count) break;
		int j = i - 1;
		if (i == 0) j = vision_point_count - 1;
		vec2 pi = vision_points[i];
		vec2 pj = vision_points[j];
		float dy = pj.y - pi.y;
		if (abs(dy) < 0.0001) continue;
		bool intersect = ((pi.y > point.y) != (pj.y > point.y)) && (point.x < (pj.x - pi.x) * (point.y - pi.y) / dy + pi.x);
		if (intersect) inside = !inside;
	}
	return inside;
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

bool point_in_any_light_polygon(vec2 point) {
	if (omni_point_count <= 2 || !point_in_omni_polygon(point)) return false;
	for(int l = 0; l < MAX_LIGHT_SOURCES; l++) {
		if (l >= light_count) break;
		int start = light_starts[l];
		int end = light_ends[l];
		if (end - start > 2 && point_in_light_polygon(point, start, end)) return true;
	}
	return false;
}

void fragment() {
	vec2 pixel_pos = SCREEN_UV / SCREEN_PIXEL_SIZE;
	bool visible_by_inner = omni_point_count > 2 && point_in_omni_polygon(pixel_pos) && length(pixel_pos - player_screen_pos) <= inner_light_radius;
	bool visible_by_player = (vision_point_count > 2 && point_in_polygon(pixel_pos)) || visible_by_inner || point_in_any_light_polygon(pixel_pos);
	if (!visible_by_player) {
		discard;
	}
	COLOR = texture(TEXTURE, UV) * COLOR;
}
