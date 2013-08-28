#version 120



#define WATER_REFLECTIONS

uniform sampler2D composite;
uniform sampler2D gaux2;
uniform sampler2D gaux1;
uniform sampler2D depthtex0;
uniform sampler2D gnormal;

varying vec4 texcoord;
varying vec3 sunlight;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform float far;

uniform int isEyeInWater;

//don't touch these lines if you don't know what you do!
const float stp = 1.0;			//size of one step for raytracing algorithm
const float ref = 0.1;			//refinement multiplier
const float inc = 1.54;			//increasement factor at each step
const int maxf = 5;				//number of refinements

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
        float err = length(vector)*(inc+0.1)-distance(fragpos, spos);
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


void main() {

float spec = texture2D(gaux2,texcoord.xy).r;
float wave = texture2D(gaux2,texcoord.xy).g;




float iswater = 0.0;
if (wave > 0.0) {
iswater = 1.0;
wave = (wave-0.02)*2.0-1.0;
}

    vec3 fragpos = vec3(texcoord.st, texture2D(depthtex0, texcoord.st).r);
    fragpos = nvec3(gbufferProjectionInverse * nvec4(fragpos * 2.0 - 1.0));
    vec3 normal = texture2D(gnormal, texcoord.st).rgb * 2.0 - 1.0;
    vec4 color = texture2D(composite,texcoord.xy);
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

/* DRAWBUFFERS:NNNNNN6 */

	gl_FragData[6] = color;
}
