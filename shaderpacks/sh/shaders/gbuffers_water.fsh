#version 120

/* GNORMALFORMAT:RGBA32F */

uniform sampler2D texture;
uniform sampler2D lightmap;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float frameTimeCounter;

uniform float rainStrength;

varying vec3 normal;
varying vec3 globalNormal;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 viewVector;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec4 position;

varying float iswater;
varying float isice;

float rainx = clamp(rainStrength, 0.0f, 1.0f)/1.0f;

float GetWaves(vec4 position, in float scale) {
	//Animate waves
	float wsize = 0.1f*1.5 * 1.1f * scale;
	float wspeed = 8.3f;

	position.x *= 4.0f;

	float rs0 = (sin((frameTimeCounter*wspeed/5.0) + (position.s*wsize) * 20.0 + (position.z*4.0))+0.2);
	float rs1 = (sin((frameTimeCounter*wspeed/7.0) + (position.z*wsize) * 27.0- (position.z*6.0)) + 0.5);
	float rs2 = (sin((frameTimeCounter*wspeed/2.0) + (position.z*wsize) * 60.0 - sin(position.s*wsize) * 13.0)+0.4);
	float rs3 = (sin((frameTimeCounter*wspeed/1.0) - (position.s*wsize) * 20.0 + cos(position.z*wsize) * 83.0)+0.1);

	float wsize2 = 0.05f*0.75 * 0.5f * scale;
	float wspeed2 = wspeed;

	float rs0a = (sin((frameTimeCounter*wspeed2/4.0) + (position.s*wsize2) * 24.0 - (position.z*6.0)) + 0.5);
	float rs1a = (sin((frameTimeCounter*wspeed2/11.0) + (position.z*wsize2) * 77.0  - (position.z*6.0)) + 0.5);
	float rs2a = (sin((frameTimeCounter*wspeed2/6.0) + (position.s*wsize2) * 50.0 - (position.z*wsize2) * 23.0) + 0.5);
	float rs3a = (sin((frameTimeCounter*wspeed2/14.0) - (position.z*wsize2) * 4.0 + (position.s*wsize2) * 98.0) + 0.5);

	float wsize3 = 0.01f*0.125 * 0.2f * scale;
	float wspeed3 = wspeed;

	float rs0b = (sin((frameTimeCounter*wspeed3/4.0) + (position.s*wsize3) * 14.0) + 0.5);
	float rs1b = (sin((frameTimeCounter*wspeed3/11.0) + (position.z*wsize3) * 37.0 + (position.z*1.0)) + 0.5);
	float rs2b = (sin((frameTimeCounter*wspeed3/6.0) + (position.z*wsize3) * 47.0 - cos(position.s*wsize3) * 33.0 + rs0a + rs0b) + 0.5);
	float rs3b = (sin((frameTimeCounter*wspeed3/14.0) - (position.s*wsize3) * 13.0 + sin(position.z*wsize3) * 98.0 + rs0 + rs1) + 0.5);

	float waves = (rs1 * rs0 + rs2 * rs3)/2.0f;
	float waves2 = (rs0a * rs1a + rs2a * rs3a)/2.0f;
	float waves3 = (rs0b + rs1b + rs2b + rs3b)*0.25;

	float allwaves = (waves + waves2 + waves3)/3.0f;
		  allwaves *= 1.0;	

	return allwaves;
}

vec3 GetWavesNormal(vec4 position, in float scale) {
	float wavesCenter = GetWaves(position, scale);
	float wavesLeft = GetWaves(position + vec4(0.1f, 0.0f, 0.0f, 0.0f), scale);
	float wavesUp   = GetWaves(position + vec4(0.0f, 0.0f, 0.1f, 0.0f), scale);

	vec3 wavesNormal;
		 wavesNormal.r = wavesCenter - wavesUp;
		 wavesNormal.g = wavesCenter - wavesLeft;

		 wavesNormal.r *= 0.10f;
		 wavesNormal.g *= 0.10f;

		 wavesNormal.b = sqrt(1.0f - wavesNormal.r * wavesNormal.r - wavesNormal.g * wavesNormal.g);
		 //wavesNormal.b = 1.0f;



	return wavesNormal.rgb;
}

