// Multiversal Van Life - the sky: gradient, star field, the galaxy band,
// the star's disc, moons with phases and visible planets (MIT).
in vec2 vNdc;
uniform mat4 uInvViewProj;
uniform vec3 uTop;
uniform vec3 uHorizon;
uniform float uStars;
uniform float uTime;
uniform sampler2D uTex;
uniform vec4 uSun;          // direction, angular radius (0: none)
uniform vec4 uSunColor;     // colour, glow
uniform vec3 uLight;        // towards the star (moon phases)
uniform int uMoons;
uniform vec4 uMoonDir[4];   // direction, angular radius
uniform vec3 uMoonColor[4];
uniform int uPlanets;
uniform vec4 uPlanetDir[8];
uniform vec3 uPlanetColor[8];
uniform vec4 uBand;         // normal of the band's great circle, strength
uniform vec4 uBandCore;     // towards the galaxy's core, width
uniform vec3 uBandColor;
out vec4 fragColor;

float hash3(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Value noise on the sphere of directions.
float noise3(vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
               mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y),
               f.z);
}

// Angle between two unit vectors (stable for small angles).
float angle(vec3 a, vec3 b) { return 2.0 * asin(clamp(length(a - b) * 0.5, 0.0, 1.0)); }

void main() {
    vec4 far = uInvViewProj * vec4(vNdc, 1.0, 1.0);
    vec3 dir = normalize(far.xyz / far.w);
    float h = clamp(dir.y, 0.0, 1.0);
    vec3 base = mix(uHorizon, uTop, sqrt(h));
    vec3 col = base;
    float above = smoothstep(-0.02, 0.03, dir.y);   // bodies set behind the horizon
    float night = uStars * smoothstep(0.02, 0.3, h);

    // the galaxy band: a cloudy great circle, brightest towards the core
    if (uBand.w > 0.0) {
        float d = dot(dir, uBand.xyz) / max(uBandCore.w, 0.01);
        float core = 1.0 + 1.3 * pow(max(dot(dir, uBandCore.xyz), 0.0), 6.0);
        float clouds = 0.35 + 0.65 * noise3(dir * 9.0) * (0.6 + 0.4 * noise3(dir * 23.0));
        float dust = 1.0 - 0.6 * smoothstep(0.55, 0.8, noise3(dir * 15.0 + 3.7)) * exp(-d * d * 4.0);
        col += uBandColor * uBand.w * exp(-d * d) * core * clouds * dust * night;
    }

    // stars: a stereographic view of the sky (no seam, no pinch at the
    // zenith), turning slowly
    float spin = uTime * 0.002;
    vec2 xz = mat2(cos(spin), sin(spin), -sin(spin), cos(spin)) * dir.xz;
    vec3 stars = texture(uTex, xz / (1.0 + max(dir.y, 0.0)) * 2.5).rgb;
    col += stars * night;

    // planets: small bright points
    for (int i = 0; i < 8; ++i) {
        if (i >= uPlanets) break;
        float a = angle(dir, uPlanetDir[i].xyz);
        col += uPlanetColor[i] * smoothstep(uPlanetDir[i].w, 0.0, a) * night * 1.5;
    }

    // the star: a disc with a halo
    if (uSun.w > 0.0) {
        float a = angle(dir, uSun.xyz);
        float disc = step(a, uSun.w);
        float halo = uSunColor.w * exp(-a / max(uSun.w * 6.0, 0.02));
        col += (uSunColor.rgb * (halo + disc * 1.2) + disc * 0.3) * above;
    }

    // moons: discs lit from the star's side, so they show their phases
    for (int i = 0; i < 4; ++i) {
        if (i >= uMoons) break;
        vec3 m = uMoonDir[i].xyz;
        float r = uMoonDir[i].w;
        float a = angle(dir, m);
        if (a < r) {
            vec3 right = normalize(cross(m, abs(m.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
            vec3 up = cross(right, m);
            vec3 p = dir - m * dot(dir, m);
            vec2 q = vec2(dot(p, right), dot(p, up)) / sin(r);
            float z = sqrt(max(1.0 - dot(q, q), 0.0));
            vec3 n = right * q.x + up * q.y - m * z;   // faces the viewer
            float lit = smoothstep(-0.05, 0.15, dot(n, uLight));
            float shade = 0.75 + 0.25 * noise3(n * 6.0 + float(i) * 7.0);
            vec3 moon = base * 0.9 + uMoonColor[i] * (0.03 + lit * shade);
            col = mix(col, moon, above);
        }
    }
    fragColor = vec4(col, 1.0);
}
