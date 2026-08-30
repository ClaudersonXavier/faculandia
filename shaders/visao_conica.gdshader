shader_type canvas_item;

#include "res://shaders/visibility_polygon.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float vision_distance_screen = 520.0;
uniform vec2 light_centers[MAX_LIGHT_SOURCES];
uniform float light_radii[MAX_LIGHT_SOURCES];
uniform float darkness_alpha : hint_range(0.0, 1.0) = 0.88;
uniform float outside_saturation : hint_range(0.0, 1.0) = 0.12;
uniform float outside_brightness : hint_range(0.0, 1.0) = 0.2;
uniform float fade_edge = 26.0;
uniform vec3 warm_light = vec3(1.0, 0.78, 0.42);

float distance_to_segment(vec2 point, vec2 a, vec2 b) {
	vec2 pa = point - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec2 pixel_pos = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec4 base = texture(screen_texture, SCREEN_UV);

	// 1. Visao Direta (Cone do jogador)
	float cone_visible = 0.0;
	if (vision_point_count > 2 && point_in_polygon(pixel_pos)) {
		float dist_from_player = length(pixel_pos - player_screen_pos);
		float dist_fade = 1.0 - smoothstep(vision_distance_screen * 0.88, vision_distance_screen, dist_from_player);

		// Fade suave apenas nas bordas laterais do feixe de luz
		float d_left = distance_to_segment(pixel_pos, vision_points[0], vision_points[1]);
		float d_right = distance_to_segment(pixel_pos, vision_points[0], vision_points[vision_point_count - 1]);
		float side_dist = min(d_left, d_right);
		float side_fade = smoothstep(0.0, fade_edge, side_dist);

		cone_visible = side_fade * dist_fade;
	}

	// 2. Percepcao Periferica (Luz interna curta ao redor do jogador)
	float inner_dist = length(pixel_pos - player_screen_pos);
	float inner_fade = 1.0 - smoothstep(inner_light_radius * 0.45, inner_light_radius, inner_dist);
	bool inside_omni = (omni_point_count <= 2) || point_in_omni_polygon(pixel_pos);
	float inner_visible = inside_omni ? inner_fade : 0.0;

	// 3. Fontes de Luz no cenario
	float total_light_visible = 0.0;
	if (inside_omni) {
		for(int l = 0; l < MAX_LIGHT_SOURCES; l++) {
			if (l >= light_count) break;
			int start = light_starts[l];
			int end = light_ends[l];
			if (end - start > 2 && point_in_light_polygon(pixel_pos, start, end)) {
				float light_dist = length(pixel_pos - light_centers[l]);
				float light_rad = light_radii[l];
				float light_fade = 1.0 - smoothstep(light_rad * 0.45, light_rad, light_dist);
				total_light_visible = max(total_light_visible, light_fade);
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
