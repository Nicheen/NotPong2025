shader_type canvas_item;

uniform sampler2D texture2;
uniform sampler2D colorTexture;
uniform vec2 scroll1 = vec2(0.1, 0.1);
uniform vec2 scroll2 = vec2(0.2, 0.2);
uniform float corner_radius : hint_range(0.0, 0.5) = 0.01;

void fragment() {
    // Calculate the original color
    float textureColor1 = texture(TEXTURE, UV + scroll1 * TIME).r;
    float textureColor2 = texture(texture2, UV + scroll2 * TIME).r;
    float energy = textureColor1 * textureColor2 - (1.0 - UV.y);
    vec4 color = texture(colorTexture, vec2(energy));
    
    // Create mask for bottom corners
    float mask = 1.0;
    
    // Bottom left corner
    if (UV.x < corner_radius && UV.y > corner_radius && UV.y > 1.0 - corner_radius) {
        vec2 corner_pos = vec2(corner_radius, 1.0 - corner_radius);
        float dist = distance(UV, corner_pos);
        mask = smoothstep(corner_radius, corner_radius - 0.01, dist);
    }
    
    // Bottom right corner
    if (UV.x > (1.0 - corner_radius) && UV.y > corner_radius && UV.y > 1.0 - corner_radius) {
        vec2 corner_pos = vec2(1.0 - corner_radius, 1.0 - corner_radius);
        float dist = distance(UV, corner_pos);
        mask = smoothstep(corner_radius, corner_radius - 0.01, dist);
    }
    
    COLOR = color;
    COLOR.a *= mask;
}