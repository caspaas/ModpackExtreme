#version 120



/////////////////////////CONFIGURABLE VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////CONFIGURABLE VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define SATURATION_BOOST 0.2f 			//How saturated the final image should be. 0 is unchanged saturation. Higher values create more saturated image

/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////


uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gdepthtex;
uniform sampler2D gnormal;
uniform sampler2D composite;
//uniform sampler2D gaux1;

varying vec4 texcoord;
varying vec3 lightVector;

uniform int worldTime;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float aspectRatio;
uniform float centerDepthSmooth;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform int   isEyeInWater;
uniform float eyeAltitude;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;
uniform int   fogMode;

varying float timeSunrise;
varying float timeNoon;
varying float timeSunset;
varying float timeMidnight;

#define BANDING_FIX_FACTOR 1.0f




/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
vec3 	GetTexture(in sampler2D tex, in vec2 coord) {				//Perform a texture lookup with BANDING_FIX_FACTOR compensation
	return pow(texture2D(tex, coord).rgb, vec3(BANDING_FIX_FACTOR + 1.2f));
}

vec3 	GetTextureLod(in sampler2D tex, in vec2 coord, in int level) {				//Perform a texture lookup with BANDING_FIX_FACTOR compensation
	return pow(texture2DLod(tex, coord, level).rgb, vec3(BANDING_FIX_FACTOR + 1.2f));
}

vec3 	GetTexture(in sampler2D tex, in vec2 coord, in int LOD) {	//Perform a texture lookup with BANDING_FIX_FACTOR compensation and lod offset
	return pow(texture2D(tex, coord, LOD).rgb, vec3(BANDING_FIX_FACTOR));
}

float 	GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

vec3 	GetColorTexture(in vec2 coord) {
	return GetTextureLod(gnormal, coord.st, 0).rgb;
}

float 	GetMaterialIDs(in vec2 coord) {			//Function that retrieves the texture that has all material IDs stored in it
	return texture2D(gdepth, coord).r;
}

bool 	GetMaterialMask(in vec2 coord, in int ID) {
	float	  matID = floor(GetMaterialIDs(coord) * 255.0f);

	//Catch last part of sky
	if (matID > 254.0f) {
		matID = 0.0f;
	}

	if (matID == ID) {
		return true;
	} else {
		return false;
	}
}

