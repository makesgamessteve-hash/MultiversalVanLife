// Multiversal Van Life - UI fragment shader (MIT).
in vec2 vUV;
in vec4 vColor;
uniform sampler2D uTex;
out vec4 fragColor;
void main() {
    fragColor = texture(uTex, vUV) * vColor;
}
