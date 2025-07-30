shader_type canvas_item;

uniform vec2 center;
uniform float force;
uniform sampler2D distortionTexture;
uniform sampler2D SCREEN_TEXTURE;
void fragment() {
	vec2 distortedUV = SCREEN_UV + texture(distortionTexture, UV).r * 0.05;
	vec4 screenColor = texture(SCREEN_TEXTURE, distortedUV);
	COLOR = screenColor;
}
