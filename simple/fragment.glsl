#version 120

// ─────────────────────────────────────────────────────────────────
//  Legacy Shaders — Simple — Fragment
//  GLSL 1.20.
//
//  Samples the diffuse texture, applies the vertex tint and the
//  per-vertex directional light + ambient, then linear fog.
// ─────────────────────────────────────────────────────────────────

uniform sampler2D diffuseTexture;
uniform vec3 sunColor;
uniform vec3 ambientColor;
uniform vec3 fogColor;

varying vec2  vTexCoord;
varying vec4  vColor;
varying float vDiffuse;
varying float vFog;

void main()
{
    vec4 tex = texture2D(diffuseTexture, vTexCoord);

    // Modulate the texture by the vertex tint (Minecraft block colors).
    vec3 base = tex.rgb * vColor.rgb;

    // Directional light + ambient.
    vec3 lit = base * (ambientColor + sunColor * vDiffuse);

    // Blend toward the fog color.
    vec3 finalColor = mix(lit, fogColor, vFog);

    gl_FragColor = vec4(finalColor, tex.a * vColor.a);
}
