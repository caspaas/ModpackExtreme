#version 120

uniform sampler2D tex;

varying vec4 texcoord;

void main() {


	gl_FragData[0] = texture2DLod(tex, texcoord.st, 0);
}