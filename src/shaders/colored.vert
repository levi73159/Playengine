#version 330 core

layout(location = 0) in vec4 aPos;

uniform mat4 u_MVP;

void main() {
    gl_Position = aPos * u_MVP;
}
