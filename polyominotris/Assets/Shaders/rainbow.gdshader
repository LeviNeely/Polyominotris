// Shader to make a moving rainbow gradient.

shader_type canvas_item;

void fragment() {
	// Get the color from the image
	vec4 color = texture(TEXTURE, UV);
	// Then, figure out the rainbow logic
	float shade = (UV.x * cos(radians(35.0))) - (UV.y * sin(radians(35.0)));
	shade = fract(shade + fract(TIME * 0.2));
	float x = 1.0 - abs(mod(shade / (1.0 / 6.0), 2.0) - 1.0);
	vec3 rainbow;
	if (shade < (1.0 / 6.0)) {
		rainbow = vec3(1.0, x, 0.0);
	}
	else if (shade < (1.0 / 3.0)) {
		rainbow = vec3(x, 1.0, 0.0);
	}
	else if (shade < 0.5) {
		rainbow = vec3(0, 1.0, x);
	}
	else if (shade < (2.0 / 3.0)) {
		rainbow = vec3(0.0, x, 1.0);
	}
	else if (shade < (5.0 / 6.0)) {
		rainbow = vec3(x, 0.0, 1.0);
	}
	else {
		rainbow = vec3(1.0, 0.0, x);
	}
	// We don't apply the logic if the color is black (think about moving this into an if/else statement for optimization (not a super big deal)
	if (color.rgb == vec3(1.0)) {
		COLOR = mix(color, vec4(rainbow, color.a), 0.5);
	}
	else {
		COLOR = color;
	}
}