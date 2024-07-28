#version 330 core

in vec2 fragTexCoord;           
in vec4 fragColor;       
out vec4 finalColor;            

uniform sampler2D texture0; //texture to blur
uniform float blur_size; // Size of the blur kernel, e.g., 1.0/512.0 for a 512x512 texture

void main()
{

    vec2 tex_offset = vec2(blur_size); // Size of one texel
    vec4 result = vec4(0.0);

    // Gaussian kernel weights (flattened)
    float kernel[9] = float[9](
        1.0, 2.0, 1.0,
        2.0, 4.0, 2.0,
        1.0, 2.0, 1.0
    );

    float kernel_sum = 16.0; // Sum of all kernel weights

    // Coordinates for the 3x3 kernel
    int offsets[18] = int[18](
        -1, -1,  -1, 0,  -1, 1,
         0, -1,   0, 0,   0, 1,
         1, -1,   1, 0,   1, 1
    );

    // Sample the neighboring pixels
    for(int i = 0; i < 9; i++)
    {
        vec2 offset = vec2(float(offsets[2 * i]), float(offsets[2 * i + 1])) * tex_offset;
        result += texture(texture0, fragTexCoord + offset).rgba * kernel[i];
    }

    // Normalize the result
    result /= kernel_sum;

    //ignore results if no colors are found
    if(result.a <= 0.2) {
        finalColor = vec4(0.0);
        return;
    }

    result.a *= 0.33;
    result.rbg *= 3;

    finalColor = clamp(result, 0, 1);
}
