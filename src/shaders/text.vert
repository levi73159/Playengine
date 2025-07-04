#version 330 core

layout(location = 0) in vec4 aPos;
layout(location = 1) in vec2 aTexCoords;

out vec2 TexCoords;

uniform mat4 u_MVP;

void main()
{
    gl_Position = aPos * u_MVP;
    TexCoords = aTexCoords;
}
