shader_type canvas_item;

uniform vec2 player_screen_pos;
uniform float player_angle;
uniform float cone_half_angle;
uniform float vision_range;
uniform float darkness_alpha : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec2 pixel_pos = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 to_pixel = pixel_pos - player_screen_pos;
	float dist = length(to_pixel);
	float pixel_angle = atan(to_pixel.y, to_pixel.x);
	float angle_diff = abs(pixel_angle - player_angle);
	if (angle_diff > 3.14159) angle_diff = 6.28318 - angle_diff;

	if (dist < vision_range && angle_diff < cone_half_angle) {
		COLOR.a = 0.0;
	} else {
   	    COLOR = vec4(0.0, 0.0, 0.0, darkness_alpha); 
	}
}
