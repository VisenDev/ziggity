#version 330 core

in vec2 fragTexCoord;           
in vec4 fragColor;       
out vec4 finalColor;            

uniform sampler2D texture0;     
uniform sampler2D lightTexture;   // Contains the corresponding lighting values for all texture0 coordinates
uniform vec4 ambientColor;       // Ambient light color

void main() {
    vec4 baseColor = texture(texture0, fragTexCoord); // Sample the base color from texture0
    vec4 lightColor = texture(lightTexture, fragTexCoord); // Sample the light color from lightTexture

    // Calculate the diffuse component by modulating baseColor with lightColor
    vec4 diffuseColor = baseColor * lightColor;
    
    // Combine ambient and diffuse lighting
    finalColor = (diffuseColor + ambientColor) * fragColor;
}
