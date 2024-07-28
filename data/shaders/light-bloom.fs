#version 330 core

in vec2 fragTexCoord;           
in vec4 fragColor;       
out vec4 finalColor;            

uniform sampler2D texture0;     
uniform vec4 colDiffuse;        

#define MAX_LIGHTS 64
uniform vec2[MAX_LIGHTS] position;
uniform vec4[MAX_LIGHTS] color;
uniform float[MAX_LIGHTS] radius;
uniform int num_active_lights;
uniform int screen_width;
uniform int screen_height;

// Function to apply bloom effect
vec4 applyBloom(vec4 color) {
    // Parameters for bloom effect
    const float threshold = 0.8;
    const float blurAmount = 0.01; // Adjust this value for more/less blur
    const int blurSamples = 10;

    vec4 bloomColor = vec4(0.0);

    // Bright-pass filter: extract bright areas
    if (color.r > threshold || color.g > threshold || color.b > threshold) {
        // Apply blur to create bloom effect
        for (int x = -blurSamples; x <= blurSamples; x++) {
            for (int y = -blurSamples; y <= blurSamples; y++) {
                bloomColor += texture(texture0, fragTexCoord + vec2(x, y) * blurAmount);
            }
        }
        bloomColor /= (blurSamples * 2 + 1) * (blurSamples * 2 + 1);
    }

    return bloomColor;
}

void main()                     
{                               
    vec4 texelColor = texture(texture0, fragTexCoord);
    vec4 myColor = texelColor * colDiffuse * fragColor;  

    // Initialize finalColor with a dark color (e.g., black)
    finalColor = vec4(0.0, 0.0, 0.0, 1.0);
         
    for (int i = 0; i < num_active_lights; i++) {
        // Calculate the distance from the fragment to the light source
        
        // Assuming screen_width and screen_height are available
        float aspect_ratio = float(screen_width) / float(screen_height);

        vec2 shifted_position = position[i] - fragTexCoord;
        vec2 adjusted_position = vec2(shifted_position.x * aspect_ratio, shifted_position.y) + fragTexCoord;

        // Adjust the distance calculation based on the aspect ratio
        // This scales the distance to maintain a circular shape
        float distance = length(adjusted_position - fragTexCoord);
        
        // Check if the fragment is within the light's radius
        if (distance < radius[i] * 0.33) {
            finalColor += myColor * color[i] * 1.25;
        } else if (distance < radius[i] * 0.66) {
            finalColor += myColor * 0.66 * color[i];
        } else if (distance < radius[i]) {
            finalColor += myColor * 0.33 * color[i];
        }
    }

    // Apply bloom effect to the final color
    vec4 bloomColor = applyBloom(finalColor);
    finalColor += bloomColor;

    // Ensure the final color does not exceed the maximum color value
    finalColor = clamp(finalColor, 0.0, 1.0);
}
