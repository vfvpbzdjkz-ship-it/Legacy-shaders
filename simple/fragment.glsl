
#version 120

// ─────────────────────────────────────────────────────────────────
//  Legacy Shaders — Simple — Fragment  (v2)
//  GLSL 1.20.
//
//  Samples the diffuse texture, applies the vertex tint and the
//  per-vertex directional light + directional ambient, then linear
//  fog.
//
//  v2: ambient is now modulated by the sky factor so upward-facing
//      surfaces are brighter and downward-facing surfaces darker —
//      a subtle but noticeable improvement over flat ambient.
// ─────────────────────────────────────────────────────────────────

uniform sampler2D diffuseTexture;
uniform vec3 sunColor;
uniform vec3 ambientColor;
uniform vec3 fogColor;

varying vec2  vTexCoord;
varying vec4  vColor;
varying float vDiffuse;
varying float vFog;
varying float vSkyFactor;

void main()
{
    vec4 tex = texture2D(diffuseTexture, vTexCoord);

    // Modulate the texture by the vertex tint (Minecraft block colors).
    vec3 base = tex.rgb * vColor.rgb;

    // Directional ambient: 60% base + 40% sky-oriented variation.
    vec3 ambient = ambientColor * (0.6 + 0.4 * vSkyFactor);

    // Directional light + ambient.
    vec3 lit = base * (ambient + sunColor * vDiffuse);

    // Blend toward the fog color.
    vec3 finalColor = mix(lit, fogColor, vFog);

    gl_FragColor = vec4(finalColor, tex.a * vColor.a);
}
