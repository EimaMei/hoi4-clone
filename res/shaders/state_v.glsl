#version 460 core

flat out int ColorID;

layout (location = 0) in vec2 aPos;

uniform mat4 u_transform;

void main() {
    gl_Position = u_transform * vec4(aPos, 0.0, 1.0);
    ColorID = gl_DrawID;
}