void main() {

	vec4 tex = texture2D(texture, texcoord.st);
		 tex.a = 0.95f;
	
	float zero = 1.0f;
	float transx = 0.0f;
	float transy = 0.0f;
	//float iswater = 0.0f;
	
	float texblock = 0.0625f;

	bool backfacing = false;

	if (viewVector.z > 0.0f) {
		backfacing = true;
	} else {
		backfacing = false;
	}

	
	if (iswater > 0.5f && !backfacing) {
		vec4 albedo = texture2D(texture, texcoord.st).rgba;
		float lum = albedo.r + albedo.g + albedo.b;
			  lum /= 3.0f;

			  lum = pow(lum, 2.0f) * 1.0f;
			  lum += 0.0f;

		tex = vec4(0.6f, 0.7f, 0.15f, 220.0f/255.0f);
		tex.rgb *= 0.8f * color.rgb;
		tex.rgb *= vec3(lum);

		// tex = vec4(color.r, color.g, color.b, 0.4f);
		// tex.rgb *= vec3(0.9f, 1.0f, 0.1f) * 0.8f;

	} else if (iswater > 0.5f && backfacing) {
		tex = vec4(0.0, 0.0, 0.0f, 30.0f / 255.0f);
	}
	
	//store lightmap in auxilliary texture. r = torch light. g = lightning. b = sky light.
		
	vec3 lightmaptorch = texture2D(lightmap, vec2(lmcoord.s, 0.00f)).rgb;
	vec3 lightmapsky   = texture2D(lightmap, vec2(0.0f, lmcoord.t)).rgb;
	
	//store lightmap in auxilliary texture. r = torch light. g = lightning. b = sky light.
	vec4 lightmap = vec4(0.0f, 0.0f, 0.0f, 1.0f);
	
	//Separate lightmap types
	lightmap.r = clamp((lmcoord.s * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);
	lightmap.b = clamp((lmcoord.t * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);

	
	



	float matID = 4.0f;

	for (int i = 0; i < 16; i++) {
		if (iswater > 0.5f && lightmap.b >= i / 16.0f && lightmap.b < (i + 1) / 16.0f)
			matID = 35.0f + i;
	}

	lightmap.b = pow(lightmap.b, 5.7f);
	lightmap.r = pow(lightmap.r, 3.0f);

	matID += 0.1f;

	gl_FragData[0] = tex * color;
	gl_FragData[1] = vec4(matID / 255.0f, lightmap.r, lightmap.b, 1.0);


	vec3 wavesNormal = GetWavesNormal(position, 1.0f);
		 wavesNormal += GetWavesNormal(position, 0.5f);
		 wavesNormal += GetWavesNormal(position, 0.25f);
		 wavesNormal += GetWavesNormal(position, 0.125f);

		 wavesNormal /= 4.0f;

		

		 mat3 tbnMatrix = mat3 (tangent.x, binormal.x, normal.x,
								tangent.y, binormal.y, normal.y,
						     	tangent.z, binormal.z, normal.z);



	vec3 waterNormal = wavesNormal * tbnMatrix;


	gl_FragData[2] = vec4(waterNormal.rgb * 0.5 + 0.5, 1.0f);
	gl_FragData[3] = vec4(lightmap.b, 0.0f, 0.0f, 1.0);

	
	//gl_FragData[5] = vec4(lightmap.rgb, 0.0f);	
	//gl_FragData[6] = vec4(0.0f, lightmap.b, iswater, 1.0f);
	
	
	//gl_FragData[7] = vec4(globalNormal * 0.5f + 0.5f, 1.0);
}