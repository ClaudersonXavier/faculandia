shader_type canvas_item;

#include "res://shaders/visibility_polygon.gdshaderinc"

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
