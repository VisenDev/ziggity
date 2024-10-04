#version 330 core

in vec2 fragTexCoord;           
out vec4 finalColor;            

uniform sampler2D texture0; //base texture
uniform sampler2D texture1; //light map

void main() {
    vec4 baseColor = texture(texture0, fragTexCoord); // Sample the base color from texture0
    vec4 lightColor = texture(texture1, fragTexCoord); // Sample the light color from lightTexture

    // Add lighting
    finalColor = clamp(baseColor * lightColor , 0, 1);
}
