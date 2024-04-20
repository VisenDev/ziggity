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

void main()                     
{                               
   vec4 texelColor = texture(texture0, fragTexCoord);
   vec4 myColor = texelColor*colDiffuse*fragColor;  

   // Loop through each light
   for(int i = 0; i < num_active_lights; i++) {
      float dist = distance(fragTexCoord, position[i]);
      if(dist < 10) {
         myColor = vec4(1, 1, 0, 1.0);
      }
   }

   // Normalize the distance to the center of the screen
   float distanceToCenter = distance(fragTexCoord, vec2(0.5, 0.5));
   float radius = 0.15; // Adjust this value to change the size of the dot

   // Check if the current fragment is within the desired radius
   if (distanceToCenter < radius) {
      myColor = vec4(0.8, 0.6, 0.1, 1.0);
   }

   finalColor = myColor;
}
