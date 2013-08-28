#version 120

//clouds

uniform sampler2D texture;

varying vec4 color;
varying vec4 texcoord;

varying vec3 normal;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

uniform int fogMode;

void main() {

	float fullalpha = (texture2D(texture, texcoord.st).a * color.a);

	gl_FragData[0] = vec4(texture2D(texture, texcoord.st).rgb * color.rgb, fullalpha*2.0f);
	gl_FragData[1] = vec4((29.0f + 0.1f) / 255.0f, 0.0f, 1.0f, 1.0f);
	

	
	float colormask = 0.0;
	float coloraverage = (color.r + color.g + color.b)/3.0;
	
	if (coloraverage == 1.0 && gl_FragCoord.z < 0.999) {
		colormask = 1.0;
	} else {
		colormask = 0.0;
	}
	
	float skymask;
	
	if (gl_FragCoord.z < 0.99f) {
		skymask = 1.0f;
	} else {
		skymask = 0.0f;
	}
	
	gl_FragData[2] = vec4(normal.rgb * vec3(0.5f) + vec3(0.5f), fullalpha);
	//gl_FragData[3] = vec4(0.0f, 0.0, 0.0f, 1.0f);
}