
#version 120

// ─────────────────────────────────────────────────────────────────
//  Legacy Shaders — Moderate — Vertex  (v2)
//  GLSL 1.20.
//
//  Forwards view-space position and normal to the fragment stage
//  so lighting can be computed per pixel for smoother shading.
// ─────────────────────────────────────────────────────────────────

attribute vec3 position;
attribute vec3 normal;
attribute vec4 color;
attribute vec2 texCoord;

uniform mat4 modelViewMatrix;
uniform mat4 modelViewProjectionMatrix;
uniform mat3 normalMatrix;

varying vec2 vTexCoord;
varying vec4 vColor;
varying vec3 vViewPos;   // eye-space position
varying vec3 vNormal;    // eye-space normal

void main()
{
    vec4 viewPos = modelViewMatrix * vec4(position, 1.0);
    gl_Position  = modelViewProjectionMatrix * vec4(position, 1.0);

    vViewPos = viewPos.xyz;
    vNormal  = normalize(normalMatrix * normal);
    vTexCoord = texCoord;
    vColor    = color;
}
