shader_type canvas_item;

// Grid settings
uniform float grid_size : hint_range(10.0, 200.0) = 50.0;
uniform float line_width : hint_range(0.5, 10.0) = 2.0;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.75);
uniform vec4 background_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float line_alpha : hint_range(0.0, 1.0) = 0.3;

// Distortion effects (up to 5 simultaneous distortions)
uniform vec2 distortion_centers[5];
uniform float distortion_forces[5];
uniform float distortion_radiuses[5];
uniform float distortion_times[5];
uniform int active_distortions = 0;

// Animation
uniform float time : hint_range(0.0, 100.0) = 0.0;

vec2 apply_distortions(vec2 uv, vec2 pixel_pos) {
    vec2 distorted_pos = pixel_pos;
    
    for (int i = 0; i < active_distortions && i < 5; i++) {
        vec2 center = distortion_centers[i];
        float force = distortion_forces[i];
        float radius = distortion_radiuses[i];
        float dist_time = distortion_times[i];
        
        // Calculate distance from distortion center
        float distance = length(pixel_pos - center);
        
        // Create expanding wave effect
        float wave_progress = dist_time * 200.0; // Speed of wave expansion
        float wave_thickness = 30.0;
        
        // Only distort if we're within the wave ring
        float wave_start = wave_progress - wave_thickness;
        float wave_end = wave_progress + wave_thickness;
        
        if (distance >= wave_start && distance <= wave_end && distance <= radius) {
            // Calculate wave intensity (stronger at center of wave ring)
            float wave_center = wave_progress;
            float wave_intensity = 1.0 - abs(distance - wave_center) / wave_thickness;
            wave_intensity = smoothstep(0.0, 1.0, wave_intensity);
            
            // Apply radial distortion
            vec2 direction = normalize(pixel_pos - center);
            float distortion_amount = force * wave_intensity * sin(dist_time * 10.0) * 0.5;
            
            // Add some rotational component for more interesting distortion
            vec2 perpendicular = vec2(-direction.y, direction.x);
            distorted_pos += direction * distortion_amount;
            distorted_pos += perpendicular * distortion_amount * 0.3;
        }
    }
    
    return distorted_pos;
}

void fragment() {
    // Get pixel position in world coordinates
    vec2 pixel_pos = UV * vec2(1152.0, 648.0);
    
    // Apply distortion effects
    vec2 distorted_pixel_pos = apply_distortions(UV, pixel_pos);
    
    // Calculate grid position using distorted coordinates
    vec2 grid_pos = mod(distorted_pixel_pos, grid_size);
    
    // Calculate distance to nearest grid line
    float dist_to_line = min(
        min(grid_pos.x, grid_size - grid_pos.x),
        min(grid_pos.y, grid_size - grid_pos.y)
    );
    
    // Create line effect with smooth transition
    float line_factor = 1.0 - smoothstep(0.0, line_width, dist_to_line);
    
    // Add some subtle animation to the grid when no distortions are active
    float base_animation = sin(time * 2.0 + pixel_pos.x * 0.01 + pixel_pos.y * 0.01) * 0.1 + 0.9;
    
    // Mix background and line colors
    vec3 final_color = mix(background_color.rgb, line_color.rgb * base_animation, line_factor);
    float final_alpha = mix(background_color.a, line_color.a * line_alpha, line_factor);
    
    COLOR = vec4(final_color, final_alpha);
}