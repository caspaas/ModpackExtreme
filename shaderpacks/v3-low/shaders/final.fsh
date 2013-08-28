#version 120


/*

Chocapic13' shaders, derived from SonicEther v10 rc6
Place two leading Slashes in front of the following '#define' lines in order to disable an option.

*/


#define GODRAYS
#define GODRAYS_EXPOSURE 0.11
#define GODRAYS_SAMPLES 6
#define GODRAYS_DECAY 0.99
#define GODRAYS_DENSITY 0.30
#define LENS				
#define LENS_POWER 0.34						//lens effect intensity	
//#define BLOOM								
//#define DOF								//broken



//color post-process
#define VIGNETTE
#define VIGNETTE_STRENGTH 1.3
#define CROSSPROCESS
#define BRIGHTMULT 1.0                 	// 1.0 = default brightness. Higher values mean brighter. 0 would be black.
#define DARKMULT 0.00						// 0.0 = normal image. Higher values will darken dark colors.
#define COLOR_BOOST	0.1					// 0.0 = normal saturation. Higher values mean more saturated image.
#define HIGHDESATURATE
#define GAMMA 1.0							//1.0 is default brightness. lower values will brighten image, higher values will darken image	
#define TONEMAP
#define TONEMAP_CURVE 0.5


//#define WATER_REFLECTIONS
uniform int isEyeInWater;

//don't touch these lines if you don't know what you do!
const float stp = 0.5;			//size of one step for raytracing algorithm
const float ref = 0.1;			//refinement multiplier
const float inc = 2.0;			//increasement factor at each step
const int maxf = 5;				//number of refinements



// DOF Constants - DO NOT CHANGE
// HYPERFOCAL = (Focal Distance ^ 2)/(Circle of Confusion * F Stop) + Focal Distance
#ifdef USE_DOF
const float HYPERFOCAL = 3.132;
const float PICONSTANT = 3.14159;
#endif





uniform sampler2D depthtex0;
uniform sampler2D gnormal;
uniform sampler2D gaux2;
uniform sampler2D composite;


uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform vec3 sunPosition;

uniform ivec2 eyeBrightness;

uniform int worldTime;
uniform float aspectRatio;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;

varying vec4 texcoord;
varying vec3 sunlight;



//Raining
float rainx = clamp(rainStrength, 0.0f, 1.0f)/1.0f;
float wetx  = clamp(wetness, 0.0f, 1.0f);


float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;
// Standard depth function.
float getDepth(float depth) {
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
}
float eDepth(vec2 coord) {
	return texture2D(depthtex0, coord).x;
}
float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}
float luma(vec3 color) {
return dot(color,vec3(0.299, 0.587, 0.114));
}


vec3 convertScreenSpaceToWorldSpace(vec2 co, float depth) {
    vec4 fragposition = gbufferProjectionInverse * vec4(vec3(co, depth) * 2.0 - 1.0, 1.0);
    fragposition /= fragposition.w;
    return fragposition.xyz;
}

vec3 convertCameraSpaceToScreenSpace(vec3 cameraSpace) {
    vec4 clipSpace = gbufferProjection * vec4(cameraSpace, 1.0);
    vec3 NDCSpace = clipSpace.xyz / clipSpace.w;
    vec3 screenSpace = 0.5 * NDCSpace + 0.5;
    return screenSpace;
}

float depth = texture2D(depthtex0,texcoord.xy).x;
//Calculate Time of Day

	float timefract = worldTime;

	float TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 4000.0)/4000.0));
	float TimeNoon     = ((clamp(timefract, 0.0, 4000.0)) / 4000.0) - ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0);
	float TimeSunset   = ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
	float TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);

	#ifdef BLOOM
vec2 offsets[16] = vec2[16] (vec2(0.008,0.0), vec2(0.006,0.0), vec2(0.004,0.0), vec2(0.002,0.0),
							 vec2(0.0,0.008), vec2(0.0,0.006), vec2(0.0,0.004), vec2(0.0,0.002),
							 -vec2(0.008,0.0), -vec2(0.006,0.0), -vec2(0.004,0.0), -vec2(0.002,0.0),
							 -vec2(0.0,0.008), -vec2(0.0,0.006), -vec2(0.0,0.004), -vec2(0.0,0.002)
							 );
#endif
/*
vec3 nvec3(vec4 pos){
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos){
    return vec4(pos.xyz, 1.0);
}

float cdist(vec2 coord){
    return distance(coord,vec2(0.5))*2.0;
}

vec4 raytrace(vec3 fragpos, vec3 normal){
    vec4 color = vec4(0.0);
    vec3 start = nvec3(gbufferProjection * nvec4(fragpos)) * 0.5 + 0.5;
    vec3 rvector = normalize(reflect(normalize(fragpos), normalize(normal)));
    vec3 vector = stp * rvector;
    vec3 oldpos = fragpos;
    fragpos += vector;
    int sr = 0;
    for(int i=0;i<300;i++){
        vec3 pos = nvec3(gbufferProjection * nvec4(fragpos)) * 0.5 + 0.5;
        if(pos.x < 0 || pos.x > 1 || pos.y < 0 || pos.y > 1 || pos.z < 0 || pos.z > 1.0) break;
        vec3 spos = vec3(pos.st, texture2D(depthtex0, pos.st).r);
        spos = nvec3(gbufferProjectionInverse * nvec4(spos * 2.0 - 1.0));
        float err = length(vector)*inc-distance(fragpos, spos);
        if(err > 0){
		if(texture2D(gaux2,pos.st).g < 0.01) {
                sr++;
                if(sr >= maxf){
                    float border = clamp(1.0 - pow(cdist(pos.st), 1.5), 0.0, 1.0);
                    color = texture2D(composite, pos.st);
					color.a = 1.0;
                    color.a *= border;
                    break;
                }
                fragpos = oldpos;
                vector *=ref;
				
        }
}
        vector *= inc;
        oldpos = fragpos;
        fragpos += vector;
		
    }
    return color;
}
*/
vec3 sunPos = sunPosition;
#ifdef GODRAYS





	float addGodRays(vec2 lightPos, in float nc, in vec2 tx, in float noise, in float noise2, in float noise3, in float noise4, in float noise5, in float noise6, in float noise7, in float noise8, in float noise9) {
			float GDTimeMult = 0.0f;
			if (sunPos.z > 0.0f) {
				sunPos.z = -sunPos.z;
				sunPos.x = -sunPos.x;
				sunPos.y = -sunPos.y;
				GDTimeMult = TimeMidnight;	
			} else {
				GDTimeMult = TimeSunrise + TimeNoon + TimeSunset;
			}
			//vec2 coord = tx;
			vec2 delta = (tx - lightPos) * GODRAYS_DENSITY / float(2.0);
			delta *= -sunPos.z*0.01f;
			//delta *= -sunPos.z*0.01;
			float decay = -sunPos.z / 100.0f;
				 // decay *= -sunPos.z*0.01;
			float colorGD = 0.0f;
			
			for (int i = 0; i<2;i+=1) {
			
				
			
				
				float sample = 0.0f;

					sample = texture2D(gaux2, clamp(tx + delta*noise,0.000001,0.999999)).b;
					sample += texture2D(gaux2, clamp(tx + delta*noise2,0.000001,0.999999)).b;
					sample += texture2D(gaux2, clamp(tx + delta*noise3,0.000001,0.999999)).b;
					sample += texture2D(gaux2, clamp(tx + delta*noise4,0.000001,0.999999)).b;
					sample *= decay;

					colorGD += sample;
					decay *= GODRAYS_DECAY;
					tx -= delta;
			
			
}
			return (nc + GODRAYS_EXPOSURE * (colorGD))*GDTimeMult;
	}
