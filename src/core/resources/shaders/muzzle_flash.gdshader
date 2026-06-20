shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform vec4 flash_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float flash_intensity : hint_range(0.0, 20.0) = 0.0;

// Set a new random value each shot
uniform float seed = 0.0;

void fragment()
{
    vec2 p = UV - vec2(0.5);

    float r = length(p);
    float angle = atan(p.y, p.x);

    // Randomize spike count
    float spikes = mix(4.0, 8.0, fract(seed * 17.31));

    // Create star pattern
    float star = abs(cos(angle * spikes));

    // Randomize spike sharpness
    float sharpness = mix(6.0, 12.0, fract(seed * 8.73));
    star = pow(star, sharpness);

    // Radial falloff
    float mask = smoothstep(0.5, 0.0, r);

    float core = smoothstep(0.25, 0.0, r);
	float flash = core + star * mask;

    ALBEDO = flash_color.rgb * flash_intensity;
    ALPHA = flash * min(flash_intensity, 1.0);
}