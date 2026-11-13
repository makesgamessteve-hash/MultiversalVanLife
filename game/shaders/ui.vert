// Multiversal Van Life - UI vertex shader (MIT).
in vec3 aPos;
in vec2 aUV;
in vec4 aColor;
uniform mat4 uProj;
out vec2 vUV;
out vec4 vColor;
void main() {
    vUV = aUV;
    vColor = aColor;
    gl_Position = uProj * vec4(aPos.xy, 0.0, 1.0);
}
