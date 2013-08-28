#version 120




/////////ADJUSTABLE VARIABLES//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////ADJUSTABLE VARIABLES//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define SHADOW_MAP_BIAS 0.80

#define ENABLE_SOFT_SHADOWS
//#define ENABLE_FAST_SOFT_SHADOWS
//#define VARIABLE_PENUMBRA_SHADOWS
	//#define VPS_HIGH_QUALITY






/////////INTERNAL VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////INTERNAL VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Do not change the name of these variables or their type. The Shaders Mod reads these lines and determines values to send to the inner-workings
//of the shaders mod. The shaders mod only reads these lines and doesn't actually know the real value assigned to these variables in GLSL.
//Some of these variables are critical for proper operation. Change at your own risk.

const int 		shadowMapResolution 	= 1024;
const float 	shadowDistance 			= 80.0f;
const bool 		generateShadowMipmap 	= true;
const float 	shadowIntervalSize 		= 4.0f;

const int 		R8 						= 0;
const int 		RGB8 					= 1;
const int 		RGB16 					= 2;
const int 		gcolorFormat 			= RGB16;
const int 		gdepthFormat 			= RGB8;
const int 		gnormalFormat 			= RGB16;
const int 		compositeFormat 		= R8;

const float 	eyeBrightnessHalflife 	= 10.0f;
const float 	centerDepthHalflife 	= 2.0f;
const float 	wetnessHalflife 		= 200.0f;
const float 	drynessHalflife 		= 500.0f;

const int 		superSamplingLevel 		= 0;

const float		sunPathRotation 		= -30.0f;
const float 	ambientOcclusionLevel 	= 0.014f;


//END OF INTERNAL VARIABLES//



#define BANDING_FIX_FACTOR 1.0f

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gdepthtex;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D shadow;
uniform sampler2D watershadow;
//uniform sampler2D gaux1;
//uniform sampler2D gaux2;
//uniform sampler2D gaux3;
//uniform sampler2D gaux4;

varying vec4 texcoord;
varying vec3 lightVector;
varying vec3 upVector;

uniform int worldTime;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 cameraPosition;
uniform vec3 upPosition;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float aspectRatio;

uniform int   isEyeInWater;
uniform float eyeAltitude;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;
uniform int   fogMode;


varying float timeSunrise;
varying float timeNoon;
varying float timeSunset;
varying float timeMidnight;
varying float timeSkyDark;

varying vec3 colorSunlight;
varying vec3 colorSkylight;
varying vec3 colorSunglow;
varying vec3 colorBouncedSunlight;
varying vec3 colorScatteredSunlight;
varying vec3 colorTorchlight;
varying vec3 colorWaterMurk;
varying vec3 colorWaterBlue;





/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//Get gbuffer textures
vec3  	GetAlbedoLinear(in vec2 coord) {			//Function that retrieves the diffuse texture and convert it into linear space.
	return pow(texture2D(gcolor, coord).rgb, vec3(2.2f));	
}

vec3  	GetAlbedoGamma(in vec2 coord) {			//Function that retrieves the diffuse texture and leaves it in gamma space.
	return texture2D(gcolor, coord).rgb;	
}

vec3  	GetNormals(in vec2 coord) {				//Function that retrieves the screen space surface normals. Used for lighting calculations
	return texture2D(gnormal, texcoord.st).rgb * 2.0f - 1.0f;
}

float 	GetDepth(in vec2 coord) {					//Function that retrieves the scene depth. 0 - 1, higher values meaning farther away
	return texture2D(gdepthtex, coord).r;
}

float 	GetDepthLinear(in vec2 coord) {					//Function that retrieves the scene depth. 0 - 1, higher values meaning farther away
	return 2.0f * near * far / (far + near - (2.0f * texture2D(gdepthtex, coord).x - 1.0f) * (far - near));
}


//Lightmaps
float 	GetLightmapTorch(in vec2 coord) {			//Function that retrieves the lightmap of light emitted by emissive blocks like torches and lava
	float lightmap = texture2D(gdepth, coord).g;

	//Apply inverse square law and normalize for natural light falloff
	lightmap 		= clamp(lightmap * 1.05f, 0.0f, 1.0f);
	lightmap 		= 1.0f - lightmap;
	lightmap 		*= 5.6f;
	lightmap 		= 1.0f / pow((lightmap + 0.00001f), 2.0f);
	lightmap 		-= 0.03195f;

	// if (lightmap <= 0.0f)
	// 	lightmap = 100.0f;

	lightmap 		= max(0.0f, lightmap);
	lightmap 		*= 0.008f;
	lightmap 		= clamp(lightmap, 0.0f, 1.0f);
	return lightmap;


}

float 	GetLightmapSky(in vec2 coord) {			//Function that retrieves the lightmap of light emitted by the sky. This is a raw value from 0 (fully dark) to 1 (fully lit) regardless of time of day
	return texture2D(gdepth, coord).b;
}

float 	GetUnderwaterLightmapSky(in vec2 coord) {
	return texture2D(composite, coord).r;
}


//Specularity
float 	GetSpecularity(in vec2 coord) {			//Function that retrieves how reflective any surface/pixel is in the scene. Used for reflections and specularity
	return texture2D(composite, texcoord.st).r;
}


//Material IDs
float 	GetMaterialIDs(in vec2 coord) {			//Function that retrieves the texture that has all material IDs stored in it
	return texture2D(gdepth, coord).r;
}

bool  	GetSky(in vec2 coord) {					//Function that returns true for any pixel that is part of the sky, and false for any pixel that isn't part of the sky
	float matID = GetMaterialIDs(coord);		//Gets texture that has all material IDs stored in it
		  matID = floor(matID * 255.0f);		//Scale texture from 0-1 float to 0-255 integer format
	
	if (matID == 0.0f) {						//Checks to see if the current pixel's material ID is 0 = the sky
		return true;							//If the current pixel has the material ID of 0 (sky material ID), Return "this pixel is part of the sky"
	} else {
		return false;							//Return "this pixel is not part of the sky"
	}
}

