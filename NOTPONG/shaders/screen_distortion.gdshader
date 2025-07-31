shader_type canvas_item;

// Distortion effects (up to 5 simultaneous distortions)
uniform vec2 distortion_centers[5];
uniform float distortion_forces[5];
uniform float distortion_radiuses[5];
uniform float distortion_times[5];
uniform int active_distortions = 0;

// Distortion texture for more realistic effects
uniform sampler2D distortionTexture;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;

vec2 apply_screen_distortions(vec2 screen_uv) {
    vec2 distorted_uv = screen_uv;
    vec2 screen_size = vec2(1152.0, 648.0); // Your game resolution
    
    for (int i = 0; i < active_distortions && i < 5; i++) {
        vec2 center_uv = distortion_centers[i] / screen_size;
        float force = distortion_forces[i];
        float max_radius = distortion_radiuses[i] / max(screen_size.x, screen_size.y);
        float dist_time = distortion_times[i];
        
        // Calculate distance from distortion center
        float distance_to_center = length(screen_uv - center_uv);
        
        // Create expanding shockwave ring
        float wave_speed = 0.4; // How fast the wave expands
        float wave_radius = dist_time * wave_speed;
        float wave_thickness = 0.15; // Thickness of the shockwave ring
        
        // Only apply distortion within the expanding ring
        if (distance_to_center <= wave_radius && distance_to_center >= (wave_radius - wave_thickness) && wave_radius <= max_radius) {
            // Calculate position within the wave ring (0.0 to 1.0)
            float ring_position = 1.0 - ((wave_radius - distance_to_center) / wave_thickness);
            ring_position = clamp(ring_position, 0.0, 1.0);
            
            // Sample the distortion texture using the ring position
            // Use ring_position as the texture coordinate to get gradient effect
            vec2 distortion_sample_uv = vec2(ring_position, 0.5);
            float distortion_strength = texture(distortionTexture, distortion_sample_uv).r;
            
            // Create fade-out effect as wave expands
            float fade = 1.0 - (wave_radius / max_radius);
            fade = fade * fade; // Quadratic fade for smoother effect
            
            // Calculate direction from explosion center
            vec2 direction = normalize(screen_uv - center_uv);
            
            // Apply distortion based on texture sample and force
            float final_distortion = distortion_strength * force * fade * 0.02;
            
            // Add some turbulence for more realistic effect
            float turbulence = sin(dist_time * 6.0 + distance_to_center * 20.0) * 0.3;
            final_distortion *= (1.0 + turbulence);
            
            // Apply the distortion
            distorted_uv += direction * final_distortion;
            
            // Add slight rotational component for more dynamic effect
            vec2 perpendicular = vec2(-direction.y, direction.x);
            distorted_uv += perpendicular * final_distortion * 0.2;
        }
    }
    
    return distorted_uv;
}

void fragment() {
    // Apply distortions to screen UV
    vec2 distorted_uv = apply_screen_distortions(SCREEN_UV);
    
    // Sample the screen texture with distorted coordinates
    vec4 screen_color = texture(SCREEN_TEXTURE, distorted_uv);
    
    COLOR = screen_color;
}