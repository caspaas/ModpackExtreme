#version 120

#define SHADOW_MAP_BIAS 0.80		

varying vec4 texcoord;
varying vec4 vPosition;


void main() {
	gl_Position = ftransform();

	float dist = sqrt(gl_Position.x * gl_Position.x + gl_Position.y * gl_Position.y);
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
	gl_Position.xy *= 1.0f / distortFactor;


	vPosition = gl_Position;
	
	texcoord = gl_MultiTexCoord0;


	// texcoord = texcoord * 2.0f - 1.0f;
	// dist = sqrt(texcoord.x * texcoord.x + texcoord.y * texcoord.y);
	// distortFactor = 0.15f + dist * 0.85f;
	// texcoord *= 1.0f / distortFactor;
	// texcoord = texcoord * 0.5f + 0.5f;

	gl_FrontColor = gl_Color;
	
}
