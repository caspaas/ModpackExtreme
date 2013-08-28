#version 120
/* DRAWBUFFERS:0N2N4 */

////////////////////////////////////////////////////ADJUSTABLE VARIABLES/////////////////////////////////////////////////////////

#define POM 								//Comment to disable parallax occlusion mapping.
#define NORMAL_MAP_MAX_ANGLE 0.88f   		//The higher the value, the more extreme per-pixel normal mapping (bump mapping) will be.





/* Here, intervalMult might need to be tweaked per texture pack.  
   The first two numbers determine how many samples are taken per fragment.  They should always be the equal to eachother.
   The third number divided by one of the first two numbers is inversely proportional to the range of the height-map. */


uniform sampler2D texture;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;

varying vec3 viewVector;
varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;

varying float translucent;
varying float distance;

const float MAX_OCCLUSION_DISTANCE = 100.0;

const int MAX_OCCLUSION_POINTS = 20;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;


const float bump_distance = 80.0f;
const float fademult = 0.1f;





void main() {	

	
	vec2 adjustedTexCoord = texcoord.st;
	float texinterval = 0.0625f;


				  


	vec3 indlmap = mix(pow(min(lmcoord.t+0.1,1.0),2.0),1.0,lmcoord.s)*texture2D(texture,adjustedTexCoord).rgb*color.rgb;
	gl_FragData[0] = vec4(indlmap,texture2D(texture,adjustedTexCoord).a*color.a);
	float pomdepth = -3.0;			//make the block closer as it is for self-shadowing fix
	float pomdepthbias = (pomdepth) * (1.0 - gl_FragCoord.z) * (1.0 - gl_FragCoord.z);
	gl_FragDepth = gl_FragCoord.z+pomdepthbias;
	
	
	vec4 frag2;
	
			frag2 = vec4((normal) * 0.5f + 0.5f, 1.0f);		
			

	
	gl_FragData[2] = frag2;	
	//x = specularity / y = land(0.0/1.0)/shadow early exit(0.2)/water(0.05) / z = torch lightmap
	gl_FragData[4] = vec4(0.0, 1.0f, lmcoord.s, 0.0f);
	

}