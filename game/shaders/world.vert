// Multiversal Van Life - world vertex shader (MIT). Per-vertex (Gouraud)
// lighting, PS1 style vertex snapping and linear fog.
in vec3 aPos;
in vec2 aUV;
in vec3 aNormal;
in vec4 aColor;

uniform mat4 uModel;
uniform mat4 uView;
uniform mat4 uProj;
uniform vec4 uTint;
uniform float uUnlit;
uniform float uNoFog;
uniform vec2 uUVOffset;
uniform vec3 uAmbient;
uniform vec3 uSunDir;
uniform vec3 uSunColor;
uniform vec3 uLightPos[8];
uniform vec3 uLightColor[8];
uniform float uLightRange[8];
uniform float uFogNear;
uniform float uFogFar;
uniform vec2 uSnap;

out vec2 vUV;
out vec4 vColor;
out float vFog;

void main() {
    vec4 world = uModel * vec4(aPos, 1.0);
    vec4 viewPos = uView * world;
    vec4 clip = uProj * viewPos;
    // snap to the low resolution pixel grid for that wobbly retro look
    if (clip.w > 0.0) {
        vec2 ndc = clip.xy / clip.w;
        ndc = floor(ndc * uSnap + 0.5) / uSnap;
        clip.xy = ndc * clip.w;
    }
    gl_Position = clip;

    vec3 n = normalize(mat3(uModel) * aNormal);
    vec3 light = uAmbient + uSunColor * max(dot(n, -uSunDir), 0.0);
    for (int i = 0; i < 8; ++i) {
        if (uLightRange[i] <= 0.0) continue;
        vec3 d = uLightPos[i] - world.xyz;
        float dist = length(d);
        float att = clamp(1.0 - dist / uLightRange[i], 0.0, 1.0);
        float lambert = max(dot(n, d / max(dist, 0.001)), 0.0) * 0.6 + 0.4;
        light += uLightColor[i] * att * att * lambert;
    }
    light = mix(light, vec3(1.0), uUnlit);
    vColor = vec4(aColor.rgb * light, aColor.a) * uTint;
    vUV = aUV + uUVOffset;
    float dist = length(viewPos.xyz);
    vFog = (1.0 - uNoFog) * clamp((dist - uFogNear) / max(uFogFar - uFogNear, 0.001), 0.0, 1.0);
}
