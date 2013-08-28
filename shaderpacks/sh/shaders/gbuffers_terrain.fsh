#version 120





////////////////////////////////////////////////////ADJUSTABLE VARIABLES/////////////////////////////////////////////////////////

#define NORMAL_MAP_MAX_ANGLE 0.95f   		//The higher the value, the more extreme per-pixel normal mapping (bump mapping) will be.

///////////////////////////////////////////////////END OF ADJUSTABLE VARIABLES///////////////////////////////////////////////////



uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D specular;
//uniform float rainStrength;
uniform float wetness;


varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;

varying vec3 viewVector;
varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 globalNormal;

varying float materialIDs;

varying float distance;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

const float bump_distance = 78.0f;
const float fademult = 0.1f;






void main() {	

if (texture2D(texture, texcoord.st).a == 0.0f){
	//discard;
}

		
	vec4 spec = texture2D(specular, texcoord.st);

	//store lightmap in auxilliary texture. r = torch light. g = lightning. b = sky light.
	vec4 lightmap = vec4(0.0f, 0.0f, 0.0f, 1.0f);
	
	//Separate lightmap types
	lightmap.r = clamp((lmcoord.s * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);
	lightmap.b = clamp((lmcoord.t * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);

	
	vec4 clr = color;
		 clr.rgb = clr.rgb / normalize(clr.rbg);
		 clr.rgb *= 0.5f;
		 clr.rgb = vec3(max(color.r, max(color.g, color.b)));

	float ao = (color.r + color.g + color.b) / 3.0f;

	float colorDiff = abs(color.r - color.g);
		  colorDiff += abs(color.r - color.b);
		  colorDiff += abs(color.g - color.b);

	if (colorDiff > 0.001f) {
		ao = 1.0f;
	}

	ao = pow(ao, 13.0f);

	 lightmap.b *= ao;

	 lightmap.r *= ao * 0.5f + 0.5f;

	lightmap.b = pow(lightmap.b, 5.7f);
	lightmap.r = pow(lightmap.r, 3.0f);

	float wetfactor = clamp(lightmap.b - 0.9f, 0.0f, 0.1f) / 0.1f;
	
	
	vec4 frag2;
	vec4 frag3;
	
	if (distance < bump_distance) {
	
			vec3 bump = texture2D(normals, texcoord.st).rgb * 2.0f - 1.0f;
			vec3 bump2 = texture2D(normals, texcoord.st).rgb * 2.0f - 1.0f;
				 bump2.g = 1.0f - bump2.g;
			
			float bumpmult = clamp(bump_distance * fademult - distance * fademult, 0.0f, 1.0f) * NORMAL_MAP_MAX_ANGLE;
	              bumpmult *= 1.0f - (spec.g * 0.9f * wetness * wetfactor);
				  
			bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
			
			
			bump2 = bump2 * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
		
			mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
								  tangent.y, binormal.y, normal.y,
						     	  tangent.z, binormal.z, normal.z);
			
			frag2 = vec4(bump * tbnMatrix * 0.5 + 0.5, 1.0);
			
			frag3 = vec4((globalNormal + (bump2 * NORMAL_MAP_MAX_ANGLE)) * 0.5f + 0.5f, 1.0f);
			
	} else {
	
			frag2 = vec4((normal) * 0.5f + 0.5f, 1.0f);		
			frag3 = vec4(globalNormal * 0.5f + 0.5f, 1.0f);
			
	}

	//Diffuse
		vec4 albedo = texture2D(texture, texcoord.st) * color;
		//Wet diffuse
		const float wetPow = 1.75f;
		
		float metallicMask = 0.0f;
		
		if (   abs(materialIDs - 20.0f) < 0.1f
			|| abs(materialIDs - 21.0f) < 0.1f
			|| abs(materialIDs - 22.0f) < 0.1f
			|| abs(materialIDs - 23.0f) < 0.1f) {
			metallicMask = 1.0f;
		}
		
		gl_FragData[0] = albedo;
		

	float mats_1 = materialIDs;
		  mats_1 += 0.1f;
	//Depth  
	gl_FragData[1] = vec4(mats_1/255.0f, lightmap.r, lightmap.b, 1.0f);

	//normal
	gl_FragData[2] = frag2;
		
	//specularity
	gl_FragData[3] = vec4(spec.r + spec.b + spec.g * wetness * wetfactor, 0.0f, 0.0f, 1.0f);	

}