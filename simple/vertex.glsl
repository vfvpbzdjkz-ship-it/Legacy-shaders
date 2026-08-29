#version 120

// ─────────────────────────────────────────────────────────────────
//  Legacy Shaders — Simple — Vertex
//  GLSL 1.20 (OpenGL 2.1). Compatible with basic / legacy GLSL.
//
//  Lightweight directional (Lambert) lighting computed per vertex
//  (Gouraud shading) plus linear distance fog. Fast, punchy, and
//  easy to tweak — not trying to be realistic, just clean to play.
// ─────────────────────────────────────────────────────────────────

// Per-vertex inputs from the loader mod:
attribute vec3 position;   // model-space position
attribute vec3 normal;     // model-space normal
attribute vec4 color;      // vertex tint (rgba)
attribute vec2 texCoord;   // texture coordinates

// Camera / transforms:
uniform mat4 modelViewMatrix;
uniform mat4 modelViewProjectionMatrix;
uniform mat3 normalMatrix;

// Lighting (view space):
uniform vec3 sunDirection;  // normalized, view space, from sun toward scene
uniform vec3 sunColor;
uniform vec3 ambientColor;

// Fog:
uniform float fogStart;
uniform float fogEnd;

// Outputs to the fragment stage (GLSL 1.20 uses 'varying'):
varying vec2  vTexCoord;
varying vec4  vColor;
varying float vDiffuse;   // 0..1 directional light factor
varying float vFog;       // 0 (clear) .. 1 (fully fogged)

void main()
{
    gl_Position = modelViewProjectionMatrix * vec4(position, 1.0);

    vTexCoord = texCoord;
    vColor    = color;

    // View-space normal and a simple directional light factor.
    vec3 n = normalize(normalMatrix * normal);
    // Light travels along sunDirection, so a surface is lit when its
    // normal faces the source: dot(n, -sunDirection).
    vDiffuse = max(dot(n, -sunDirection), 0.0);

    // Linear distance fog (eye-space distance).
    vec3  viewPos = (modelViewMatrix * vec4(position, 1.0)).xyz;
    float dist    = length(viewPos);
    vFog = clamp((dist - fogStart) / (fogEnd - fogStart), 0.0, 1.0);
}
