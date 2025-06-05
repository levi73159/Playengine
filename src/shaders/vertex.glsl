#version 330 core

layout(location = 0) in vec4 aPos;
layout(location = 1) in vec2 aTextCoord;

out vec2 vTextCoord;

void main() {
    vTextCoord = aTextCoord;
    gl_Position = aPos;
}
