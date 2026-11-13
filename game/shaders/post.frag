// Multiversal Van Life - nearest upscale with 4x4 ordered dithering and a
// reduced (5 bits per channel) colour depth (MIT).
in vec2 vUV;
uniform sampler2D uTex;
uniform float uDither;
uniform vec2 uSize;
out vec4 fragColor;

float bayer(vec2 p) {
    int x = int(mod(p.x, 4.0)), y = int(mod(p.y, 4.0));
    int i = x + y * 4;
    int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
    return float(m[i]) / 16.0 - 0.5;
}

void main() {
    vec4 c = texture(uTex, vUV);
    if (uDither > 0.5) {
        vec2 px = floor(vUV * uSize);
        c.rgb = floor(c.rgb * 31.0 + 0.5 + bayer(px)) / 31.0;
    }
    fragColor = c;
}
