#version 120

varying vec4 texcoord;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform float rainStrength;

uniform int worldTime;

varying vec3 lightVector;
varying vec3 upVector;

varying float timeSunrise;
varying float timeNoon;
varying float timeSunset;
varying float timeMidnight;

varying vec3 colorSunlight;
varying vec3 colorSkylight;

void main() {
	gl_Position = ftransform();
	
	texcoord = gl_MultiTexCoord0;

	if (worldTime < 12700 || worldTime > 23250) {
		lightVector = normalize(sunPosition);
	} else {
		lightVector = normalize(moonPosition);
	}

	float timePow = 3.0f;
	float timefract = worldTime;
	
	timeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 4000.0)/4000.0));  
	timeNoon     = ((clamp(timefract, 0.0, 4000.0)) / 4000.0) - ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0);
	timeSunset   = ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);  
	timeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);
	
	timeSunrise  = pow(timeSunrise, timePow);
	timeNoon     = pow(timeNoon, 1.0f/timePow);
	timeSunset   = pow(timeSunset, timePow);
	timeMidnight = pow(timeMidnight, 1.0f/timePow);



	upVector = normalize(upPosition);

	float rayleigh = 0.0f;

	//colors for shadows/sunlight and sky
	
	vec3 sunrise_sun;
	 sunrise_sun.r = 1.00 * timeSunrise;
	 sunrise_sun.g = 0.56 * timeSunrise;
	 sunrise_sun.b = 0.00 * timeSunrise;
	 sunrise_sun *= 0.35f;
	
	vec3 sunrise_amb;
	 sunrise_amb.r = 0.00 * timeSunrise;
	 sunrise_amb.g = 0.25 * timeSunrise;
	 sunrise_amb.b = 0.70 * timeSunrise;	
	 sunrise_amb = mix(sunrise_amb, vec3(1.0f), 0.2f);
	 
	
	vec3 noon_sun;
	 noon_sun.r = mix(1.00, 1.00, rayleigh) * timeNoon;
	 noon_sun.g = mix(1.00, 0.48, rayleigh) * timeNoon;
	 noon_sun.b = mix(1.00, 0.00, rayleigh) * timeNoon;	 
	
	vec3 noon_amb;
	 noon_amb.r = 0.00 * timeNoon * 1.0;
	 noon_amb.g = 0.23 * timeNoon * 1.0;
	 noon_amb.b = 0.999 * timeNoon * 1.0;
	
	vec3 sunset_sun;
	 sunset_sun.r = 1.0 * timeSunset;
	 sunset_sun.g = 0.48 * timeSunset;
	 sunset_sun.b = 0.0 * timeSunset;
	 sunset_sun *= 0.55f;
	
	vec3 sunset_amb;
	 sunset_amb.r = 0.252 * timeSunset;
	 sunset_amb.g = 0.427 * timeSunset;
	 sunset_amb.b = 0.700 * timeSunset;
	
	vec3 midnight_sun;
	 midnight_sun.r = 0.45 * timeMidnight;
	 midnight_sun.g = 0.6 * timeMidnight;
	 midnight_sun.b = 0.8 * timeMidnight;
	 midnight_sun *= 0.1f;
	
	vec3 midnight_amb;
	 midnight_amb.r = 0.3 * timeMidnight;
	 midnight_amb.g = 0.4 * timeMidnight;
	 midnight_amb.b = 0.8 * timeMidnight;
	 midnight_amb *= 0.04f;


	colorSunlight;
	 colorSunlight.r = sunrise_sun.r + noon_sun.r + sunset_sun.r + midnight_sun.r;
	 colorSunlight.g = sunrise_sun.g + noon_sun.g + sunset_sun.g + midnight_sun.g;
	 colorSunlight.b = sunrise_sun.b + noon_sun.b + sunset_sun.b + midnight_sun.b;
	
	colorSkylight;
	 colorSkylight.r = sunrise_amb.r + noon_amb.r + sunset_amb.r + midnight_amb.r;
	 colorSkylight.g = sunrise_amb.g + noon_amb.g + sunset_amb.g + midnight_amb.g;
	 colorSkylight.b = sunrise_amb.b + noon_amb.b + sunset_amb.b + midnight_amb.b;

	colorSkylight.g *= 0.95f;

	float sun_fill = 0.41f;
	colorSkylight = mix(colorSkylight, colorSunlight, sun_fill);

	vec3 colorSkylight_rain = vec3(2.0, 2.0, 2.38) * 0.5f * (1.0f - timeMidnight * 0.95f);
	colorSkylight = mix(colorSkylight, colorSkylight_rain, rainStrength); //rain

	//Saturate sunlight colors
	colorSunlight = pow(colorSunlight, vec3(2.0f));

	//Make ambient light darker when not day time
	colorSkylight = mix(colorSkylight, colorSkylight * 0.5f, timeSunrise);
	colorSkylight = mix(colorSkylight, colorSkylight * 1.0f, timeNoon);
	colorSkylight = mix(colorSkylight, colorSkylight * 0.5f, timeSunset);
	colorSkylight = mix(colorSkylight, colorSkylight * 0.005f, timeMidnight);

	//Make sunlight darker when not day time
	colorSunlight = mix(colorSunlight, colorSunlight * 1.0f, timeSunrise);
	colorSunlight = mix(colorSunlight, colorSunlight * 1.0f, timeNoon);
	colorSunlight = mix(colorSunlight, colorSunlight * 1.0f, timeSunset);
	colorSunlight = mix(colorSunlight, colorSunlight * 0.0025f, timeMidnight);

}
