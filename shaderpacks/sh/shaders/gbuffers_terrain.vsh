#version 120

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;


attribute vec4 mc_Entity;

uniform int worldTime;
uniform float frameTimeCounter;
uniform float rainStrength;

varying vec3 globalNormal;
varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 viewVector;
varying vec2 waves;

varying float distance;

varying float materialIDs;

#define WAVING_GRASS
#define WAVING_WHEAT
#define WAVING_LEAVES

void main() {



	texcoord = gl_MultiTexCoord0;

	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	
	vec4 position = gl_Vertex;
	

	
	
	//Gather materials
	materialIDs = 1.0f;

	//Grass
	if (mc_Entity.x == 31.0) {
		materialIDs = max(materialIDs, 2.0f);
	}
	
	//Wheat
	if (mc_Entity.x == 59.0) {
		materialIDs = max(materialIDs, 2.0f);
	}	
	
	//Leaves
	if (mc_Entity.x == 18.0) {
		materialIDs = max(materialIDs, 3.0f);
	}	

	
	//Gold block
	if (mc_Entity.x == 41) {
		materialIDs = max(materialIDs, 20.0f);
	}
	
	//Iron block
	if (mc_Entity.x == 42) {
		materialIDs = max(materialIDs, 21.0f);
	}
	
	//Diamond Block
	if (mc_Entity.x == 57) {
		materialIDs = max(materialIDs, 22.0f);
	}
	
	//Emerald Block
	if (mc_Entity.x == -123) {
		materialIDs = max(materialIDs, 23.0f);
	}
	
	
	
	//sand
	if (mc_Entity.x == 12) {
		materialIDs = max(materialIDs, 24.0f);
	}

	//sandstone
	if (mc_Entity.x == 24 || mc_Entity.x == -128) {
		materialIDs = max(materialIDs, 25.0f);
	}
	
	//stone
	if (mc_Entity.x == 1) {
		materialIDs = max(materialIDs, 26.0f);
	}
	
	//cobblestone
	if (mc_Entity.x == 4) {
		materialIDs = max(materialIDs, 27.0f);
	}
	
	//wool
	if (mc_Entity.x == 35) {
		materialIDs = max(materialIDs, 28.0f);
	}


	//torch	
	if (mc_Entity.x == 50) {
		materialIDs = max(materialIDs, 30.0f);
	}

	//lava
	if (mc_Entity.x == 10 || mc_Entity.x == 11) {
		materialIDs = max(materialIDs, 31.0f);
	}

	//glowstone and lamp
	if (mc_Entity.x == 89 || mc_Entity.x == 124) {
		materialIDs = max(materialIDs, 32.0f);
	}

	//fire
	if (mc_Entity.x == 51) {
		materialIDs = max(materialIDs, 33.0f);
	}



	float tick = frameTimeCounter;
	
	
float grassWeight = mod(texcoord.t * 16.0f, 1.0f / 16.0f);

float lightWeight = clamp((lmcoord.t * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);
	  lightWeight *= 1.1f;
	  lightWeight -= 0.1f;
	  lightWeight = max(0.0f, lightWeight);
	  lightWeight = pow(lightWeight, 5.0f);
	  
	  // if (texcoord.t < 0.65f) {
	  // 	grassWeight = 1.0f;
	  // } else {
	  // 	grassWeight = 0.0f;
	  // }	 

	  if (grassWeight < 0.01f) {
	  	grassWeight = 1.0f;
	  } else {
	  	grassWeight = 0.0f;
	  }

const float pi = 3.14159265f;
	
#ifdef WAVING_GRASS	
//Grass//
	if (mc_Entity.x == 31.0) {
		float speed = 0.4;
		
		float magnitude = sin((tick * pi / (28.0)) + position.x + position.z) * 0.1 + 0.1;
			  magnitude *= grassWeight * 0.5f;
			  magnitude *= lightWeight;
		float d0 = sin(tick * pi / (122.0 * speed)) * 3.0 - 1.5 + position.z;
		float d1 = sin(tick * pi / (152.0 * speed)) * 3.0 - 1.5 + position.x;
		float d2 = sin(tick * pi / (122.0 * speed)) * 3.0 - 1.5 + position.x;
		float d3 = sin(tick * pi / (152.0 * speed)) * 3.0 - 1.5 + position.z;
		position.x += sin((tick * pi / (28.0 * speed)) + (position.x + d0) * 0.1 + (position.z + d1) * 0.1) * magnitude * (1.0f + rainStrength * 1.4f);
		position.z += sin((tick * pi / (28.0 * speed)) + (position.z + d2) * 0.1 + (position.x + d3) * 0.1) * magnitude * (1.0f + rainStrength * 1.4f);
	}
	
	
	//small leaf movement
	if (mc_Entity.x == 31.0) {
		float speed = 0.04;
		
		float magnitude = (sin(((position.y + position.x)/2.0 + tick * pi / ((28.0)))) * 0.05 + 0.15) * 0.4;
			  magnitude *= grassWeight * 0.5f;
			  magnitude *= lightWeight;
		float d0 = sin(tick * pi / (112.0 * speed)) * 3.0 - 1.5;
		float d1 = sin(tick * pi / (142.0 * speed)) * 3.0 - 1.5;
		float d2 = sin(tick * pi / (112.0 * speed)) * 3.0 - 1.5;
		float d3 = sin(tick * pi / (142.0 * speed)) * 3.0 - 1.5;
		position.x += sin((tick * pi / (18.0 * speed)) + (-position.x + d0)*1.6 + (position.z + d1)*1.6) * magnitude * (1.0f + rainStrength * 1.7f);
		position.z += sin((tick * pi / (18.0 * speed)) + (position.z + d2)*1.6 + (-position.x + d3)*1.6) * magnitude * (1.0f + rainStrength * 1.7f);
		position.y += sin((tick * pi / (11.0 * speed)) + (position.z + d2) + (position.x + d3)) * (magnitude/3.0) * (1.0f + rainStrength * 1.7f);
	}
	
#endif	



#ifdef WAVING_WHEAT
//Wheat//
	if (mc_Entity.x == 59.0 && texcoord.t < 0.35) {
		float speed = 0.1;
		
		float magnitude = sin((tick * pi / (28.0)) + position.x + position.z) * 0.12 + 0.02;
			  magnitude *= grassWeight * 0.2f;
			  magnitude *= lightWeight;
		float d0 = sin(tick * pi / (122.0 * speed)) * 3.0 - 1.5 + position.z;
		float d1 = sin(tick * pi / (152.0 * speed)) * 3.0 - 1.5 + position.x;
		float d2 = sin(tick * pi / (122.0 * speed)) * 3.0 - 1.5 + position.x;
		float d3 = sin(tick * pi / (152.0 * speed)) * 3.0 - 1.5 + position.z;
		position.x += sin((tick * pi / (28.0 * speed)) + (position.x + d0) * 0.1 + (position.z + d1) * 0.1) * magnitude;
		position.z += sin((tick * pi / (28.0 * speed)) + (position.z + d2) * 0.1 + (position.x + d3) * 0.1) * magnitude;
	}
	
	//small leaf movement
	if (mc_Entity.x == 59.0 && texcoord.t < 0.35) {
		float speed = 0.04;
		
		float magnitude = (sin(((position.y + position.x)/2.0 + tick * pi / ((28.0)))) * 0.025 + 0.075) * 0.2;
			  magnitude *= grassWeight;
			  magnitude *= lightWeight;
		float d0 = sin(tick * pi / (112.0 * speed)) * 3.0 - 1.5;
		float d1 = sin(tick * pi / (142.0 * speed)) * 3.0 - 1.5;
		float d2 = sin(tick * pi / (112.0 * speed)) * 3.0 - 1.5;
		float d3 = sin(tick * pi / (142.0 * speed)) * 3.0 - 1.5;
		position.x += sin((tick * pi / (18.0 * speed)) + (-position.x + d0)*1.6 + (position.z + d1)*1.6) * magnitude * (1.0f + rainStrength * 2.0f);
		position.z += sin((tick * pi / (18.0 * speed)) + (position.z + d2)*1.6 + (-position.x + d3)*1.6) * magnitude * (1.0f + rainStrength * 2.0f);
		position.y += sin((tick * pi / (11.0 * speed)) + (position.z + d2) + (position.x + d3)) * (magnitude/3.0) * (1.0f + rainStrength * 2.0f);
	}



#endif
	
	

#ifdef WAVING_LEAVES
//Leaves//



	
		
	if (mc_Entity.x == 18.0 && texcoord.t < 1.90 && texcoord.t > -1.0) {
		float speed = 0.05;


			  //lightWeight = max(0.0f, 1.0f - (lightWeight * 5.0f));
		
		float magnitude = (sin((position.y + position.x + tick * pi / ((28.0) * speed))) * 0.15 + 0.15) * 0.30 * lightWeight;
			  magnitude *= grassWeight;
			  magnitude *= lightWeight;
		float d0 = sin(tick * pi / (112.0 * speed)) * 3.0 - 1.5;
		float d1 = sin(tick * pi / (142.0 * speed)) * 3.0 - 1.5;
		float d2 = sin(tick * pi / (132.0 * speed)) * 3.0 - 1.5;
		float d3 = sin(tick * pi / (122.0 * speed)) * 3.0 - 1.5;
		position.x += sin((tick * pi / (18.0 * speed)) + (-position.x + d0)*1.6 + (position.z + d1)*1.6) * magnitude * (1.0f + rainStrength * 1.0f);
		position.z += sin((tick * pi / (17.0 * speed)) + (position.z + d2)*1.6 + (-position.x + d3)*1.6) * magnitude * (1.0f + rainStrength * 1.0f);
		position.y += sin((tick * pi / (11.0 * speed)) + (position.z + d2) + (position.x + d3)) * (magnitude/2.0) * (1.0f + rainStrength * 1.0f);
		
	}
	

	//lower leaf movement
	if (mc_Entity.x == 18.0) {
		float speed = 0.075;


		
		float magnitude = (sin((tick * pi / ((28.0) * speed))) * 0.05 + 0.15) * 0.075 * lightWeight;
			  magnitude *= 1.0f - grassWeight;
			  magnitude *= lightWeight;
		float d0 = sin(tick * pi / (122.0 * speed)) * 3.0 - 1.5;
		float d1 = sin(tick * pi / (142.0 * speed)) * 3.0 - 1.5;
		float d2 = sin(tick * pi / (162.0 * speed)) * 3.0 - 1.5;
		float d3 = sin(tick * pi / (112.0 * speed)) * 3.0 - 1.5;
		position.x += sin((tick * pi / (13.0 * speed)) + (position.x + d0)*0.9 + (position.z + d1)*0.9) * magnitude;
		position.z += sin((tick * pi / (16.0 * speed)) + (position.z + d2)*0.9 + (position.x + d3)*0.9) * magnitude;
		position.y += sin((tick * pi / (15.0 * speed)) + (position.z + d2) + (position.x + d3)) * (magnitude/1.0);
	}

#endif	

	vec4 locposition = gl_ModelViewMatrix * gl_Vertex;
	
	distance = sqrt(locposition.x * locposition.x + locposition.y * locposition.y + locposition.z * locposition.z);


	gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * position);
	



	color = gl_Color;

	float colorDiff = abs(color.r - color.g);
		  colorDiff += abs(color.r - color.b);
		  colorDiff += abs(color.g - color.b);

	if (colorDiff < 0.001f && mc_Entity.x != -1.0f) {

		float lum = color.r + color.g + color.b;
			  lum /= 3.0f;

		if (lum < 0.92f) {
			color.rgb = vec3(1.0f);
		}

	}	
	
	gl_FogFragCoord = gl_Position.z;
	
	
	normal = normalize(gl_NormalMatrix * gl_Normal);
	
	globalNormal = normalize(gl_Normal);

	//if(distance < 80.0f){	
		if (gl_Normal.x > 0.5) {
			//  1.0,  0.0,  0.0
			tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0, -1.0));
			binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
		} else if (gl_Normal.x < -0.5) {
			// -1.0,  0.0,  0.0
			tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
			binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
		} else if (gl_Normal.y > 0.5) {
			//  0.0,  1.0,  0.0
			tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
			binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
		} else if (gl_Normal.y < -0.5) {
			//  0.0, -1.0,  0.0
			tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
			binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
		} else if (gl_Normal.z > 0.5) {
			//  0.0,  0.0,  1.0
			tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
			binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
		} else if (gl_Normal.z < -0.5) {
			//  0.0,  0.0, -1.0
			tangent  = normalize(gl_NormalMatrix * vec3(-1.0,  0.0,  0.0));
			binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
		}
	//}

	
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
                          tangent.y, binormal.y, normal.y,
                          tangent.z, binormal.z, normal.z);
	
	viewVector = (gl_ModelViewMatrix * gl_Vertex).xyz;
	viewVector = normalize(tbnMatrix * viewVector);

	
}