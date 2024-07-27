#version 330 core

in vec2 fragTexCoord;           
in vec4 fragColor;       
out vec4 finalColor;            
//in vec2 TexCoords;
//out vec4 finalColor;

uniform sampler2D texture1;     
uniform float blur_size; // Size of the blur kernel, e.g., 1.0/512.0 for a 512x512 texture

void main()
{
    vec2 tex_offset = vec2(blur_size); // Size of one texel
    vec3 result = vec3(0.0);

    // Sample the neighboring pixels
    for(int x = -1; x <= 1; x++)
    {
        for(int y = -1; y <= 1; y++)
        {
            vec2 offset = vec2(float(x), float(y)) * tex_offset;
            result += texture(texture1, fragTexCoord + offset).rgb;
        }
    }

    // Average the result
    result /= 9.0;

    finalColor = vec4(result, 1.0);
}
