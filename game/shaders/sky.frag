// Multiversal Van Life - gradient sky with a scrolling star field (MIT).
in vec2 vNdc;
uniform mat4 uInvViewProj;
uniform vec3 uTop;
uniform vec3 uHorizon;
uniform float uStars;
uniform float uTime;
uniform sampler2D uTex;
out vec4 fragColor;

void main() {
    vec4 far = uInvViewProj * vec4(vNdc, 1.0, 1.0);
    vec3 dir = normalize(far.xyz / far.w);
    float h = clamp(dir.y, 0.0, 1.0);
    vec3 col = mix(uHorizon, uTop, sqrt(h));
    float u = atan(dir.z, dir.x) / 6.2831853 + 0.5;
    float v = 1.0 - h;
    vec3 stars = texture(uTex, vec2(u * 4.0 + uTime * 0.002, v * 2.0)).rgb;
    col += stars * uStars * smoothstep(0.02, 0.3, h);
    fragColor = vec4(col, 1.0);
}