#endif 
/*
vec4 ComputeReflection(vec3 delta) {
    float stochasticAmount = 0.0f;
    float initialStepAmount = 1.04;
    float stepRefinementAmount = .5;
    int maxRefinements = 3;
    
    vec2 screenSpacePosition2D = texcoord.st;
    vec3 cameraSpacePosition = convertScreenSpaceToWorldSpace(screenSpacePosition2D);
    
    vec3 cameraSpaceNormal = texture2D(gnormal, screenSpacePosition2D).rgb * 2.0f - 1.0f + delta;
    vec3 cameraSpaceViewDir = cameraSpacePosition;
    vec3 cameraSpaceVector = initialStepAmount * normalize(reflect(cameraSpaceViewDir,cameraSpaceNormal));
    vec3 oldPosition = cameraSpacePosition;
    vec3 cameraSpaceVectorPosition = oldPosition + cameraSpaceVector;
    vec3 currentPosition = convertCameraSpaceToScreenSpace(cameraSpaceVectorPosition);
    vec4 color = vec4(texture2D(gaux3,texcoord.xy).rgb,0.0);
    int numRefinements = 0;
    int count = 0;
    //int outed = 0;


    vec2 finalSamplePos = vec2(-0.1f);
    
    while(count < far/initialStepAmount*RANGE)
    {
        if(currentPosition.x < 0 || currentPosition.x > 1 ||
           currentPosition.y < 0 || currentPosition.y > 1 ||
           currentPosition.z < 0 || currentPosition.z > 1.0001) break;
        vec2 samplePos = currentPosition.xy;
        vec3 samplyPos = convertScreenSpaceToWorldSpace(samplePos);
        float currentDepth = cameraSpaceVectorPosition.z;
        float diff = samplyPos.z - currentDepth;
        float error = length(cameraSpaceVector);
        if((diff >= 0 && distance(samplyPos, cameraSpaceVectorPosition) <= error*1.1)) {
            //outed++;
            cameraSpaceVector *= stepRefinementAmount;
            cameraSpaceVectorPosition = oldPosition;
            numRefinements++;
            if(diff >= 0) finalSamplePos = samplePos;
			if(numRefinements == maxRefinements){
            break;
        }
        } 
        
        cameraSpaceVector *= 1.1;    //Each step gets bigger
        oldPosition = cameraSpaceVectorPosition;
        cameraSpaceVectorPosition += cameraSpaceVector;
        currentPosition = convertCameraSpaceToScreenSpace(cameraSpaceVectorPosition);
        count++;
    }
    if(finalSamplePos.x >= 0.0){
        color = texture2D(gaux3, finalSamplePos);
        color.a *= clamp(1 - pow(distance(vec2(0.5), finalSamplePos)*2.0, 4.0), 0.0, 1.0);
    }
    return color;
}
*/
// Main --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
void main() {

	vec3 color = texture2D(composite, texcoord.st).rgb;
	float land = texture2D(composite, texcoord.st).a;
	
    vec3 cameraSpacePosition = convertScreenSpaceToWorldSpace(texcoord.xy,depth);
	
//Common variables

	
	vec2 Texcoord2 = texcoord.st;
	float linDepth = getDepth(depth);

const float noiseamp = 5.5f;



						const float width3 = 2.0f;
						const float height3 = 2.0f;
						float noiseX3 = ((fract(1.0f-Texcoord2.s*(width3/2.0f))*0.25f)+(fract(Texcoord2.t*(height3/2.0f))*0.75f))*2.0f-1.0f;

						
							noiseX3 = clamp(fract(sin(dot(Texcoord2 ,vec2(18.9898f,28.633f))) * 4378.5453f),0.0f,1.0f)*2.0f-1.0f;
						
						noiseX3 *= (0.10f*noiseamp);

						const float width2 = 1.0f;
						const float height2 = 1.0f;
						float noiseX2 = ((fract(1.0f-Texcoord2.s*(width2/2.0f))*0.25f)+(fract(Texcoord2.t*(height2/2.0f))*0.75f))*2.0f-1.0f;
						float noiseY2 = ((fract(1.0f-Texcoord2.s*(width2/2.0f))*0.75f)+(fract(Texcoord2.t*(height2/2.0f))*0.25f))*2.0f-1.0f;

						
							noiseX2 = clamp(fract(sin(dot(Texcoord2 ,vec2(12.9898f,78.233f))) * 43758.5453f),0.0f,1.0f)*2.0f-1.0f;
							noiseY2 = clamp(fract(sin(dot(Texcoord2 ,vec2(12.9898f,78.233f)*2.0f)) * 43758.5453f),0.0f,1.0f)*2.0f-1.0f;
						
						noiseX2 *= (0.10f*noiseamp);
						noiseY2 *= (0.10f*noiseamp);
						

						const float width4 = 3.0f;
						const float height4 = 3.0f;
						float noiseX4 = ((fract(1.0f-Texcoord2.s*(width4/2.0f))*0.25f)+(fract(Texcoord2.t*(height4/2.0f))*0.75f))*2.0f-1.0f;
						float noiseY4 = ((fract(1.0f-Texcoord2.s*(width4/2.0f))*0.75f)+(fract(Texcoord2.t*(height4/2.0f))*0.25f))*2.0f-1.0f;

						
							noiseX4 = clamp(fract(sin(dot(Texcoord2 ,vec2(16.9898f,38.633f))) * 41178.5453f),0.0f,1.0f)*2.0f-1.0f;
							noiseY4 = clamp(fract(sin(dot(Texcoord2 ,vec2(21.9898f,66.233f)*2.0f)) * 9758.5453f),0.0f,1.0f)*2.0f-1.0f;
						
						noiseX4 *= (0.10f*noiseamp);
						noiseY4 *= (0.10f*noiseamp);	

						const float width5 = 4.0f;
						const float height5 = 4.0f;
						float noiseX5 = ((fract(1.0f-Texcoord2.s*(width5/2.0f))*0.25f)+(fract(Texcoord2.t*(height5/2.0f))*0.75f))*2.0f-1.0f;
						float noiseY5 = ((fract(1.0f-Texcoord2.s*(width5/2.0f))*0.75f)+(fract(Texcoord2.t*(height5/2.0f))*0.25f))*2.0f-1.0f;

						
							noiseX5 = clamp(fract(sin(dot(Texcoord2 ,vec2(11.9898f,68.633f))) * 21178.5453f),0.0f,1.0f)*2.0f-1.0f;
							noiseY5 = clamp(fract(sin(dot(Texcoord2 ,vec2(26.9898f,71.233f)*2.0f)) * 6958.5453f),0.0f,1.0f)*2.0f-1.0f;
						
						noiseX5 *= (0.10f*noiseamp);
						noiseY5 *= (0.10f*noiseamp);							
						
						const float width6 = 4.0f;
						const float height6 = 4.0f;
						float noiseX6 = ((fract(1.0f-Texcoord2.s*(width6/2.0f))*0.25f)+(fract(Texcoord2.t*(height6/2.0f))*0.75f))*2.0f-1.0f;
						float noiseY6 = ((fract(1.0f-Texcoord2.s*(width6/2.0f))*0.75f)+(fract(Texcoord2.t*(height6/2.0f))*0.25f))*2.0f-1.0f;

						
							noiseX6 = clamp(fract(sin(dot(Texcoord2 ,vec2(21.9898f,78.633f))) * 29178.5453f),0.0f,1.0f)*2.0f-1.0f;
							noiseY6 = clamp(fract(sin(dot(Texcoord2 ,vec2(36.9898f,81.233f)*2.0f)) * 16958.5453f),0.0f,1.0f)*2.0f-1.0f;
						
						noiseX6 *= (0.10f*noiseamp);
						noiseY6 *= (0.10f*noiseamp);						
					
						float width7 = 6.0;
						float height7 = 6.0;
						float noiseX7 = ((fract(1.0-Texcoord2.s*(width7/2.0))*0.25)+(fract(Texcoord2.t*(height7/2.0))*0.75))*2.0-1.0;
						float noiseY7 = ((fract(1.0-Texcoord2.s*(width7/2.0))*0.75)+(fract(Texcoord2.t*(height7/2.0))*0.25))*2.0-1.0;

						
							noiseX7 = clamp(fract(sin(dot(Texcoord2 ,vec2(12.9898,44.633))) * 51178.5453),0.0,1.0)*2.0-1.0;
							noiseY7 = clamp(fract(sin(dot(Texcoord2 ,vec2(43.9898,61.233)*2.0)) * 9958.5453),0.0,1.0)*2.0-1.0;
						
						noiseX7 *= (0.10f*noiseamp);
						noiseY7 *= (0.10f*noiseamp);
						
						float width8 = 7.0;
						float height8 = 7.0;
						float noiseX8 = ((fract(1.0-Texcoord2.s*(width8/2.0))*0.25)+(fract(Texcoord2.t*(height8/2.0))*0.75))*2.0-1.0;
						float noiseY8 = ((fract(1.0-Texcoord2.s*(width8/2.0))*0.75)+(fract(Texcoord2.t*(height8/2.0))*0.25))*2.0-1.0;

						
							noiseX8 = clamp(fract(sin(dot(Texcoord2 ,vec2(14.9898,47.633))) * 51468.5453),0.0,1.0)*2.0-1.0;
							noiseY8 = clamp(fract(sin(dot(Texcoord2 ,vec2(13.9898,81.233)*2.0)) * 6388.5453),0.0,1.0)*2.0-1.0;
						
						noiseX8 *= (0.10f*noiseamp);
						noiseY8 *= (0.10f*noiseamp);
						
						float width9 = 8.0;
						float height9 = 8.0;
						float noiseX9 = ((fract(1.0-Texcoord2.s*(width9/2.0))*0.25)+(fract(Texcoord2.t*(height9/2.0))*0.75))*2.0-1.0;
						float noiseY9 = ((fract(1.0-Texcoord2.s*(width9/2.0))*0.75)+(fract(Texcoord2.t*(height9/2.0))*0.25))*2.0-1.0;

						
							noiseX9 = clamp(fract(sin(dot(Texcoord2 ,vec2(24.9898,59.633))) * 55468.5453),0.0,1.0)*2.0-1.0;
							noiseY9 = clamp(fract(sin(dot(Texcoord2 ,vec2(23.9898,95.233)*2.0)) * 16388.5453),0.0,1.0)*2.0-1.0;
						
						noiseX9 *= (0.10f*noiseamp);
						noiseY9 *= (0.10f*noiseamp);
						
						float width10 = 9.0;
						float height10 = 9.0;
						float noiseX10 = ((fract(1.0-Texcoord2.s*(width10/2.0))*0.25)+(fract(Texcoord2.t*(height10/2.0))*0.75))*2.0-1.0;
						float noiseY10 = ((fract(1.0-Texcoord2.s*(width10/2.0))*0.75)+(fract(Texcoord2.t*(height10/2.0))*0.25))*2.0-1.0;

						
							noiseX10 = clamp(fract(sin(dot(Texcoord2 ,vec2(26.9898,59.633))) * 57468.5453),0.0,1.0)*2.0-1.0;
							noiseY10 = clamp(fract(sin(dot(Texcoord2 ,vec2(25.9898,95.233)*2.0)) * 18388.5453),0.0,1.0)*2.0-1.0;
						
						noiseX10 *= (0.10f*noiseamp);
						noiseY10 *= (0.10f*noiseamp);
						
float spec = texture2D(gaux2,texcoord.xy).r;
float wave = texture2D(gaux2,texcoord.xy).g;


/*

float iswater = 0.0;
if (wave > 0.0) {
iswater = 1.0;
wave = (wave-0.02)*2.0-1.0;
}

    vec3 fragpos = vec3(texcoord.st, texture2D(depthtex0, texcoord.st).r);
    fragpos = nvec3(gbufferProjectionInverse * nvec4(fragpos * 2.0 - 1.0));
    vec3 normal = texture2D(gnormal, texcoord.st).rgb * 2.0 - 1.0;
			color.rgb *= mix(vec3(1.0),vec3(0.3,0.4,0.6),isEyeInWater);
    if (iswater > 0.9) {
#ifdef WATER_REFLECTIONS
            vec4 reflection = raytrace(fragpos, normalize(normal+wave*0.02));
			float normalDotEye = dot(normalize(normal+wave*0.15), -normalize(fragpos));
			float fresnel = 1.0 - normalDotEye;

            color.rgb = mix(color.rgb, reflection.rgb, fresnel*reflection.a * (vec3(1.0) - color.rgb) * (1.0-isEyeInWater));
#endif
    		color.rgb += spec*sunlight*(1.0-isEyeInWater);
    }
	*/
/*
#ifdef DOF
float focal = ld(texture2D(depthtex0,vec2(0.5)).x);
float ddiff;
float mult = 1.0;
vec3 bcolor = vec3(0.0);
vec2 samplecoord;
bcolor = color.rgb;
for (int i = -3; i < 4; i++) {
	for (int j = -3; j < 4; j++) {
	samplecoord = vec2(pw*i*2.0f,pw*cos(j/3.0f)*6.0f);
	ddiff = ld(texture2D(depthtex0, texcoord.xy + samplecoord).x);
	if (ddiff - ld(depth) < 0.0) {
	ddiff -= -focal;
	bcolor += texture2D(gaux3,texcoord.xy + samplecoord).rgb*ddiff;
	mult += ddiff;
	}
	}
}
color.rgb = bcolor/mult;
#endif
*/

#ifdef BLOOM
float sweight = length(color)+(1.0-rainx)*0.2;
//exclude bright pixels
if (sweight < 0.7) {
vec3 csample = vec3(0.0);
for (int i=0; i < 16; i++) {
csample += max(texture2D(gaux3,texcoord.xy + offsets[i]*1.2).rgb-sweight,0.0);
}
color += csample/30.0;
}

#endif
vec4 tpos = vec4(sunPos,1.0)*gbufferProjection;
			tpos = vec4(tpos.xyz/tpos.w,1.0);
			vec2 lightPos = tpos.xy/tpos.z;
			lightPos = (lightPos + 1.0f)/2.0f;
			
			float distof = min(min(1.0-lightPos.x,lightPos.x),min(1.0-lightPos.y,lightPos.y));
			float fading = clamp(1.0-step(distof,0.1)+pow(distof*10.0,5.0),0.0,1.0);
#ifdef GODRAYS
			
			if (fading > 0.01) {
			
	float GR = addGodRays(lightPos,0.0f, Texcoord2, noiseX3, noiseX4, noiseY4, noiseX2, noiseY2, noiseX5, noiseY5, noiseX6, noiseY6)/2.0;

	
	GR = pow(GR, 1.0f)*2.5f;
	
	color += GR*sunlight*fading;
}
	
#endif

#ifdef LENS

vec3 sP = sunPosition;

			vec2 lPos = lightPos;

			if (fading > 0.01 && TimeMidnight < 1.0) {

			
			float sunmask = 0.0f;
			float sunstep = -4.5f;
			float masksize = 0.004f;
					
/*
					for (int a = 0; a < 16; a++) {
							sunmask += 1.0f - texture2D(gaux3, lPos + offsets[a]*4.0).a;
						}
						sunmask /= 16.0;
*/
sunmask = texture2D(gaux2,vec2(0.0)).a;
					sunmask *= LENS_POWER * (1.0f - TimeMidnight)*fading;
					sunmask *= 1.0 - rainx;
			if (sunmask > 0.02) {
			//Detect if sun is on edge of screen
				float edgemaskx = clamp(distance(lPos.x, 0.5f)*8.0f - 3.0f, 0.0f, 1.0f);
				float edgemasky = clamp(distance(lPos.y, 0.5f)*8.0f - 3.0f, 0.0f, 1.0f);
			
						
						
			////Darken colors if the sun is visible
				float centermask = 1.0 - clamp(distance(lPos.xy, vec2(0.5f, 0.5f))*2.0, 0.0, 1.0);
						centermask = pow(centermask, 1.0f);
						centermask *= sunmask;
			
				color *= (1.0 - centermask * (1.0f - TimeMidnight));
			
			
			//Adjust global flare settings
				const float flaremultR = 0.8f;
				const float flaremultG = 1.0f;
				const float flaremultB = 1.5f;
			
				float flarescale = 1.0f;
				const float flarescaleconst = 1.0f;
			
			
			//Flare gets bigger at center of screen
			
				flarescale *= (1.0 - centermask);
			
			
			//Center white flare
			vec2 flare1scale = vec2(1.7f*flarescale, 1.7f*flarescale);
			float flare1pow = 12.0f;
			vec2 flare1pos = vec2(lPos.x*aspectRatio*flare1scale.x, lPos.y*flare1scale.y);
			
			
			float flare1 = distance(flare1pos, vec2(texcoord.s*aspectRatio*flare1scale.x, texcoord.t*flare1scale.y));
				  flare1 = 0.5 - flare1;
				  flare1 = clamp(flare1, 0.0, 10.0) * clamp(-sP.z, 0.0, 1.0);
				  flare1 *= sunmask;
				  flare1 = pow(flare1, 1.8f);
				  
				  flare1 *= flare1pow;
				  
				  	color.r += flare1*0.7f*flaremultR;
					color.g += flare1*0.4f*flaremultG;
					color.b += flare1*0.2f*flaremultB;	
				  			
							
							
			//Center white flare
			  vec2 flare1Bscale = vec2(0.5f*flarescale, 0.5f*flarescale);
			  float flare1Bpow = 6.0f;
			vec2 flare1Bpos = vec2(lPos.x*aspectRatio*flare1Bscale.x, lPos.y*flare1Bscale.y);
			
			
			float flare1B = distance(flare1Bpos, vec2(texcoord.s*aspectRatio*flare1Bscale.x, texcoord.t*flare1Bscale.y));
				  flare1B = 0.5 - flare1B;
				  flare1B = clamp(flare1B, 0.0, 10.0) * clamp(-sP.z, 0.0, 1.0);
				  flare1B *= sunmask;
				  flare1B = pow(flare1B, 1.8f);
				  
				  flare1B *= flare1Bpow;
				  
				  	color.r += flare1B*0.7f*flaremultR;
					color.g += flare1B*0.2f*flaremultG;
					color.b += flare1B*0.0f*flaremultB;	
				  
				  
					
					
					
			//Far blue flare MAIN
			  vec2 flare3scale = vec2(2.0f*flarescale, 2.0f*flarescale);
			  float flare3pow = 0.7f;
			  float flare3fill = 10.0f;
			  float flare3offset = -0.5f;
			vec2 flare3pos = vec2(  ((1.0 - lPos.x)*(flare3offset + 1.0) - (flare3offset*0.5))  *aspectRatio*flare3scale.x,  ((1.0 - lPos.y)*(flare3offset + 1.0) - (flare3offset*0.5))  *flare3scale.y);
			
			
			float flare3 = distance(flare3pos, vec2(texcoord.s*aspectRatio*flare3scale.x, texcoord.t*flare3scale.y));
				  flare3 = 0.5 - flare3;
				  flare3 = clamp(flare3*flare3fill, 0.0, 1.0) * clamp(-sP.z, 0.0, 1.0);
				  flare3 = sin(flare3*1.57075);
				  flare3 *= sunmask;
				  flare3 = pow(flare3, 1.1f);
				  
				  flare3 *= flare3pow;			
				  
				  
				  //subtract from blue flare
				  vec2 flare3Bscale = vec2(1.4f*flarescale, 1.4f*flarescale);
				  float flare3Bpow = 1.0f;
				  float flare3Bfill = 2.0f;
				  float flare3Boffset = -0.65f;
				vec2 flare3Bpos = vec2(  ((1.0 - lPos.x)*(flare3Boffset + 1.0) - (flare3Boffset*0.5))  *aspectRatio*flare3Bscale.x,  ((1.0 - lPos.y)*(flare3Boffset + 1.0) - (flare3Boffset*0.5))  *flare3Bscale.y);
			
			
				float flare3B = distance(flare3Bpos, vec2(texcoord.s*aspectRatio*flare3Bscale.x, texcoord.t*flare3Bscale.y));
					flare3B = 0.5 - flare3B;
					flare3B = clamp(flare3B*flare3Bfill, 0.0, 1.0) * clamp(-sP.z, 0.0, 1.0);
					flare3B = sin(flare3B*1.57075);
					flare3B *= sunmask;
					flare3B = pow(flare3B, 0.9f);
				  
					flare3B *= flare3Bpow;
				  
				flare3 = clamp(flare3 - flare3B, 0.0, 10.0);
				  
				  
				  	color.r += flare3*0.0f*flaremultR;
					color.g += flare3*0.3f*flaremultG;
					color.b += flare3*1.0f*flaremultB;

					
					
					
			//Far blue flare MAIN 2
			  vec2 flare3Cscale = vec2(3.2f*flarescale, 3.2f*flarescale);
			  float flare3Cpow = 1.4f;
			  float flare3Cfill = 10.0f;
			  float flare3Coffset = -0.0f;
			vec2 flare3Cpos = vec2(  ((1.0 - lPos.x)*(flare3Coffset + 1.0) - (flare3Coffset*0.5))  *aspectRatio*flare3Cscale.x,  ((1.0 - lPos.y)*(flare3Coffset + 1.0) - (flare3Coffset*0.5))  *flare3Cscale.y);
			
			
			float flare3C = distance(flare3Cpos, vec2(texcoord.s*aspectRatio*flare3Cscale.x, texcoord.t*flare3Cscale.y));
				  flare3C = 0.5 - flare3C;
				  flare3C = clamp(flare3C*flare3Cfill, 0.0, 1.0) * clamp(-sP.z, 0.0, 1.0);
				  flare3C = sin(flare3C*1.57075);
				  
				  flare3C = pow(flare3C, 1.1f);
				  
				  flare3C *= flare3Cpow;			
				  
				  
				  //subtract from blue flare
				  vec2 flare3Dscale = vec2(2.1f*flarescale, 2.1f*flarescale);
				  float flare3Dpow = 2.7f;
				  float flare3Dfill = 1.4f;
				  float flare3Doffset = -0.05f;
				vec2 flare3Dpos = vec2(  ((1.0 - lPos.x)*(flare3Doffset + 1.0) - (flare3Doffset*0.5))  *aspectRatio*flare3Dscale.x,  ((1.0 - lPos.y)*(flare3Doffset + 1.0) - (flare3Doffset*0.5))  *flare3Dscale.y);
			
			
				float flare3D = distance(flare3Dpos, vec2(texcoord.s*aspectRatio*flare3Dscale.x, texcoord.t*flare3Dscale.y));
					flare3D = 0.5 - flare3D;
					flare3D = clamp(flare3D*flare3Dfill, 0.0, 1.0) * clamp(-sP.z, 0.0, 1.0);
					flare3D = sin(flare3D*1.57075);
					flare3D = pow(flare3D, 0.9f);
				  
					flare3D *= flare3Dpow;
				  
				flare3C = clamp(flare3C - flare3D, 0.0, 10.0);
				flare3C *= sunmask;
				  
				  	color.r += flare3C*0.4f*flaremultR;
					color.g += flare3C*0.7f*flaremultG;
					color.b += flare3C*1.0f*flaremultB;							
					
					
					
					
					
					
					
					
					
			//far small pink flare
			  vec2 flare4scale = vec2(4.5f*flarescale, 4.5f*flarescale);
			  float flare4pow = 0.3f;
			  float flare4fill = 3.0f;
			  float flare4offset = -0.1f;
			vec2 flare4pos = vec2(  ((1.0 - lPos.x)*(flare4offset + 1.0) - (flare4offset*0.5))  *aspectRatio*flare4scale.x,  ((1.0 - lPos.y)*(flare4offset + 1.0) - (flare4offset*0.5))  *flare4scale.y);
			
			
			float flare4 = distance(flare4pos, vec2(texcoord.s*aspectRatio*flare4scale.x, texcoord.t*flare4scale.y));
				  flare4 = 0.5 - flare4;
				  flare4 = clamp(flare4*flare4fill, 0.0, 1.0) * clamp(-sP.z, 0.0, 1.0);
				  flare4 = sin(flare4*1.57075);
				  flare4 *= sunmask;
				  flare4 = pow(flare4, 1.1f);
				  
				  flare4 *= flare4pow;
				  
				  	color.r += flare4*0.6f*flaremultR;
					color.g += flare4*0.0f*flaremultG;
					color.b += flare4*0.8f*flaremultB;							
					
					
					
			//far small pink flare2
			  vec2 flare4Bscale = vec2(7.5f*flarescale, 7.5f*flarescale);
			  float flare4Bpow = 0.4f;
			  float flare4Bfill = 2.0f;
			  float flare4Boffset = 0.0f;
			vec2 flare4Bpos = vec2(  ((1.0 - lPos.x)*(flare4Boffset + 1.0) - (flare4Boffset*0.5))  *aspectRatio*flare4Bscale.x,  ((1.0 - lPos.y)*(flare4Boffset + 1.0) - (flare4Boffset*0.5))  *flare4Bscale.y);
			
			
			float flare4B = distance(flare4Bpos, vec2(texcoord.s*aspectRatio*flare4Bscale.x, texcoord.t*flare4Bscale.y));
				  flare4B = 0.5 - flare4B;
				  flare4B = clamp(flare4B*flare4Bfill, 0.0, 1.0) * clamp(-sP.z, 0.0, 1.0);
				  flare4B = sin(flare4B*1.57075);
				  flare4B *= sunmask;
				  flare4B = pow(flare4B, 1.1f);
				  
				  flare4B *= flare4Bpow;
				  
				  	color.r += flare4B*0.4f*flaremultR;
					color.g += flare4B*0.0f*flaremultG;
					color.b += flare4B*0.8f*flaremultB;						
					
					
					
			//far small pink flare3
			  vec2 flare4Cscale = vec2(37.5f*flarescale, 37.5f*flarescale);
			  float flare4Cpow = 2.0f;
			  float flare4Cfill = 2.0f;
			  float flare4Coffset = -0.3f;
			vec2 flare4Cpos = vec2(  ((1.0 - lPos.x)*(flare4Coffset + 1.0) - (flare4Coffset*0.5))  *aspectRatio*flare4Cscale.x,  ((1.0 - lPos.y)*(flare4Coffset + 1.0) - (flare4Coffset*0.5))  *flare4Cscale.y);
			
			
			float flare4C = distance(flare4Cpos, vec2(texcoord.s*aspectRatio*flare4Cscale.x, texcoord.t*flare4Cscale.y));
				  flare4C = 0.5 - flare4C;
				  flare4C = clamp(flare4C*flare4Cfill, 0.0, 1.0) * clamp(-sP.z, 0.0, 1.0);
				  flare4C = sin(flare4C*1.57075);
				  flare4C *= sunmask;
				  flare4C = pow(flare4C, 1.1f);
				  
				  flare4C *= flare4Cpow;
				  
				  	color.r += flare4C*0.2f*flaremultR;
					color.g += flare4C*0.6f*flaremultG;
					color.b += flare4C*0.8f*flaremultB;						
					
					
					
			//far small pink flare4
			  vec2 flare4Dscale = vec2(67.5f*flarescale, 67.5f*flarescale);
			  float flare4Dpow = 1.0f;
			  float flare4Dfill = 2.0f;
			  float flare4Doffset = -0.35f;
			vec2 flare4Dpos = vec2(  ((1.0 - lPos.x)*(flare4Doffset + 1.0) - (flare4Doffset*0.5))  *aspectRatio*flare4Dscale.x,  ((1.0 - lPos.y)*(flare4Doffset + 1.0) - (flare4Doffset*0.5))  *flare4Dscale.y);
			
			
			float flare4D = distance(flare4Dpos, vec2(texcoord.s*aspectRatio*flare4Dscale.x, texcoord.t*flare4Dscale.y));
				  flare4D = 0.5 - flare4D;
				  flare4D = clamp(flare4D*flare4Dfill, 0.0, 1.0) * clamp(-sP.z, 0.0, 1.0);
				  flare4D = sin(flare4D*1.57075);
				  flare4D *= sunmask;
				  flare4D = pow(flare4D, 1.1f);
				  
				  flare4D *= flare4Dpow;
				  
				  	color.r += flare4D*0.2f*flaremultR;
					color.g += flare4D*0.2f*flaremultG;
					color.b += flare4D*0.8f*flaremultB;						
					
					
								
			//far small pink flare5
			  vec2 flare4Escale = vec2(60.5f*flarescale, 60.5f*flarescale);
			  float flare4Epow = 1.0f;
			  float flare4Efill = 3.0f;
			  float flare4Eoffset = -0.3393f;
			vec2 flare4Epos = vec2(  ((1.0 - lPos.x)*(flare4Eoffset + 1.0) - (flare4Eoffset*0.5))  *aspectRatio*flare4Escale.x,  ((1.0 - lPos.y)*(flare4Eoffset + 1.0) - (flare4Eoffset*0.5))  *flare4Escale.y);
			
			
			float flare4E = distance(flare4Epos, vec2(texcoord.s*aspectRatio*flare4Escale.x, texcoord.t*flare4Escale.y));
				  flare4E = 0.5 - flare4E;
				  flare4E = clamp(flare4E*flare4Efill, 0.0, 1.0) * clamp(-sP.z, 0.0, 1.0);
				  flare4E = sin(flare4E*1.57075);
				  flare4E *= sunmask;
				  flare4E = pow(flare4E, 1.1f);
				  
				  flare4E *= flare4Epow;
				  
				  	color.r += flare4E*0.2f*flaremultR;
					color.g += flare4E*0.2f*flaremultG;
					color.b += flare4E*0.6f*flaremultB;					
					
								
								
			//far small pink flare5
			  vec2 flare4Fscale = vec2(20.5f*flarescale, 20.5f*flarescale);
			  float flare4Fpow = 3.0f;
			  float flare4Ffill = 3.0f;
			  float flare4Foffset = -0.4713f;
			vec2 flare4Fpos = vec2(  ((1.0 - lPos.x)*(flare4Foffset + 1.0) - (flare4Foffset*0.5))  *aspectRatio*flare4Fscale.x,  ((1.0 - lPos.y)*(flare4Foffset + 1.0) - (flare4Foffset*0.5))  *flare4Fscale.y);
			
			
			float flare4F = distance(flare4Fpos, vec2(texcoord.s*aspectRatio*flare4Fscale.x, texcoord.t*flare4Fscale.y));
				  flare4F = 0.5 - flare4F;
				  flare4F = clamp(flare4F*flare4Ffill, 0.0, 1.0) * clamp(-sP.z, 0.0, 1.0);
				  flare4F = sin(flare4F*1.57075);
				  flare4F *= sunmask;
				  flare4F = pow(flare4F, 1.1f);
				  
				  flare4F *= flare4Fpow;
				  
				  	color.r += flare4F*0.6f*flaremultR;
					color.g += flare4F*0.1f*flaremultG;
					color.b += flare4F*0.1f*flaremultB;						
					
					
					
					
					
					
					
					
					
					
					
					
			//
			  vec2 flare5scale = vec2(3.2f*flarescale , 3.2f*flarescale );
			  float flare5pow = 13.4f;
			  float flare5fill = 1.0f;
			  float flare5offset = -2.0f;
			vec2 flare5pos = vec2(  ((1.0 - lPos.x)*(flare5offset + 1.0) - (flare5offset*0.5))  *aspectRatio*flare5scale.x,  ((1.0 - lPos.y)*(flare5offset + 1.0) - (flare5offset*0.5))  *flare5scale.y);
			
			
			float flare5 = distance(flare5pos, vec2(texcoord.s*aspectRatio*flare5scale.x, texcoord.t*flare5scale.y));
				  flare5 = 0.5 - flare5;
				  flare5 = clamp(flare5*flare5fill, 0.0, 1.0) * clamp(-sP.z, 0.0, 1.0);
				  flare5 *= sunmask;
				  flare5 = pow(flare5, 1.9f);
				  
				  flare5 *= flare5pow;
				  
				  	color.r += flare5*0.9f*flaremultR;
					color.g += flare5*0.4f*flaremultG;
					color.b += flare5*0.3f*flaremultB;						
					
					
					
					
					
			//close ring flare red
			  vec2 flare6scale = vec2(1.2f*flarescale, 1.2f*flarescale);
			  float flare6pow = 0.2f;
			  float flare6fill = 5.0f;
			  float flare6offset = -1.9f;
			vec2 flare6pos = vec2(  ((1.0 - lPos.x)*(flare6offset + 1.0) - (flare6offset*0.5))  *aspectRatio*flare6scale.x,  ((1.0 - lPos.y)*(flare6offset + 1.0) - (flare6offset*0.5))  *flare6scale.y);
			
			
			float flare6 = distance(flare6pos, vec2(texcoord.s*aspectRatio*flare6scale.x, texcoord.t*flare6scale.y));
				  flare6 = 0.5 - flare6;
				  flare6 = clamp(flare6*flare6fill, 0.0, 1.0) * clamp(-sP.z, 0.0, 1.0);
				  flare6 = pow(flare6, 1.6f);
				  flare6 = sin(flare6*3.1415);
				  flare6 *= sunmask;

				  
				  flare6 *= flare6pow;
				  
				  	color.r += flare6*0.6f*flaremultR;
					color.g += flare6*0.0f*flaremultG;
					color.b += flare6*0.0f*flaremultB;						
					
					
					
			//close ring flare green
			  vec2 flare6Bscale = vec2(1.1f*flarescale, 1.1f*flarescale);
			  float flare6Bpow = 0.2f;
			  float flare6Bfill = 5.0f;
			  float flare6Boffset = -1.9f;
			vec2 flare6Bpos = vec2(  ((1.0 - lPos.x)*(flare6Boffset + 1.0) - (flare6Boffset*0.5))  *aspectRatio*flare6Bscale.x,  ((1.0 - lPos.y)*(flare6Boffset + 1.0) - (flare6Boffset*0.5))  *flare6Bscale.y);
			
			
			float flare6B = distance(flare6Bpos, vec2(texcoord.s*aspectRatio*flare6Bscale.x, texcoord.t*flare6Bscale.y));
				  flare6B = 0.5 - flare6B;
				  flare6B = clamp(flare6B*flare6Bfill, 0.0, 1.0) * clamp(-sP.z, 0.0, 1.0);
				  flare6B = pow(flare6B, 1.6f);
				  flare6B = sin(flare6B*3.1415);
				  flare6B *= sunmask;

				  
				  flare6B *= flare6Bpow;
				  
				  	color.r += flare6B*0.0f*flaremultR;
					color.g += flare6B*0.4f*flaremultG;
					color.b += flare6B*0.0f*flaremultB;						
					
					
			
			//close ring flare blue
			  vec2 flare6Cscale = vec2(0.9f*flarescale, 0.9f*flarescale);
			  float flare6Cpow = 0.2f;
			  float flare6Cfill = 5.0f;
			  float flare6Coffset = -1.9f;
			vec2 flare6Cpos = vec2(  ((1.0 - lPos.x)*(flare6Coffset + 1.0) - (flare6Coffset*0.5))  *aspectRatio*flare6Cscale.x,  ((1.0 - lPos.y)*(flare6Coffset + 1.0) - (flare6Coffset*0.5))  *flare6Cscale.y);
			
			
			float flare6C = distance(flare6Cpos, vec2(texcoord.s*aspectRatio*flare6Cscale.x, texcoord.t*flare6Cscale.y));
				  flare6C = 0.5 - flare6C;
				  flare6C = clamp(flare6C*flare6Cfill, 0.0, 1.0) * clamp(-sP.z, 0.0, 1.0);
				  flare6C = pow(flare6C, 1.8f);
				  flare6C = sin(flare6C*3.1415);
				  flare6C *= sunmask;

				  
				  flare6C *= flare6Cpow;
				  
				  	color.r += flare6C*0.0f*flaremultR;
					color.g += flare6C*0.0f*flaremultG;
					color.b += flare6C*0.4f*flaremultB;						
					
					
					
					
			//far red ring

			  vec2 flare7scale = vec2(0.4f*flarescale, 0.4f*flarescale);
			  float flare7pow = 0.2f;
			  float flare7fill = 10.0f;
			  float flare7offset = 2.6f;
			vec2 flare7pos = vec2(  ((1.0 - lPos.x)*(flare7offset + 1.0) - (flare7offset*0.5))  *aspectRatio*flare7scale.x,  ((1.0 - lPos.y)*(flare7offset + 1.0) - (flare7offset*0.5))  *flare7scale.y);
			
			
			float flare7 = distance(flare7pos, vec2(texcoord.s*aspectRatio*flare7scale.x, texcoord.t*flare7scale.y));
				  flare7 = 0.5 - flare7;
				  flare7 = clamp(flare7*flare7fill, 0.0, 1.0) * clamp(-sP.z, 0.0, 1.0);
				  flare7 = pow(flare7, 1.9f);
				  flare7 = sin(flare7*3.1415);
				  flare7 *= sunmask;

				  
				  flare7 *= flare7pow;
				  
				  	color.r += flare7*1.0f*flaremultR;
					color.g += flare7*0.0f*flaremultG;
					color.b += flare7*0.0f*flaremultB;				
					
					
					
			//far blue ring

			  vec2 flare7Dscale = vec2(0.39f*flarescale, 0.39f*flarescale);
			  float flare7Dpow = 0.1f;
			  float flare7Dfill = 10.0f;
			  float flare7Doffset = 2.6f;
			vec2 flare7Dpos = vec2(  ((1.0 - lPos.x)*(flare7Doffset + 1.0) - (flare7Doffset*0.5))  *aspectRatio*flare7Dscale.x,  ((1.0 - lPos.y)*(flare7Doffset + 1.0) - (flare7Doffset*0.5))  *flare7Dscale.y);
			
			
			float flare7D = distance(flare7Dpos, vec2(texcoord.s*aspectRatio*flare7Dscale.x, texcoord.t*flare7Dscale.y));
				  flare7D = 0.5 - flare7D;
				  flare7D = clamp(flare7D*flare7Dfill, 0.0, 1.0) * clamp(-sP.z, 0.0, 1.0);
				  flare7D = pow(flare7D, 1.9f);
				  flare7D = sin(flare7D*3.1415);
				  flare7D *= sunmask;

				  
				  flare7D *= flare7Dpow;
				  
				  	color.r += flare7D*0.0f*flaremultR;
					color.g += flare7D*0.6f*flaremultG;
					color.b += flare7D*0.0f*flaremultB;				
					
					
					
			//far red glow

			  vec2 flare7Bscale = vec2(0.2f*flarescale, 0.2f*flarescale);
			  float flare7Bpow = 0.1f;
			  float flare7Bfill = 2.0f;
			  float flare7Boffset = 2.9f;
			vec2 flare7Bpos = vec2(  ((1.0 - lPos.x)*(flare7Boffset + 1.0) - (flare7Boffset*0.5))  *aspectRatio*flare7Bscale.x,  ((1.0 - lPos.y)*(flare7Boffset + 1.0) - (flare7Boffset*0.5))  *flare7Bscale.y);
			
			
			float flare7B = distance(flare7Bpos, vec2(texcoord.s*aspectRatio*flare7Bscale.x, texcoord.t*flare7Bscale.y));
				  flare7B = 0.5 - flare7B;
				  flare7B = clamp(flare7B*flare7Bfill, 0.0, 1.0) * clamp(-sP.z, 0.0, 1.0);
				  flare7B = pow(flare7B, 1.9f);
				  flare7B = sin(flare7B*3.1415*0.5);
				  flare7B *= sunmask;

				  
				  flare7B *= flare7Bpow;
				  
				  	color.r += flare7B*1.0f*flaremultR;
					color.g += flare7B*0.0f*flaremultG;
					color.b += flare7B*0.0f*flaremultB;	
			
			
			
		
					
					
					
	
					
					
		
		
		
		
		

					
			
			color = clamp(color, 0.0, 4.0);
			}
}

#endif


#ifdef VIGNETTE

float dv = distance(texcoord.st, vec2(0.5, 0.5));

dv *= VIGNETTE_STRENGTH;

dv = 1.0 - dv;

dv = pow(dv, 0.2);

dv *= 1.9;
dv -= 0.9;

color *= dv;
#endif


color = color * BRIGHTMULT;

#ifdef CROSSPROCESS
	//pre-gain
	color = color * (BRIGHTMULT) + 0.03;
	
	//compensate for low-light artifacts
	color = color+0.029;
 
	//calculate double curve
	float dbr = -color.r + 1.4;
	float dbg = -color.g + 1.4;
	float dbb = -color.b + 1.4;
	
	//fade between simple gamma up curve and double curve
	float pr = mix(dbr, 0.65, 0.5);
	float pg = mix(dbg, 0.65, 0.5);
	float pb = mix(dbb, 0.65, 0.5);
	
	color.r = pow((color.r * 0.95 - 0.002), pr);
	color.g = pow((color.g * 0.95 - 0.002), pg);
	color.b = pow((color.b * 0.99 + 0.000), pb);
#endif

	//Color boosting
	color.r = (color.r)*(COLOR_BOOST + 1.0) + (color.g + color.b)*(-COLOR_BOOST);
	color.g = (color.g)*(COLOR_BOOST + 1.0) + (color.r + color.b)*(-COLOR_BOOST);
	color.b = (color.b)*(COLOR_BOOST + 1.0) + (color.r + color.g)*(-COLOR_BOOST);
	
	//color.r = mix(((color.r)*(COLOR_BOOST + 1.0) + (hld.g + hld.b)*(-COLOR_BOOST)), hld.r, (max(((1-rgb)*2 - 1), 0.0)));
	//color.g = mix(((color.g)*(COLOR_BOOST + 1.0) + (hld.r + hld.b)*(-COLOR_BOOST)), hld.g, (max(((1-rgb)*2 - 1), 0.0)));
	//color.b = mix(((color.b)*(COLOR_BOOST + 1.0) + (hld.r + hld.g)*(-COLOR_BOOST)), hld.b, (max(((1-rgb)*2 - 1), 0.0)));

#ifdef HIGHDESATURATE


	//average
	float rgb = max(color.r, max(color.g, color.b))/2 + min(color.r, min(color.g, color.b))/2;

	//adjust black and white image to be brighter
	float bw = pow(rgb, 0.7);

	//mix between per-channel analysis and average analysis
	float rgbr = mix(rgb, color.r, 0.7);
	float rgbg = mix(rgb, color.g, 0.7);
	float rgbb = mix(rgb, color.b, 0.7);

	//calculate crossfade based on lum
	float mixfactorr = max(0.0, (rgbr*2 - 1));
	float mixfactorg = max(0.0, (rgbg*2 - 1));
	float mixfactorb = max(0.0, (rgbb*2 - 1));

	//crossfade between saturated and desaturated image
	float mixr = mix(color.r, bw, mixfactorr);
	float mixg = mix(color.g, bw, mixfactorg);
	float mixb = mix(color.b, bw, mixfactorb);

	//adjust level of desaturation
	color.r = clamp((mix(mixr, color.r, 0.0)), 0.0, 1.0);
	color.g = clamp((mix(mixg, color.g, 0.0)), 0.0, 1.0);
	color.b = clamp((mix(mixb, color.b, 0.0)), 0.0, 1.0);
	
	//desaturate blue channel
	color.b = color.b*0.8 + ((color.r + color.g)/2.0)*0.2;
	

	//hold color values for color boost
	//vec4 hld = color;

	
	

	
	//undo artifact compensation
	color = max(((color*1.10) - 0.06), 0.0);
	
	//color = color * BRIGHTMULT;

	color.r = pow(color.r, GAMMA);
	color.g = pow(color.g, GAMMA);
	color.b = pow(color.b, GAMMA);
	
	color = color*(1.0 + DARKMULT) - DARKMULT;
	
#endif

color = color / (color + TONEMAP_CURVE) * (1.0+TONEMAP_CURVE);




	gl_FragColor = vec4(color,1.0);
	
// End of Main. -----------------
}
