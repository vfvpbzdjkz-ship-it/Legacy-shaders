
#version 120

// ─────────────────────────────────────────────────────────────────
//  Legacy Shaders — Realistic — Vertex  (v2)
//  GLSL 1.20.
//
//  Forwards everything needed for cinematic per-pixel lighting.
//
//  v2: also forwards world-space position (needs modelMatrix) so
//      the fragment stage can compute height-based fog and
//      atmospheric perspective relative to the camera.
// ─────────────────────────────────────────────────────────────────

attribute vec3 position;
attribute vec3 normal;
attribute vec4 color;
attribute vec2 texCoord;

uniform mat4 modelMatrix;                // NEW: model -> world (for height fog)
uniform mat4 modelViewMatrix;
uniform mat4 modelViewProjectionMatrix;
uniform mat3 normalMatrix;

varying vec2 vTexCoord;
varying vec4 vColor;
varying vec3 vViewPos;    // eye-space position
varying vec3 vNormal;     // eye-space normal
varying vec3 vWorldPos;   // NEW: world-space position

void main()
{
    vec4 viewPos = modelViewMatrix * vec4(position, 1.0);
    gl_Position  = modelViewProjectionMatrix * vec4(position, 1.0);

    vViewPos  = viewPos.xyz;
    vNormal   = normalize(normalMatrix * normal);
    vWorldPos = (modelMatrix * vec4(position, 1.0)).xyz;
    vTexCoord = texCoord;
    vColor    = color;
}
