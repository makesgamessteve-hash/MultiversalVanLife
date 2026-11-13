// Multiversal Van Life - world fragment shader (MIT).
in vec2 vUV;
in vec4 vColor;
in float vFog;
uniform sampler2D uTex;
uniform vec3 uFogColor;
out vec4 fragColor;

void main() {
    vec4 c = texture(uTex, vUV) * vColor;
    if (c.a < 0.5 && vColor.a > 0.99) discard; // alpha cutout for sprites
    fragColor = vec4(mix(c.rgb, uFogColor, vFog), c.a);
}
