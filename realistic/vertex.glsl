#version 120

// ─────────────────────────────────────────────────────────────────
//  Legacy Shaders — Realistic — Vertex
//  GLSL 1.20.
//
//  Forwards everything needed for cinematic per-pixel lighting:
//  hemisphere ambient, Blinn-Phong specular, atmospheric fog, ACES
//  tone mapping, gamma correction, and optional shadow maps.
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