bool 	GetMaterialMask(in vec2 coord, in int ID, in float matID) {
		  matID = floor(matID * 255.0f);

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




//Water
float 	GetWaterTex(in vec2 coord) {				//Function that returns the texture used for water. 0 means "this pixel is not water". 0.5 and greater means "this pixel is water".
	return texture2D(composite, coord).b;		//values from 0.5 to 1.0 represent the amount of sky light hitting the surface of the water. It is used to simulate fake sky reflections in composite1.fsh
}

bool  	GetWaterMask(in vec2 coord, in float matID) {					//Function that returns "true" if a pixel is water, and "false" if a pixel is not water.
	matID = floor(matID * 255.0f);

	if (matID >= 35.0f && matID <= 51) {
		return true;
	} else {
		return false;
	}
}




//Surface calculations
vec4  	GetWorldSpacePosition(in vec2 coord) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
	float depth = GetDepth(coord);
		  //depth += float(GetMaterialMask(coord, 5)) * 0.38f;
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;
	
	return fragposition;
}

vec4  	GetWorldSpacePosition(in vec2 coord, in float depth) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
		  //depth += float(GetMaterialMask(coord, 5)) * 0.38f;
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;
	
	return fragposition;
}

void 	DoNightEye(inout vec3 color) {			//Desaturates any color input at night, simulating the rods in the human eye
	
	float amount = 0.8f; 						//How much will the new desaturated and tinted image be mixed with the original image
	vec3 rodColor = vec3(0.2f, 0.5f, 1.0f); 	//Cyan color that humans percieve when viewing extremely low light levels via rod cells in the eye
	float colorDesat = dot(color, vec3(1.0f)); 	//Desaturated color
	
	color = mix(color, vec3(colorDesat) * rodColor, timeSkyDark * amount);
	
}


float 	ExponentialToLinearDepth(in float depth)
{
	vec4 worldposition = vec4(depth);
	worldposition = gbufferProjection * worldposition;
	return worldposition.z;
}

void 	DoLowlightEye(inout vec3 color) {			//Desaturates any color input at night, simulating the rods in the human eye
	
	float amount = 0.8f; 						//How much will the new desaturated and tinted image be mixed with the original image
	vec3 rodColor = vec3(0.2f, 0.5f, 1.0f); 	//Cyan color that humans percieve when viewing extremely low light levels via rod cells in the eye
	float colorDesat = dot(color, vec3(1.0f)); 	//Desaturated color
	
	color = mix(color, vec3(colorDesat) * rodColor, amount);
	
}

void 	FixLightFalloff(inout float lightmap) { //Fixes the ugly lightmap falloff and creates a nice linear one
	float additive = 5.35f;
	float exponent = 40.0f;

	lightmap += additive;							//Prevent ugly fast falloff
	lightmap = pow(lightmap, exponent);			//Curve light falloff
	lightmap = max(0.0f, lightmap);		//Make sure light properly falls off to zero
	lightmap /= pow(1.0f + additive, exponent);
}


float 	CalculateLuminance(in vec3 color) {
	return (color.r * 0.2126f + color.g * 0.7152f + color.b * 0.0722f);
}

vec3 	Glowmap(in vec3 albedo, in bool mask, in float curve, in vec3 emissiveColor) {
	vec3 color = albedo * float(mask);
		 color = pow(color, vec3(curve));
		 color = vec3(CalculateLuminance(color));
		 color *= emissiveColor;

	return color;
}


