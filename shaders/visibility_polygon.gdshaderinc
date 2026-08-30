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
