#version 120

varying vec4 color;
varying vec4 texcoord;

varying vec3 normal;

void main() {
	gl_Position = ftransform();
	//gl_Position.z -= 0.15f;	//Make clouds render farther
	
	color = gl_Color;
	
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	
	normal = normalize(gl_NormalMatrix * gl_Normal);

	gl_FogFragCoord = gl_Position.z;
}