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

void main()                     
{                               
   vec4 texelColor = texture(texture0, fragTexCoord);
   vec4 myColor = texelColor * colDiffuse * fragColor;  

   // Initialize finalColor with a dark color (e.g., black)
   finalColor = vec4(0.0, 0.0, 0.0, 1.0);

   for (int i = 0; i < num_active_lights; i++) {
      // Calculate the distance from the fragment to the light source
      float distance = length(position[i] - fragTexCoord);

      // Check if the fragment is within the light's radius
      if (distance < radius[i]) {
         // Calculate the light's contribution based on its color and intensity
         // This is a simple linear falloff, you might want to use a different falloff function
         float intensity = 1.0 - (distance / radius[i]);
         vec4 lightContribution = color[i] * intensity;

         // Multiply the light's contribution with the texture color to simulate lighting
         // This will make the texture visible near the light source
         finalColor += myColor * lightContribution;
      }
   }

   // Ensure the final color does not exceed the maximum color value
   finalColor = clamp(finalColor, 0.0, 1.0);
}



//#version 330 core
//
//in vec2 fragTexCoord;           
//in vec4 fragColor;       
//out vec4 finalColor;            
//
//uniform sampler2D texture0;     
//uniform vec4 colDiffuse;        
//
//#define MAX_LIGHTS 64
//uniform vec2[MAX_LIGHTS] position;
//uniform vec4[MAX_LIGHTS] color;
//uniform float[MAX_LIGHTS] radius;
//uniform int num_active_lights;
//uniform int screen_width;
//uniform int screen_height;
//
//void main()                     
//{                               
//   vec4 texelColor = texture(texture0, fragTexCoord);
//   vec4 myColor = texelColor*colDiffuse*fragColor;  
//
//   finalColor = myColor;
//
//   for (int i = 0; i < num_active_lights; i++) {
//
//      // Calculate the distance, taking into account the adjusted position
//      float distance = length(position[i] - fragTexCoord);
//
//      // Check if the fragment is within the light's radius
//      if (distance < radius[i]) {
//         // Calculate the light's contribution based on its color and intensity
//         // This is a simple linear falloff, you might want to use a different falloff function
//         float intensity = 1.0 - (distance / radius[i]);
//         vec4 lightContribution = color[i] * intensity;
//
//         // Add the light's contribution to the final color
//         finalColor += lightContribution;
//      }
//   }
//}