void 	DepthOfField(inout vec3 color)
{

	float cursorDepth = centerDepthSmooth;

	bool isHand = GetMaterialMask(texcoord.st, 5);
	
	
const float blurclamp = 0.014;  // max blur amount
const float bias = 0.15;	//aperture - bigger values for shallower depth of field
	
	
	vec2 aspectcorrect = vec2(1.0, aspectRatio) * 1.5;

	float depth = texture2D(gdepthtex, texcoord.st).x;
		  depth += float(isHand) * 0.36f;

	float factor = (depth - cursorDepth);
	 
	vec2 dofblur = vec2(factor * bias)*0.6;

	
	

	vec3 col = vec3(0.0);
	col += GetColorTexture(texcoord.st);
	
	col += GetColorTexture(texcoord.st + (vec2( 0.0,0.4 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.15,0.37 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.29,0.29 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( -0.37,0.15 )*aspectcorrect) * dofblur);	
	col += GetColorTexture(texcoord.st + (vec2( 0.4,0.0 )*aspectcorrect) * dofblur);	
	col += GetColorTexture(texcoord.st + (vec2( 0.37,-0.15 )*aspectcorrect) * dofblur);	
	col += GetColorTexture(texcoord.st + (vec2( 0.29,-0.29 )*aspectcorrect) * dofblur);	
	col += GetColorTexture(texcoord.st + (vec2( -0.15,-0.37 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.0,-0.4 )*aspectcorrect) * dofblur);	
	col += GetColorTexture(texcoord.st + (vec2( -0.15,0.37 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( -0.29,0.29 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.37,0.15 )*aspectcorrect) * dofblur);	
	col += GetColorTexture(texcoord.st + (vec2( -0.4,0.0 )*aspectcorrect) * dofblur);	
	col += GetColorTexture(texcoord.st + (vec2( -0.37,-0.15 )*aspectcorrect) * dofblur);	
	col += GetColorTexture(texcoord.st + (vec2( -0.29,-0.29 )*aspectcorrect) * dofblur);	
	col += GetColorTexture(texcoord.st + (vec2( 0.15,-0.37 )*aspectcorrect) * dofblur);
	
	col += GetColorTexture(texcoord.st + (vec2( 0.15,0.37 )*aspectcorrect) * dofblur*0.9);
	col += GetColorTexture(texcoord.st + (vec2( -0.37,0.15 )*aspectcorrect) * dofblur*0.9);		
	col += GetColorTexture(texcoord.st + (vec2( 0.37,-0.15 )*aspectcorrect) * dofblur*0.9);		
	col += GetColorTexture(texcoord.st + (vec2( -0.15,-0.37 )*aspectcorrect) * dofblur*0.9);
	col += GetColorTexture(texcoord.st + (vec2( -0.15,0.37 )*aspectcorrect) * dofblur*0.9);
	col += GetColorTexture(texcoord.st + (vec2( 0.37,0.15 )*aspectcorrect) * dofblur*0.9);		
	col += GetColorTexture(texcoord.st + (vec2( -0.37,-0.15 )*aspectcorrect) * dofblur*0.9);	
	col += GetColorTexture(texcoord.st + (vec2( 0.15,-0.37 )*aspectcorrect) * dofblur*0.9);	
	
	col += GetColorTexture(texcoord.st + (vec2( 0.29,0.29 )*aspectcorrect) * dofblur*0.7);
	col += GetColorTexture(texcoord.st + (vec2( 0.4,0.0 )*aspectcorrect) * dofblur*0.7);	
	col += GetColorTexture(texcoord.st + (vec2( 0.29,-0.29 )*aspectcorrect) * dofblur*0.7);	
	col += GetColorTexture(texcoord.st + (vec2( 0.0,-0.4 )*aspectcorrect) * dofblur*0.7);	
	col += GetColorTexture(texcoord.st + (vec2( -0.29,0.29 )*aspectcorrect) * dofblur*0.7);
	col += GetColorTexture(texcoord.st + (vec2( -0.4,0.0 )*aspectcorrect) * dofblur*0.7);	
	col += GetColorTexture(texcoord.st + (vec2( -0.29,-0.29 )*aspectcorrect) * dofblur*0.7);	
	col += GetColorTexture(texcoord.st + (vec2( 0.0,0.4 )*aspectcorrect) * dofblur*0.7);
			
	col += GetColorTexture(texcoord.st + (vec2( 0.29,0.29 )*aspectcorrect) * dofblur*0.4);
	col += GetColorTexture(texcoord.st + (vec2( 0.4,0.0 )*aspectcorrect) * dofblur*0.4);	
	col += GetColorTexture(texcoord.st + (vec2( 0.29,-0.29 )*aspectcorrect) * dofblur*0.4);	
	col += GetColorTexture(texcoord.st + (vec2( 0.0,-0.4 )*aspectcorrect) * dofblur*0.4);	
	col += GetColorTexture(texcoord.st + (vec2( -0.29,0.29 )*aspectcorrect) * dofblur*0.4);
	col += GetColorTexture(texcoord.st + (vec2( -0.4,0.0 )*aspectcorrect) * dofblur*0.4);	
	col += GetColorTexture(texcoord.st + (vec2( -0.29,-0.29 )*aspectcorrect) * dofblur*0.4);	
	col += GetColorTexture(texcoord.st + (vec2( 0.0,0.4 )*aspectcorrect) * dofblur*0.4);	

	color = col/41;
	
}

vec3 	GetBloomTex() {		//Retrieve previously calculated bloom textures

	//constants for bloom bloomSlant
	const float    bloomSlant = 0.0f;
	const float[7] bloomWeight = float[7] (pow(7.0f, bloomSlant),
										   pow(6.0f, bloomSlant),
										   pow(5.0f, bloomSlant),
										   pow(4.0f, bloomSlant),
										   pow(3.0f, bloomSlant),
										   pow(2.0f, bloomSlant),
										   1.0f
										   );

	vec3 bloom  =  pow(texture2D(gcolor, (texcoord.st) * (1.0f / pow(2.0f, 	2.0f 	)) + 	vec2(0.0f, 0.0f)		+ vec2(0.000f, 0.000f)	).rgb * bloomWeight[0], vec3(3.0f + 1.2f));
		 bloom +=  pow(texture2D(gcolor, (texcoord.st) * (1.0f / pow(2.0f, 	3.0f 	)) + 	vec2(0.0f, 0.25f)		+ vec2(0.000f, 0.025f)	).rgb * bloomWeight[1], vec3(3.0f + 1.2f));
		 bloom +=  pow(texture2D(gcolor, (texcoord.st) * (1.0f / pow(2.0f, 	4.0f 	)) + 	vec2(0.125f, 0.25f)		+ vec2(0.025f, 0.025f)	).rgb * bloomWeight[2], vec3(3.0f + 1.2f));
		 bloom +=  pow(texture2D(gcolor, (texcoord.st) * (1.0f / pow(2.0f, 	5.0f 	)) + 	vec2(0.1875f, 0.25f)	+ vec2(0.050f, 0.025f)	).rgb * bloomWeight[3], vec3(3.0f + 1.2f));
		 bloom +=  pow(texture2D(gcolor, (texcoord.st) * (1.0f / pow(2.0f, 	6.0f 	)) + 	vec2(0.21875f, 0.25f)	+ vec2(0.075f, 0.025f)	).rgb * bloomWeight[4], vec3(3.0f + 1.2f));
		 bloom +=  pow(texture2D(gcolor, (texcoord.st) * (1.0f / pow(2.0f, 	7.0f 	)) + 	vec2(0.25f, 0.25f)		+ vec2(0.100f, 0.025f)	).rgb * bloomWeight[5], vec3(3.0f + 1.2f));
		 //bloom +=  pow(texture2D(gcolor, (texcoord.st) * (1.0f / pow(2.0f, 	8.0f 	)) + 	vec2(0.28f, 0.25f)		+ vec2(0.125f, 0.025f)	).rgb * bloomWeight[6], vec3(3.0f + 1.2f));
		 //bloom +=  pow(texture2D(gnormal, texcoord.st, 3).rgb * 1.0f, vec3(3.0f + 1.2f));

		 //bloom = pow(bloom, vec3(3.0f));

		 bloom *= 0.008f;

	return bloom;
}

void Vignette(inout vec3 color) {
	float dist = distance(texcoord.st, vec2(0.5f)) * 2.0f;
		  dist /= 1.5142f;

		  dist = pow(dist, 1.1f);

	color.rgb *= 1.0f - dist;

}

float  	CalculateDitherPattern1() {
	int[16] ditherPattern = int[16] (0 , 9 , 3 , 11,
								 	 13, 5 , 15, 7 ,
								 	 4 , 12, 2,  10,
								 	 16, 8 , 14, 6 );

	vec2 count = vec2(0.0f);
	     count.x = floor(mod(texcoord.s * viewWidth, 4.0f));
		 count.y = floor(mod(texcoord.t * viewHeight, 4.0f));

	int dither = ditherPattern[int(count.x) + int(count.y) * 4];

	return float(dither) / 17.0f;
}

void 	MotionBlur(inout vec3 color) {
	float depth = GetDepth(texcoord.st);
	vec4 currentPosition = vec4(texcoord.x * 2.0f - 1.0f, texcoord.y * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);

	vec4 fragposition = gbufferProjectionInverse * currentPosition;
	fragposition = gbufferModelViewInverse * fragposition;
	fragposition /= fragposition.w;
	fragposition.xyz += cameraPosition;

	vec4 previousPosition = fragposition;
	previousPosition.xyz -= previousCameraPosition;
	previousPosition = gbufferPreviousModelView * previousPosition;
	previousPosition = gbufferPreviousProjection * previousPosition;
	previousPosition /= previousPosition.w;

	vec2 velocity = (currentPosition - previousPosition).st * 0.08f;
	float maxVelocity = 0.05f;
		 velocity = clamp(velocity, vec2(-maxVelocity), vec2(maxVelocity));


	bool isHand = GetMaterialMask(texcoord.st, 5);
	velocity *= 1.0f - float(isHand);

	int samples = 0;

	float dither = CalculateDitherPattern1();

	color.rgb = vec3(0.0f);

	for (int i = 0; i < 2; ++i) {
		vec2 coord = texcoord.st + velocity * (i - 0.5);
			 coord += vec2(dither) * 1.2f * velocity;

		if (coord.x > 0.0f && coord.x < 1.0f && coord.y > 0.0f && coord.y < 1.0f) {

			color += GetColorTexture(coord).rgb;
			samples += 1;

		}
	}

	color.rgb /= samples;


}

void CalculateExposure(inout vec3 color) {
	float exposureMax = 1.55f;
		  exposureMax *= mix(1.0f, 0.0f, timeMidnight);
	float exposureMin = 0.15f;
	float exposure = pow(eyeBrightnessSmooth.y / 240.0f, 6.0f) * exposureMax + exposureMin;

	color.rgb /= vec3(exposure);
}

void TonemapVorontsov(inout vec3 color) {
	//color = pow(color, vec3(2.2f)); 			//Put gcolor back into linear space
	color.rgb *= 50000.0f;
	
	//Natural
	//Properties
		// float tonemapContrast 		= 0.95f;
		// float tonemapSaturation 	= 1.2f + SATURATION_BOOST; 
		// float tonemapDecay			= 210.0f;
		// float tonemapCurve			= 100.0f;

	//Filmic
		float tonemapContrast 		= 1.0f;
		float tonemapSaturation 	= 1.0f + SATURATION_BOOST; 
		float tonemapDecay			= 121000.0f;
		float tonemapCurve			= 7.0f;
		
	color.rgb += 0.001f;
	
	vec3 colorN = normalize(color.rgb);
	
	vec3 clrfr = color.rgb/colorN.rgb;
	     clrfr = pow(clrfr.rgb, vec3(tonemapContrast));
		 
	colorN.rgb = pow(colorN.rgb, vec3(tonemapSaturation));
	
	color.rgb = clrfr.rgb * colorN.rgb;

	color.rgb = (color.rgb * (1.0 + color.rgb/tonemapDecay))/(color.rgb + tonemapCurve);

	color.rgb = pow(color.rgb, vec3(1.0f / 2.2f));

	color.rgb *= 1.1f;
}

void TonemapReinhard(inout vec3 color) {
	//color.rgb = pow(color.rgb, vec3(2.2f));			//Put color into linear space

	color.rgb *= 5200.0f;
	color.rgb = color.rgb / (1.0f + color.rgb);

	color.rgb = pow(color.rgb, vec3(1.0f / 2.2f)); //Put color into gamma space for correct display
	color.rgb *= 1.02f;
}

void SaturationBoost(inout vec3 color) {
	float satBoost = 0.04f;

	color.r = color.r * (1.0f + satBoost * 2.0f) - (color.g * satBoost) - (color.b * satBoost);
	color.g = color.g * (1.0f + satBoost * 2.0f) - (color.r * satBoost) - (color.b * satBoost);
	color.b = color.b * (1.0f + satBoost * 2.0f) - (color.r * satBoost) - (color.g * satBoost);
}

void TonemapReinhardLinearHybrid(inout vec3 color) {

	color.rgb *= 31000.0f;
	color.rgb = color.rgb / (1.0f + color.rgb);

	color.rgb = pow(color.rgb, vec3(1.0f / 2.2f)); //Put color into gamma space for correct display
	color.rgb *= 1.10f;
}

/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main() {

	vec3 color = GetColorTexture(texcoord.st);	//Sample gcolor texture

	//MotionBlur(color);

	//DepthOfField(color);

	color += GetBloomTex();			//Add previously calculated bloom

	

	Vignette(color);

	CalculateExposure(color);

	//TonemapVorontsov(color);
	//TonemapReinhard(color);
	//SaturationBoost(color);

	TonemapReinhardLinearHybrid(color);

	gl_FragColor = vec4(color.rgb, 1.0f);

}