float 	ChebyshevUpperBound(in vec2 moments, in float distance) {
	if (distance <= moments.x)
		return 1.0f;

	float variance = moments.y - (moments.x * moments.x);
		  variance = max(variance, 0.000002f);

	float d = distance - moments.x;
	float pMax = variance / (variance + d*d);

	return pMax;
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

float  	CalculateDitherPattern2() {
	int[16] ditherPattern = int[16] (4 , 12, 2,  10,
								 	 16, 8 , 14, 6 ,
								 	 0 , 9 , 3 , 11,
								 	 13, 5 , 15, 7 );

	vec2 count = vec2(0.0f);
	     count.x = floor(mod(texcoord.s * viewWidth, 4.0f));
		 count.y = floor(mod(texcoord.t * viewHeight, 4.0f));

	int dither = ditherPattern[int(count.x) + int(count.y) * 4];

	return float(dither) / 17.0f;
}


void DrawDebugSquare(inout vec3 color) {

	vec2 pix = vec2(1.0f / viewWidth, 1.0f / viewHeight);

	vec2 offset = vec2(0.5f);
	vec2 size = vec2(0.0f);
		 size.x = 1.0f / 2.0f;
		 size.y = 1.0f / 2.0f;

	vec2 padding = pix * 0.0f;
		 size += padding;

	if ( texcoord.s + offset.s / 2.0f + padding.x / 2.0f > offset.s &&
		 texcoord.s + offset.s / 2.0f + padding.x / 2.0f < offset.s + size.x &&
		 texcoord.t + offset.t / 2.0f + padding.y / 2.0f > offset.t &&
		 texcoord.t + offset.t / 2.0f + padding.y / 2.0f < offset.t + size.y
		)
	{
		
		int[16] ditherPattern = int[16] (0, 3, 0, 3,
										 2, 1, 2, 1,
										 0, 3, 0, 3,
										 2, 1, 2, 1);

		vec2 count = vec2(0.0f);
		     count.x = floor(mod(texcoord.s * viewWidth, 4.0f));
			 count.y = floor(mod(texcoord.t * viewHeight, 4.0f));

		int dither = ditherPattern[int(count.x) + int(count.y) * 4];
		color.rgb = vec3(float(dither) / 3.0f);
		
		
	}

}

/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct MCLightmapStruct {		//Lightmaps directly from MC engine
	float torch;				//Light emitted from torches and other emissive blocks
	float sky;					//Light coming from the sky
	float lightning;			//Light coming from lightning

	vec3 torchVector; 			//Vector in screen space that represents the direction of average light transfered
	vec3 skyVector;
} mcLightmap;



struct DiffuseAttributesStruct {			//Diffuse surface shading attributes
	float roughness;			//Roughness of surface. More roughness will use Oren Nayar reflectance.
	float translucency; 		//How translucent the surface is. Translucency represents how much energy will be transfered through the surface
	vec3  translucencyColor; 	//Color that will be multiplied with sunlight for backsides of translucent materials.
};

struct SpecularAttributesStruct {			//Specular surface shading attributes
	float specularity;			//How reflective a surface is
	float extraSpecularity;		//Additional reflectance for specular reflections from sun only
	float glossiness;			//How smooth or rough a specular surface is
	float metallic;				//from 0 - 1. 0 representing non-metallic, 1 representing fully metallic.
	float gain;					//Adjust specularity further
	float base;					//Reflectance when the camera is facing directly at the surface normal. 0 allows only the fresnel effect to add specularity
	float fresnelPower; 		//Curve of fresnel effect. Higher values mean the surface has to be viewed at more extreme angles to see reflectance
};

struct SkyStruct { 				//All sky shading attributes
	vec3 	albedo;				//Diffuse texture aka "color texture" of the sky
	vec3 	tintColor; 			//Color that will be multiplied with the sky to tint it
	vec3 	sunglow;			//Color that will be added to the sky simulating scattered light arond the sun/moon
	vec3 	sunSpot; 			//Actual sun surface
};

struct WaterStruct {
	vec3 albedo;
};

struct MaskStruct {

	float matIDs;

	bool sky;
	bool land;
	bool tallGrass;
	bool leaves;
	bool ice;
	bool hand;
	bool translucent;
	bool glow;
	bool goldBlock;
	bool ironBlock;
	bool diamondBlock;
	bool emeraldBlock;
	bool sand;
	bool sandstone;
	bool stone;
	bool cobblestone;
	bool wool;
	bool clouds;

	bool torch;
	bool lava;
	bool glowstone;
	bool fire;

	bool water;

};

struct CloudsStruct {
	vec3 albedo;
};

struct SurfaceStruct { 			//Surface shading properties, attributes, and functions
	
	//Attributes that change how shading is applied to each pixel
		DiffuseAttributesStruct  diffuse;			//Contains all diffuse surface attributes
		SpecularAttributesStruct specular;			//Contains all specular surface attributes

	SkyStruct 	    sky;			//Sky shading attributes and properties
	WaterStruct 	water;			//Water shading attributes and properties
	MaskStruct 		mask;			//Material ID Masks
	CloudsStruct 	clouds;
	
	//Properties that are required for lighting calculation
		vec3 	albedo;					//Diffuse texture aka "color texture"
		vec3 	normal;					//Screen-space surface normals
		float 	depth;					//Scene depth

		vec4	worldSpacePosition;	//Vector representing the screen-space position of the surface
		vec3 	viewVector; 			//Vector representing the viewing direction
		vec3 	lightVector; 			//Vector representing sunlight direction
		vec3  	upVector;				//Vector representing "up" direction
		float 	NdotL; 					//dot(normal, lightVector). used for direct lighting calculation
} surface;

struct LightmapStruct {			//Lighting information to light the scene. These are untextured colored lightmaps to be multiplied with albedo to get the final lit and textured image.
	vec3 sunlight;				//Direct light from the sun
	vec3 skylight;				//Ambient light from the sky
	vec3 bouncedSunlight;		//Fake bounced light, coming from opposite of sun direction and adding to ambient light
	vec3 scatteredSunlight;		//Fake scattered sunlight, coming from same direction as sun and adding to ambient light
	vec3 scatteredUpLight; 		//Fake GI from ground
	vec3 torchlight;			//Light emitted from torches and other emissive blocks
	vec3 lightning;				//Light caused by lightning
	vec3 nolight;				//Base ambient light added to everything. For lighting caves so that the player can barely see even when no lights are present
	vec3 specular;				//Reflected direct light from sun
	vec3 translucent;			//Light on the backside of objects representing thin translucent materials
	vec3 sky;					//Color and brightness of the sky itself
	vec3 underwater;			//underwater lightmap
} lightmap;

struct ShadingStruct {			//Shading calculation variables
	float   direct;
	float 	waterDirect;
	float 	bounced; 			//Fake bounced sunlight
	float 	skylight; 			//Light coming from sky
	float 	scattered; 			//Fake scattered sunlight
	float   scatteredUp; 		//Fake GI from ground
	float 	specular; 			//Reflected direct light
	float 	translucent; 		//Backside of objects lit up from the sun via thin translucent materials	
	float 	sunlightVisibility; //Shadows
} shading;

struct GlowStruct {
	vec3 torch;
	vec3 lava;
	vec3 glowstone;
	vec3 fire;
};

struct FinalStruct {			//Final textured and lit images sorted by what is illuminating them.
	
	GlowStruct 		glow;		//Struct containing emissive material final images

	vec3 sunlight;				//Direct light from the sun
	vec3 skylight;				//Ambient light from the sky
	vec3 bouncedSunlight;		//Fake bounced light, coming from opposite of sun direction and adding to ambient light
	vec3 scatteredSunlight;		//Fake scattered sunlight, coming from same direction as sun and adding to ambient light
	vec3 scatteredUpLight; 		//Fake GI from ground
	vec3 torchlight;			//Light emitted from torches and other emissive blocks
	vec3 lightning;				//Light caused by lightning
	vec3 nolight;				//Base ambient light added to everything. For lighting caves so that the player can barely see even when no lights are present
	vec3 translucent;			//Light on the backside of objects representing thin translucent materials
	vec3 sky;					//Color and brightness of the sky itself
	vec3 underwater;			//underwater colors
	

} final;


/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//Mask
void 	CalculateMasks(inout MaskStruct mask) {
		mask.sky 			= GetMaterialMask(texcoord.st, 0, mask.matIDs);
		mask.land	 		= GetMaterialMask(texcoord.st, 1, mask.matIDs);
		mask.tallGrass 		= GetMaterialMask(texcoord.st, 2, mask.matIDs);
		mask.leaves	 		= GetMaterialMask(texcoord.st, 3, mask.matIDs);
		mask.ice		 	= GetMaterialMask(texcoord.st, 4, mask.matIDs);
		mask.hand	 		= GetMaterialMask(texcoord.st, 5, mask.matIDs);
		mask.translucent	= GetMaterialMask(texcoord.st, 6, mask.matIDs);

		mask.glow	 		= GetMaterialMask(texcoord.st, 10, mask.matIDs);

		mask.goldBlock 		= GetMaterialMask(texcoord.st, 20, mask.matIDs);
		mask.ironBlock 		= GetMaterialMask(texcoord.st, 21, mask.matIDs);
		mask.diamondBlock	= GetMaterialMask(texcoord.st, 22, mask.matIDs);
		mask.emeraldBlock	= GetMaterialMask(texcoord.st, 23, mask.matIDs);
		mask.sand	 		= GetMaterialMask(texcoord.st, 24, mask.matIDs);
		mask.sandstone 		= GetMaterialMask(texcoord.st, 25, mask.matIDs);
		mask.stone	 		= GetMaterialMask(texcoord.st, 26, mask.matIDs);
		mask.cobblestone	= GetMaterialMask(texcoord.st, 27, mask.matIDs);
		mask.wool			= GetMaterialMask(texcoord.st, 28, mask.matIDs);
		mask.clouds 		= GetMaterialMask(texcoord.st, 29, mask.matIDs);

		mask.torch 			= GetMaterialMask(texcoord.st, 30, mask.matIDs);
		mask.lava 			= GetMaterialMask(texcoord.st, 31, mask.matIDs);
		mask.glowstone 		= GetMaterialMask(texcoord.st, 32, mask.matIDs);
		mask.fire 			= GetMaterialMask(texcoord.st, 33, mask.matIDs);

		mask.water 			= GetWaterMask(texcoord.st, mask.matIDs);
}

//Surface
void 	CalculateNdotL(inout SurfaceStruct surface) {		//Calculates direct sunlight without visibility check
	float direct = dot(surface.normal.rgb, surface.lightVector);
		  direct = direct * 1.0f + 0.0f;
		  //direct = clamp(direct, 0.0f, 1.0f);

	surface.NdotL = direct;
}

float 	CalculateDirectLighting(in SurfaceStruct surface) {

	//Tall grass translucent shading
	if (surface.mask.tallGrass) {
		return 1.0f;
	

	//Leaves
	} else if (surface.mask.leaves) {

		if (surface.NdotL > -0.01f) {
			return surface.NdotL * 0.99f + 0.01f;
		} else {
			return abs(surface.NdotL) * 0.25f;
		}


	//clouds
	} else if (surface.mask.clouds) {

		return 0.5f;


	//Default lambert shading
	} else {
		return max(0.0f, surface.NdotL * 0.99f + 0.01f);
	}
}

float 	CalculateSunlightVisibility(inout SurfaceStruct surface, in ShadingStruct shading) {				//Calculates shadows
	if (rainStrength >= 0.99f)
		return 1.0f;


	if (shading.direct > 0.0f) {
		float distance = sqrt(  surface.worldSpacePosition.x * surface.worldSpacePosition.x 	//Get surface distance in meters
							  + surface.worldSpacePosition.y * surface.worldSpacePosition.y 
							  + surface.worldSpacePosition.z * surface.worldSpacePosition.z);
		
		vec4 worldposition = vec4(0.0f);
			 worldposition = gbufferModelViewInverse * surface.worldSpacePosition;		//Transform from screen space to world space
			
		float yDistanceSquared  = worldposition.y * worldposition.y;
		
		worldposition = shadowModelView * worldposition;	//Transform from world space to shadow space
		float comparedepth = -worldposition.z;				//Surface distance from sun to be compared to the shadow map
		
		worldposition = shadowProjection * worldposition;													
		worldposition /= worldposition.w;

		float dist = sqrt(worldposition.x * worldposition.x + worldposition.y * worldposition.y);
		float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
		worldposition.xy *= 1.0f / distortFactor;
		worldposition = worldposition * 0.5f + 0.5f;		//Transform from shadow space to shadow map coordinates
		
		float shadowMult = 0.0f;																			//Multiplier used to fade out shadows at distance
		float shading = 0.0f;
		
		if (distance < shadowDistance && comparedepth > 0.0f &&											//Avoid computing shadows past the shadow map projection
			 worldposition.s < 1.0f && worldposition.s > 0.0f && worldposition.t < 1.0f && worldposition.t > 0.0f) {
			 
			float fademult = 0.15f;
				shadowMult = clamp((shadowDistance * 0.85f * fademult) - (distance * fademult), 0.0f, 1.0f);	//Calculate shadowMult to fade shadows out
			
			float diffthresh = dist * 1.0f + 0.2f;
			float bias = dist * 1.0f + 0.1f;

			#if defined ENABLE_SOFT_SHADOWS

				int count = 0;
				float spread = 2.0f;

				// vec2 dithercoord = vec2(0.0f);
				// 	 dithercoord.x = 0.5f - CalculateDitherPattern1();
				// 	 dithercoord.y = 0.5f - CalculateDitherPattern2();

				diffthresh /= 1.0f;

				float shadowCoverage = (comparedepth - (0.05f + (texture2DLod(shadow, worldposition.st, 2).z) * (256.0f - 0.05f)));
					  shadowCoverage = clamp(shadowCoverage * 10.0f, 0.0f, 1.0f);

				if (shadowCoverage >= 0.5f)
				{
					for (float i = -1.5f; i <= 1.5f; i += 1.0f) {
						for (float j = -1.5f; j <= 1.5f; j += 1.0f) {
							 shading += shadowMult * (clamp(comparedepth - (0.05f + (texture2DLod(shadow, worldposition.st + vec2(i, j) * 0.0002f * spread/* + dithercoord * 0.0005f * spread*/, 0).z) * (256.0f - 0.05f)), 0.0f, diffthresh)/(diffthresh));
							count += 1;
						}
					}
					shading /= count;
				} else {
					shading = 0.0f;
				}

				 
				 //shading = shadowCoverage;


			#elif defined ENABLE_FAST_SOFT_SHADOWS

				float coverage = 0.0f;
				float pArea = 10.0f;
				float pAreaDiff = 0.5f;
				float spread = 1.0f;

				int count = 0;
				for (float i = -0.5f; i <= 0.5f; i += 1.0f) {
					for (float j = -0.5f; j <= 0.5f; j += 1.0f) {
						float shadowSample = (comparedepth - (0.05f + (texture2DLod(shadow, worldposition.st + vec2(i, j) * 0.0006f * spread, 0).z) * (256.0f - 0.05f)));
						coverage = max(coverage, shadowSample);
						pArea = min(pArea, clamp(shadowSample, 0.0f, pAreaDiff) / pAreaDiff);
						//coverage += clamp((comparedepth - (0.05f + (texture2DLod(shadow, worldposition.st + vec2(i, j) * 0.0002f * spread).z) * (256.0f - 0.05f))), 0.0f, 5.0f);
						count += 1;
					}
				}

				//coverage /= count;

				float normalShadow = (clamp(comparedepth - (0.05f + (texture2DLod(shadow, worldposition.st, 0).z) * (256.0f - 0.05f)), 0.0f, pAreaDiff)/(pAreaDiff));

				float penumbraArea = clamp(normalShadow - pArea, 0.0f, 1.0f);
					  penumbraArea = clamp(penumbraArea * 3.0f, 0.0f, 1.0f);

				float diff = coverage + 0.15f;


				shading = shadowMult * (clamp(comparedepth - (0.05f + (texture2DLod(shadow, worldposition.st, 0).z) * (256.0f - 0.05f)), 0.0f, diff)/(diff));

				shading = mix(normalShadow, shading, penumbraArea);
				//shading = coverage;

				//shading = clamp(shading * 1.0f, 0.0f, 1.0f);
				//shading = penumbraArea;


			#elif defined VARIABLE_PENUMBRA_SHADOWS

				float coverage = 0.0f;
				float pArea = 10.0f;
				float shadowDepth = 0.0f;


				float spread = 2.0f;
				float pAreaDiff = 1.25f;

				int count = 0;

					float shadowSample = (comparedepth - (0.05f + (texture2DLod(shadow, worldposition.st, 4).z) * (256.0f - 0.05f)));
					pArea = clamp(shadowSample, 0.0f, pAreaDiff) / pAreaDiff;
					shadowDepth = shadowSample;

				float normalDiff = 0.15f;
				float normalShadow = shadowMult * (clamp(comparedepth - (0.05f + (texture2DLod(shadow, worldposition.st, 0).z) * (256.0f - 0.05f)), 0.0f, normalDiff)/(normalDiff));

				float penumbraArea = clamp(pArea, 0.0f, 1.0f);
					  penumbraArea = clamp(penumbraArea * 4.0f - 1.0f, 0.0f, 1.0f);


				#ifdef VPS_HIGH_QUALITY
					

					if (penumbraArea > 0.01f) {

						vec2 dithercoord = vec2(0.0f);
						 	 dithercoord.x = 0.5f - CalculateDitherPattern1();
						 	 dithercoord.y = 0.5f - CalculateDitherPattern2();

						shadowDepth = min(shadowDepth, 20.0f);
						shadowDepth += 0.0f;

						float confusion = shadowDepth / 10.0f;
							  confusion *= spread / 2.0f;
							  confusion *= 1.0f / distortFactor;

						float diff = 0.15f + shadowDepth * spread * 0.101f;

						count = 0;
						for (float i = -3.0f; i <= 3.0f; i += 1.0f) {
							for (float j = -3.0f; j <= 3.0f; j += 1.0f) {
								shading += shadowMult * (clamp(comparedepth - (0.05f + (texture2DLod(shadow, worldposition.st + vec2(i, j) * 0.0002f * confusion + dithercoord * 0.0005f * confusion, 0).z) * (256.0f - 0.05f)), 0.0f, diff)/(diff));
								count += 1;
							}
						}

						shading /= count;
					} else {
						shading = normalShadow;
					}

				#else

					if (penumbraArea > 0.01f) {

						vec2 dithercoord = vec2(0.0f);
						 	 dithercoord.x = 0.5f - CalculateDitherPattern1();
						 	 dithercoord.y = 0.5f - CalculateDitherPattern2();

						shadowDepth = min(shadowDepth, 20.0f);
						shadowDepth += 0.0f;

						float confusion = shadowDepth / 10.0f;
							  confusion *= spread;
							  confusion *= 1.0f / distortFactor;

						float diff = 0.15f + shadowDepth * spread * 0.0101f;

						count = 0;
						for (float i = -1.0f; i <= 1.0f; i += 1.0f) {
							for (float j = -1.0f; j <= 1.0f; j += 1.0f) {
								shading += shadowMult * (clamp(comparedepth - (0.05f + (texture2DLod(shadow, worldposition.st + vec2(i, j) * 0.0002f * confusion + dithercoord * 0.0005f * confusion, 0).z) * (256.0f - 0.05f)), 0.0f, diff)/(diff));
								count += 1;
							}
						}

						shading /= count;
					} else {
						shading = normalShadow;
					}

				#endif


				//shading = coverage;

				//shading = clamp(shading * 1.0f, 0.0f, 1.0f);
				//shading = penumbraArea;

			#else
				shading = shadowMult * (clamp(comparedepth - (bias + (texture2DLod(shadow, worldposition.st, 0).z) * (256.0f - bias)), 0.0f, diffthresh)/(diffthresh));
			#endif

			
		}
		
		shading = 1.0f - shading;
		
		return shading;
	} else {
		return 0.0f;
	}
}

float 	CalculateBouncedSunlight(in SurfaceStruct surface) {

	float NdotL = surface.NdotL;
	float bounced = clamp(-NdotL + 0.95f, 0.0f, 1.95f) / 1.95f;
		  bounced = bounced * bounced * bounced;
	
	return bounced;
}

float 	CalculateScatteredSunlight(in SurfaceStruct surface) {

	float NdotL = surface.NdotL;
	float scattered = clamp(NdotL + 0.55f, 0.0f, 1.55f) / 1.55f;
		  scattered *= scattered * scattered;
		  
	return scattered;
}

float 	CalculateSkylight(in SurfaceStruct surface) {

	if (surface.mask.clouds) {
		return 1.0f;
	} else {

		float skylight = dot(surface.normal, surface.upVector);
			  skylight = skylight * 0.5f + 0.5f;

		return skylight;
	}
}

float 	CalculateScatteredUpLight(in SurfaceStruct surface) {
	float scattered = dot(surface.normal, surface.upVector);
		  scattered = scattered * 0.5f + 0.5f;
		  scattered = 1.0f - scattered;

	return scattered;
}

float   CalculateSunglow(in SurfaceStruct surface) {

	float curve = 4.0f;

	vec3 npos = normalize(surface.worldSpacePosition.xyz);
	vec3 halfVector2 = normalize(-surface.lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

float   CalculateAntiSunglow(in SurfaceStruct surface) {

	float curve = 4.0f;

	vec3 npos = normalize(surface.worldSpacePosition.xyz);
	vec3 halfVector2 = normalize(surface.lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

bool   CalculateSunspot(in SurfaceStruct surface) {

	float curve = 1.0f;

	vec3 npos = normalize(surface.worldSpacePosition.xyz);
	vec3 halfVector2 = normalize(-surface.lightVector + npos);

	float sunProximity = 1.0f - dot(halfVector2, npos);

	if (sunProximity > 0.96f) {
		return true;
	} else {
		return false;
	}
}

void 	GetLightVectors(inout MCLightmapStruct mcLightmap, in SurfaceStruct surface) {

	vec2 torchDiff = vec2(0.0f);
		 torchDiff.x = GetLightmapTorch(texcoord.st) - GetLightmapTorch(texcoord.st + vec2(1.0f / viewWidth, 0.0f));
		 torchDiff.y = GetLightmapTorch(texcoord.st) - GetLightmapTorch(texcoord.st + vec2(0.0f, 1.0f / viewWidth));

		 //torchDiff /= GetDepthLinear(texcoord.st);

	mcLightmap.torchVector.x = torchDiff.x * 200.0f;
	//mcLightmap.torchVector.x *= 1.0f - surface.viewVector.x;

	mcLightmap.torchVector.y = torchDiff.y * 200.0f;

	mcLightmap.torchVector.x = 1.0f;
	mcLightmap.torchVector.y = 0.0f;
	mcLightmap.torchVector.z = sqrt(1.0f - mcLightmap.torchVector.x * mcLightmap.torchVector.x + mcLightmap.torchVector.y + mcLightmap.torchVector.y);

	


	float torchNormal = dot(surface.normal.rgb, mcLightmap.torchVector.rgb);

	mcLightmap.torchVector.x = torchNormal;


	//mcLightmap.torchVector = mcLightmap.torchVector * 0.5f + 0.5f;
}

void 	AddSkyGradient(inout SurfaceStruct surface) {
	float curve = 3.0f;
	vec3 npos = normalize(surface.worldSpacePosition.xyz);
	vec3 halfVector2 = normalize(-surface.upVector + npos);
	float skyGradientFactor = dot(halfVector2, npos);
	float skyDirectionGradient = skyGradientFactor;

	skyGradientFactor = pow(skyGradientFactor, curve);
	surface.sky.albedo *= mix(skyGradientFactor, 1.0f, clamp((0.145f - (timeNoon * 0.1f)) + rainStrength, 0.0f, 1.0f));

	vec3 skyBlueColor = vec3(0.5f, 0.6f, 1.0f) * 1.5f;

	float fade1 = clamp(skyGradientFactor - 0.15f, 0.0f, 0.2f) / 0.2f;
	vec3 color1 = vec3(1.0f, 1.3, 1.0f);

	surface.sky.albedo *= mix(skyBlueColor, color1, vec3(fade1));

	float fade2 = clamp(skyGradientFactor - 0.18f, 0.0f, 0.2f) / 0.2f;
	vec3 color2 = vec3(1.7f, 1.0f, 0.8f);

	surface.sky.albedo *= mix(vec3(1.0f), color2, vec3(fade2 * 0.5f));



	float horizonGradient = 1.0f - distance(skyDirectionGradient, 0.72f) / 0.72f;
		  horizonGradient = pow(horizonGradient, 10.0f);
		  horizonGradient = max(0.0f, horizonGradient);

	float sunglow = CalculateSunglow(surface);
		  horizonGradient *= sunglow * 2.0f + (0.65f - timeSunrise * 0.55f - timeSunset * 0.55f);

	vec3 horizonColor1 = vec3(1.5f, 1.5f, 1.5f);
		 horizonColor1 = mix(horizonColor1, vec3(1.5f, 1.95f, 1.5f) * 2.0f, vec3(timeSunrise + timeSunset));
	vec3 horizonColor2 = vec3(1.5f, 1.2f, 0.8f) * 1.0f;
		 horizonColor2 = mix(horizonColor2, vec3(1.9f, 0.6f, 0.4f) * 2.0f, vec3(timeSunrise + timeSunset));

	surface.sky.albedo *= mix(vec3(1.0f), horizonColor1, vec3(horizonGradient) * (1.0f - timeMidnight));
	surface.sky.albedo *= mix(vec3(1.0f), horizonColor2, vec3(pow(horizonGradient, 2.0f)) * (1.0f - timeMidnight));

	float grayscale = surface.sky.albedo.r + surface.sky.albedo.g + surface.sky.albedo.b;
		  grayscale /= 3.0f;

	surface.sky.albedo = mix(surface.sky.albedo, vec3(grayscale), vec3(rainStrength));
}

void 	AddSunglow(inout SurfaceStruct surface) {
	float sunglowFactor = CalculateSunglow(surface);
	float antiSunglowFactor = CalculateAntiSunglow(surface);

	surface.sky.albedo *= 1.0f + sunglowFactor * (10.0f + timeNoon * 5.0f) * (1.0f - rainStrength);
	surface.sky.albedo *= mix(vec3(1.0f), colorSunlight, clamp(vec3(sunglowFactor) * (1.0f - timeMidnight) * (1.0f - rainStrength), vec3(0.0f), vec3(1.0f)));

	surface.sky.albedo *= 1.0f + antiSunglowFactor * 2.0f * (1.0f - rainStrength);
	//surface.sky.albedo *= mix(vec3(1.0f), colorSunlight, antiSunglowFactor);
}


void 	AddCloudGlow(inout vec3 color, in SurfaceStruct surface) {
	float glow = CalculateSunglow(surface);
		  glow = pow(glow, 1.0f);

	float mult = mix(50.0f, 800.0f, timeSkyDark);

	color.rgb *= 1.0f + glow * mult * float(surface.mask.clouds);
}


void 	CalculateUnderwaterFog(in SurfaceStruct surface, inout vec3 finalComposite) {
	vec3 fogColor = colorWaterMurk * vec3(colorSkylight.b);
	// float fogDensity = 0.045f;
	// float fogFactor = exp(GetDepthLinear(texcoord.st) * fogDensity) - 1.0f;
	// 	  fogFactor = min(fogFactor, 1.0f);
	float fogFactor = GetDepthLinear(texcoord.st) / 100.0f;
		  fogFactor = min(fogFactor, 0.7f);
		  fogFactor = sin(fogFactor * 3.1415 / 2.0f);
		  fogFactor = pow(fogFactor, 0.5f);

	
	finalComposite.rgb = mix(finalComposite.rgb, fogColor * 0.002f, vec3(fogFactor));
	finalComposite.rgb *= mix(vec3(1.0f), colorWaterBlue * colorWaterBlue * colorWaterBlue * colorWaterBlue, vec3(fogFactor));
	//finalComposite.rgb = vec3(0.1f);
}

float 	SphereTestDistance(in vec3 p)
{
	return max(0.0f, length(p)-1.0f);
}

void 	TestRaymarch(inout vec3 color, in SurfaceStruct surface)
{

	//visualize march steps
	float rayDepth = 0.0f;
	float rayIncrement = 0.1f;
	float fogFactor = 0.0f;

	// while (rayDepth < far / 20.0f)
	// {

	// 	if (abs(-rayDepth - surface.worldSpacePosition.z) < 0.005f)
	// 	{
	// 		color.rgb = vec3(0.01f, 0.0f, 0.0f);
	// 	}

	// 	// if (SphereTestDistance(vec3(surface.worldSpacePosition.x, surface.worldSpacePosition.y, surface.worldSpacePosition.z)) <= 0.001f)
	// 	// 	fogFactor += 0.001f;

	// 	rayDepth += rayIncrement;

	// }

	//color.rgb = mix(color.rgb, vec3(1.0f) * 0.01f, fogFactor);

	// vec4 newPosition = surface.worldSpacePosition;

	// color.rgb = vec3(distance(newPosition.rgb, vec3(0.0f, 0.0f, 0.0f)) * 0.00001f);

}


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main() {
	
	//Initialize surface properties required for lighting calculation for any surface that is not part of the sky
	surface.albedo 				= GetAlbedoLinear(texcoord.st);					//Gets the albedo texture
	surface.albedo 				= pow(surface.albedo, vec3(1.15f));
	surface.normal 				= GetNormals(texcoord.st);						//Gets the screen-space normals
	surface.depth  				= GetDepth(texcoord.st);						//Gets the scene depth
	surface.worldSpacePosition  = GetWorldSpacePosition(texcoord.st); 			//Gets the screen-space position
	surface.viewVector 			= normalize(surface.worldSpacePosition.rgb);	//Gets the view vector
	surface.lightVector 		= lightVector;									//Gets the sunlight vector
	surface.upVector 			= upVector;										//Store the up vector



	surface.mask.matIDs 		= GetMaterialIDs(texcoord.st);					//Gets material ids
	CalculateMasks(surface.mask);
	


	surface.albedo *= 1.0f - float(surface.mask.sky); 						//Remove the sky from surface albedo, because sky will be handled separately
	
	//surface.water.albedo = surface.albedo * float(surface.mask.water);		//Store underwater albedo
	//surface.albedo *= 1.0f - float(surface.mask.water);						//Remove water from surface albedo to handle water separately
	
	

	//Initialize sky surface properties
	surface.sky.albedo 		= GetAlbedoLinear(texcoord.st) * float(surface.mask.sky);							//Gets the albedo texture for the sky

	surface.sky.tintColor 	= mix(colorSunlight, vec3(colorSunlight.r), vec3(0.8f));									//Initializes the defualt tint color for the sky
	surface.sky.tintColor 	*= mix(1.0f, 100.0f, timeSkyDark); 													//Boost sky color at night																		//Scale sunglow back to be less intense
	
	surface.sky.sunSpot   	= vec3(float(CalculateSunspot(surface))) * vec3(float(surface.mask.sky)) * colorSunlight;
	surface.sky.sunSpot 	*= 1.0f - timeMidnight;
	surface.sky.sunSpot   	*= 1500.0f;
	surface.sky.sunSpot 	*= 1.0f - rainStrength;
	//surface.sky.sunSpot     *= 1.0f - timeMidnight;

	AddSkyGradient(surface);
	AddSunglow(surface);
	
	
	
	//Initialize MCLightmap values
	mcLightmap.torch 		= GetLightmapTorch(texcoord.st);	//Gets the lightmap for light coming from emissive blocks


	mcLightmap.sky   		= GetLightmapSky(texcoord.st);		//Gets the lightmap for light coming from the sky
	// mcLightmap.sky 		= 1.0f / pow((1.0f - mcLightmap.sky + 0.00001f), 2.0f);
	// mcLightmap.sky 		-= 1.0f;
	// mcLightmap.sky 		= max(0.0f, mcLightmap.sky);

	mcLightmap.lightning    = 0.0f;								//gets the lightmap for light coming from lightning
	
	
	//Initialize default surface shading attributes
	surface.diffuse.roughness 			= 0.0f;					//Default surface roughness
	surface.diffuse.translucency 		= 0.0f;					//Default surface translucency
	surface.diffuse.translucencyColor 	= vec3(1.0f);			//Default translucency color
	
	surface.specular.specularity 		= GetSpecularity(texcoord.st);	//Gets the reflectance/specularity of the surface
	surface.specular.extraSpecularity 	= 0.0f;							//Default value for extra specularity
	surface.specular.glossiness 		= 50.0f;						//Default surface glossiness
	surface.specular.metallic 			= 0.0f;							//Default value of how metallic the surface is
	surface.specular.gain 				= 1.0f;							//Default surface specular gain
	surface.specular.base 				= 0.0f;							//Default reflectance when the surface normal and viewing normal are aligned
	surface.specular.fresnelPower 		= 5.0f;							//Default surface fresnel power
	
	
	//Modify surface shading attributes on a per-block basis
	
	
	
	
	
	//Calculate surface shading
	CalculateNdotL(surface);														
	shading.direct  			= CalculateDirectLighting(surface);				//Calculate direct sunlight without visibility check (shadows)
	shading.direct  			= mix(shading.direct, 1.0f, float(surface.mask.water)); //Remove shading from water
	shading.sunlightVisibility 	= CalculateSunlightVisibility(surface, shading);					//Calculate shadows and apply them to direct lighting
	shading.direct 				*= shading.sunlightVisibility;							
	shading.direct 				*= mix(1.0f, 0.0f, rainStrength);
	shading.waterDirect 		= shading.direct;
	shading.direct 				*= pow(mcLightmap.sky, 0.1f);
	shading.bounced 	= CalculateBouncedSunlight(surface);			//Calculate fake bounced sunlight
	shading.scattered 	= CalculateScatteredSunlight(surface);			//Calculate fake scattered sunlight
	shading.skylight 	= CalculateSkylight(surface);					//Calculate scattered light from sky
	shading.scatteredUp = CalculateScatteredUpLight(surface);
	
	
	
	
	
	//Colorize surface shading and store in lightmaps
	lightmap.sunlight 			= vec3(shading.direct) * colorSunlight;
	lightmap.skylight 			= vec3(mcLightmap.sky);
	lightmap.skylight 			*= mix(colorSkylight, colorSunlight, max(vec3(0.0f), vec3(1.0f - pow(mcLightmap.sky + 0.2f, 0.45f)) * 1.0f));
	lightmap.skylight 			*= shading.skylight;
	lightmap.skylight 			*= mix(1.0f, 5.0f, float(surface.mask.clouds));
	lightmap.skylight 			*= mix(1.0f, 50.0f, float(surface.mask.clouds) * timeSkyDark);
	lightmap.bouncedSunlight	= vec3(shading.bounced) * colorBouncedSunlight;
	lightmap.bouncedSunlight 	*= pow(vec3(mcLightmap.sky), vec3(0.75f));
	lightmap.bouncedSunlight 	*= mix(1.0f, 0.25f, timeSunrise + min(timeSunset + (rainStrength), 1.0f));
	lightmap.scatteredSunlight  = vec3(shading.scattered) * colorScatteredSunlight;
	lightmap.scatteredSunlight 	*= pow(vec3(mcLightmap.sky), vec3(1.0f));
	lightmap.underwater 		= vec3(mcLightmap.sky) * colorSkylight;
	lightmap.torchlight 		= mcLightmap.torch * colorTorchlight;
	lightmap.nolight 			= vec3(0.05f);
	lightmap.scatteredUpLight 	= vec3(shading.scatteredUp) * mix(colorSunlight, colorSkylight, vec3(0.0f));
	lightmap.scatteredUpLight  *= pow(mcLightmap.sky, 0.5f);
	//lightmap.scatteredUpLight  *= mix(1.0f, 1.2f, rainStrength);


	AddCloudGlow(lightmap.sunlight, surface);


	//If eye is in water
	if (isEyeInWater > 0) {
		vec3 halfColor = mix(colorWaterMurk, vec3(1.0f), vec3(0.5f));
		lightmap.sunlight *= mcLightmap.sky * halfColor;
		lightmap.skylight *= halfColor;
		lightmap.bouncedSunlight *= 0.0f;
		lightmap.scatteredSunlight *= halfColor;
		lightmap.nolight *= halfColor;
		lightmap.scatteredUpLight *= halfColor;
	}
	
	
	//Apply lightmaps to albedo and generate final shaded surface
	final.nolight 			= surface.albedo * lightmap.nolight;
	final.sunlight 			= surface.albedo * lightmap.sunlight;
	final.skylight 			= surface.albedo * lightmap.skylight;
	final.bouncedSunlight 	= surface.albedo * lightmap.bouncedSunlight;
	final.scatteredSunlight = surface.albedo * lightmap.scatteredSunlight;
	final.scatteredUpLight  = surface.albedo * lightmap.scatteredUpLight;
	final.torchlight 		= surface.albedo * lightmap.torchlight;
	final.underwater        = surface.water.albedo * colorWaterBlue;
	// final.underwater 		*= GetUnderwaterLightmapSky(texcoord.st);
	// final.underwater  		+= vec3(0.9f, 1.00f, 0.35f) * float(surface.mask.water) * 0.065f;
	 final.underwater 		*= (lightmap.sunlight * 0.3f) + (lightmap.skylight * 0.06f) + (lightmap.torchlight * 0.0165) + (lightmap.nolight * 0.002f);


	//final.glow.torch 				= pow(surface.albedo, vec3(4.0f)) * float(surface.mask.torch);
	final.glow.lava 				= Glowmap(surface.albedo, surface.mask.lava,      3.0f, vec3(1.0f, 0.05f, 0.00f));

	final.glow.glowstone 			= Glowmap(surface.albedo, surface.mask.glowstone, 3.0f, colorTorchlight);

	final.glow.fire 				= surface.albedo * float(surface.mask.fire);
	final.glow.fire 				= pow(final.glow.fire, vec3(2.0f));


	//Remove glow items from torchlight to keep control
	final.torchlight *= 1.0f - float(surface.mask.lava);
	

	//Do night eye effect on outdoor lighting and sky
	DoNightEye(final.sunlight);
	DoNightEye(final.skylight);
	DoNightEye(final.bouncedSunlight);
	DoNightEye(final.scatteredSunlight);
	DoNightEye(surface.sky.albedo);
	DoNightEye(final.underwater);

	DoLowlightEye(final.nolight);

	
	
	
	//Apply lightmaps to albedo and generate final shaded surface
	vec3 finalComposite = final.sunlight 			* 0.4f				//Add direct sunlight
						+ final.skylight 			* 0.08f				//Add ambient skylight
						+ final.nolight 			* 0.0002f 			//Add base ambient light
						+ final.bouncedSunlight 	* 0.04f				//Add fake bounced sunlight
						+ final.scatteredSunlight 	* 0.00f				//Add fake scattered sunlight
						+ final.scatteredUpLight 	* 0.010f
						+ final.torchlight 			* 11.0f 			//Add light coming from emissive blocks
						//+ final.underwater 			* 0.175f				//Add light behind water
						//+ final.glow.torch			* 500.0f 			
						+ final.glow.lava			* 5.6f 			
						+ final.glow.glowstone		* 4.1f 			
						+ final.glow.fire			* 0.35f 			
						;
						
	//Apply sky to final composite
		 surface.sky.albedo *= 0.65f;
		 surface.sky.albedo = surface.sky.albedo * surface.sky.tintColor + surface.sky.sunglow + surface.sky.sunSpot;
		 //DoNightEye(surface.sky.albedo);
		 finalComposite 	+= surface.sky.albedo;		//Add sky to final image


	//if eye is in water, do underwater fog
	if (isEyeInWater > 0) {
		CalculateUnderwaterFog(surface, finalComposite);
	}
	

	 finalComposite *= 0.0005f;												//Scale image down for HDR
	 finalComposite.b *= 1.0f;


	 TestRaymarch(finalComposite.rgb, surface);


	 finalComposite = pow(finalComposite, vec3(1.0f / 2.2f)); 					//Convert final image into gamma 0.45 space to compensate for gamma 2.2 on displays
	 finalComposite = pow(finalComposite, vec3(1.0f / BANDING_FIX_FACTOR)); 	//Convert final image into banding fix space to help reduce color banding
	

	if (finalComposite.r > 1.0f) {
		finalComposite.r = 0.0f;
	}

	if (finalComposite.g > 1.0f) {
		finalComposite.g = 0.0f;
	}

	if (finalComposite.b > 1.0f) {
		finalComposite.b = 0.0f;
	}

	//DrawDebugSquare(finalComposite.rgb);
	surface.depth += float(surface.mask.hand) * 0.0f;


	//Put sunlight visibility into matID texture



	gl_FragData[0] = vec4(finalComposite, 1.0f);
	gl_FragData[1] = vec4(surface.mask.matIDs, mcLightmap.torch, mcLightmap.sky, 1.0f);
	gl_FragData[2] = vec4(surface.normal.rgb * 0.5f + 0.5f, 1.0f);
	// gl_FragData[2] = vec4(surface.normal.b * 0.5f + 0.5f, surface.mask.matIDs, GetWaterTex(texcoord.st), 1.0f);

}
