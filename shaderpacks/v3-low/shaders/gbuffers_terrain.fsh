#version 120


/* DRAWBUFFERS:0NNN4 */

////////////////////////////////////////////////////ADJUSTABLE VARIABLES/////////////////////////////////////////////////////////

#define POM 								//Comment to disable parallax occlusion mapping.
#define NORMAL_MAP_MAX_ANGLE 0.88f   		//The higher the value, the more extreme per-pixel normal mapping (bump mapping) will be.






   
//the resolution is the normalmap resolution that you can see when opening terrain_nh,not the texturepack resolution
//most often it's 1024 or 2048
#define NORMALMAP_RES 1024.0

//the lower it is the bigger bump there will be
#define POM_AMOUNT 0.22			//when you divide normalres by 2 use the squared root of this number and when you multiply by 2 use the square of this number


const int MAX_OCCLUSION_POINTS = 14;
const float bump_distance = 70.0;
const float pom_distance = 30.0;


const vec3 intervalMult = vec3(1.0/NORMALMAP_RES, 1.0/NORMALMAP_RES, POM_AMOUNT);

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform float wetness;
uniform int worldTime;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;

varying vec3 viewVector;

varying vec3 tangent;
varying vec3 normal;
varying vec3 binormal;

varying float translucent;
varying float distance;
varying float test;


const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

uniform int fogMode;

float wetx = clamp(wetness, 0.0f, 1.0)/1.0;


const float fademult = 0.1;





void main() {	

	
	vec2 adjustedTexCoord = texcoord.st;
	float texinterval = 0.0625;
	float pomsample = 0.0;

	vec3 lightVector;
	if (worldTime < 12700 || worldTime > 23250) {
		lightVector = normalize(sunPosition);
	} else {
		lightVector = normalize(moonPosition);
	}
	vec3 indlmap = mix(pow(min(lmcoord.t,1.0),3.0),1.0,lmcoord.s)*texture2D(texture,adjustedTexCoord).rgb*color.rgb;
	gl_FragData[0] = vec4(indlmap,texture2D(texture,adjustedTexCoord).a*color.a);
	
	
	
	
float pomdepth = 0.0;
	float dirtest;
	if (translucent > 0.9) dirtest = 0.4;
	else {
	dirtest = 1.0-0.8*step(dot(normal,lightVector),-0.02);
	}
	gl_FragDepth = gl_FragCoord.z;
	
	//x = specularity / y = land(0.0/1.0)/shadow early exit(0.2)/water(0.05)/translucent(0.4) / z = torch lightmap
	
	gl_FragData[4] = vec4(0.0, dirtest, lmcoord.s, 0.0);
	
}