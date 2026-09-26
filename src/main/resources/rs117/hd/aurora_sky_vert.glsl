#version 330

#include <uniforms/global.glsl>

out vec3 vSkyDirection;
out vec2 vSkyUv;

void main()
{
	vec2 position = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);
	vec2 ndc = position * 2.0 - 1.0;
	gl_Position = vec4(ndc, 0.0, 1.0);
	vSkyUv = ndc * 0.5 + 0.5;

	// Use the same proven world-space sky ray as Aurora 0.9.
	// The 0.10/0.10.1 experimental reconstruction mixed view/world axes
	// and produced a visible split across the sky.
	vec4 viewPosition = invProjectionMatrix * vec4(ndc, 1.0, 1.0);
	vec3 viewDirection = normalize(viewPosition.xyz / max(abs(viewPosition.w), 0.0001));
	vSkyDirection = normalize(transpose(mat3(viewMatrix)) * viewDirection);
}
