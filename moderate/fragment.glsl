#version 120

// ─────────────────────────────────────────────────────────────────
//  Legacy Shaders — Moderate — Fragment
//  GLSL 1.20.
//
//  Per-pixel directional lighting with a soft rim/Fresnel highlight,
//  exponential-squared fog, and a gentle Reinhard tone map. A nice
//  middle ground — smoother and richer than Simple, lighter than
//  Realistic.
// ─────────────────────────────────────────────────────────────────

uniform sampler2D diffuseTexture;
uniform vec3  sunDirection; // view space, normalized, toward scene
uniform vec3  sunColor;
uniform vec3  ambientColor;
uniform vec3  skyColor;     // rim tint + fog hint
uniform vec3  fogColor;
uniform float fogDensity;  // exponential-squared density

varying vec2 vTexCoord;
varying vec4 vColor;
varying vec3 vViewPos;
varying vec3 vNormal;

// Reinhard tone map — keeps highlights from clipping.
vec3 toneMap(vec3 c)
{
    return c / (c + vec3(1.0));
}

void main()
{
    vec4 tex  = texture2D(diffuseTexture, vTexCoord);
    vec3 base = tex.rgb * vColor.rgb;

    vec3 n = normalize(vNormal);
    vec3 L = -sunDirection;            // direction toward the light source
    vec3 V = normalize(-vViewPos);     // direction toward the camera (eye at origin)

    float ndl = max(dot(n, L), 0.0);

    // Diffuse + ambient.
    vec3 color = base * (ambientColor + sunColor * ndl);

    // Rim light: brighter at grazing angles, tinted toward the sky.
    float rim = pow(1.0 - max(dot(n, V), 0.0), 3.0);
    color += skyColor * rim * 0.35;

    // Exponential-squared distance fog.
    float dist = length(vViewPos);
    float fog  = 1.0 - exp(-fogDensity * fogDensity * dist * dist);
    fog = clamp(fog, 0.0, 1.0);
    color = mix(color, fogColor, fog);

    // Gentle tone map for nicer highlight rolloff.
    color = toneMap(color);

    gl_FragColor = vec4(color, tex.a * vColor.a);
}
