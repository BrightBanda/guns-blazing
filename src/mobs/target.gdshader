shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// Regular uniforms shared by everyone
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;

// INSTANCE UNIFORMS: These are unique per enemy on the GPU!
instance uniform vec4 flash_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
instance uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 color = texture(texture_albedo, UV) * albedo;
	// Mix the standard texture color with the flash color based on the modifier
	ALBEDO = mix(color.rgb, flash_color.rgb, flash_modifier);
}