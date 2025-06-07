#version 330 core

// fragment shader
out vec4 FragColor;

uniform vec4 u_Color;
uniform sampler2D u_Texture;

in vec2 vTextCoord;

void main() {
    vec4 baseColor = texture(u_Texture, vTextCoord);
    vec4 color = u_Color * baseColor;

    FragColor = color;
}
