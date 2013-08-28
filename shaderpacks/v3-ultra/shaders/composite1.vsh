#version 120
uniform int worldTime;
varying vec4 texcoord;
varying vec3 sunlight;

void main() {
	gl_Position = ftransform();
	
	texcoord = gl_MultiTexCoord0;
	
	
			float timefract = float(worldTime);

	 float TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0-(clamp(timefract, 0.0, 6000.0)/6000.0));
		  
	 float TimeNoon     = ((clamp(timefract, 0.0, 6000.0)) / 6000.0) - ((clamp(timefract, 6000.0, 12000.0) - 6000.0) / 6000.0);
	  
	 float TimeSunset   = ((clamp(timefract, 6000.0, 12000.0) - 6000.0) / 6000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
		  
	 float TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);
	
	
	
	
	//water specular color
		vec3 sunrise_sun;
	 sunrise_sun.r = 1.0 * TimeSunrise;
	 sunrise_sun.g = 0.75 * TimeSunrise;
	 sunrise_sun.b = 0.35*TimeSunrise;
	 
	
	vec3 noon_sun;
	 noon_sun.r = 1.00 * TimeNoon;
	 noon_sun.g = 0.82 * TimeNoon;
	 noon_sun.b = 0.72 * TimeNoon;	 
	
	

	
	vec3 sunset_sun;
	 sunset_sun.r = 1.0 * TimeSunset;
	 sunset_sun.g = 0.75 * TimeSunset;
	 sunset_sun.b = 0.35* TimeSunset;

	
	vec3 midnight_sun;
	 midnight_sun.r = 0.2  * TimeMidnight;
	 midnight_sun.g = 0.24  * TimeMidnight;
	 midnight_sun.b = 0.37  * TimeMidnight;



	
	 sunlight.r = sunrise_sun.r + noon_sun.r + sunset_sun.r + midnight_sun.r;
	 sunlight.g = sunrise_sun.g + noon_sun.g + sunset_sun.g + midnight_sun.g;
	 sunlight.b = sunrise_sun.b + noon_sun.b + sunset_sun.b + midnight_sun.b;
	 
}
