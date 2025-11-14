#version 460 core

out vec4 FragColor;

flat in int ColorID;

uniform sampler2D tex;
uniform vec4 u_color[256];

void main() {
    FragColor = u_color[ColorID];
}
