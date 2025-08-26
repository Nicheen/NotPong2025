shader_type canvas_item;

uniform vec4 water_color : source_color = vec4(0.2, 0.6, 0.8, 0.7);
uniform float wave_speed : hint_range(0.0, 2.0) = 1.0;
uniform float wave_frequency : hint_range(0.0, 10.0) = 2.0;
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.02;

void fragment() {
    vec2 uv = UV;
    
    // Create simple wave effect
    float wave = sin(uv.x * wave_frequency + TIME * wave_speed) * wave_amplitude;
    uv.y += wave;
    
    // Simple water color with transparency
    COLOR = water_color;
}