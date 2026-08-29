#version 120

// ─────────────────────────────────────────────────────────────────
//  Legacy Shaders — Realistic — Fragment
//  GLSL 1.20 (OpenGL 2.1).
//
//  Per-pixel cinematic shading:
//    • Hemisphere ambient (sky above / ground below)
//    • Blinn-Phong direct light with a Fresnel-rough specular term
//    • Optional shadow map with 3x3 PCF (off by default)
//    • Atmospheric distance fog (exp2, sky-tinted)
//    • Mild screen-space vignette
//    • ACES filmic tone mapping + gamma correction
//
//  Shadow maps are OFF by default so the shader loads on even the
//  most basic GLSL drivers. To enable true cast shadows, set
//  ENABLE_SHADOWS to 1 and have the mod render a depth texture from
//  the sun's point of view and supply the shadow uniforms.
// ─────────────────────────────────────────────────────────────────

#define ENABLE_SHADOWS 0   // 0 = always loads; 1 = needs shadow uniforms

uniform sampler2D diffuseTexture;
uniform vec3  sunDirection; // view space, normalized, toward scene
uniform vec3  sunColor;
uniform vec3  ambientColor;
uniform vec3  skyColor;     // hemisphere-up tint
uniform vec3  groundColor;   // hemisphere-down tint
uniform vec3  fogColor;
uniform float fogDensity;   // exponential-squared density
uniform float exposure;      // HDR exposure before tone map (try ~1.0)
uniform float gamma;         // output gamma (try 2.2)
uniform vec2  viewportSize;  // framebuffer pixels, for the vignette

#if ENABLE_SHADOWS
uniform sampler2D shadowMap; // depth texture from the sun's POV
uniform mat4 shadowMatrix;    // view-space -> shadow-clip-space
uniform vec2 shadowMapSize;   // texel size for PCF (1.0 / textureSize)
#endif

varying vec2 vTexCoord;
varying vec4 vColor;
varying vec3 vViewPos;
varying vec3 vNormal;

// ACES filmic tone mapping (Narkowicz approximation).
vec3 acesToneMap(vec3 x)
{
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

vec3 applyGamma(vec3 c, float g)
{
    return pow(c, vec3(1.0 / g));
}

// Hemisphere ambient: blend sky/ground by how much the normal points up.
vec3 hemisphereAmbient(vec3 n)
{
    float up = n.y * 0.5 + 0.5;   // 0 (down) .. 1 (up)
    return mix(groundColor, skyColor, up) * ambientColor;
}

#if ENABLE_SHADOWS
// 3x3 percentage-closer filtered shadow factor.
// Returns 1.0 = fully lit, 0.0 = fully shadowed.
float shadowFactor(vec3 viewPos)
{
    vec4 clip = shadowMatrix * vec4(viewPos, 1.0);
    vec3 ndc  = clip.xyz / clip.w;
    vec3 uvw  = ndc * 0.5 + 0.5;        // 0..1

    // Outside the shadow frustum -> treat as lit.
    if (uvw.x < 0.0 || uvw.x > 1.0 ||
        uvw.y < 0.0 || uvw.y > 1.0 ||
        uvw.z < 0.0 || uvw.z > 1.0)
    {
        return 1.0;
    }

    float bias  = 0.005;
    float shadow = 0.0;
    // Constant-bounded loop: fine under GLSL 1.20.
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2  off      = vec2(float(x), float(y)) * shadowMapSize;
            float sampled  = texture2D(shadowMap, uvw.xy + off).r;
            shadow += (uvw.z - bias > sampled) ? 0.0 : 1.0;
        }
    }
    return shadow / 9.0;
}
#endif

void main()
{
    vec4 tex  = texture2D(diffuseTexture, vTexCoord);
    vec3 base = tex.rgb * vColor.rgb;

    vec3 n = normalize(vNormal);
    vec3 L = -sunDirection;          // toward the light source
    vec3 V = normalize(-vViewPos);   // toward the camera (eye at origin)
    vec3 H = normalize(L + V);       // Blinn half-vector

    // --- Direct light: Lambert diffuse + Blinn-Phong specular ---
    float ndl = max(dot(n, L), 0.0);
    float ndh = max(dot(n, H), 0.0);
    float ndv = max(dot(n, V), 0.0);

    float shininess = 32.0;
    float specPow  = pow(ndh, shininess);

    // Fresnel-rough specular: brighter at grazing angles.
    float fresnel = pow(1.0 - ndv, 5.0);
    float spec    = specPow * (0.04 + 0.96 * fresnel);

#if ENABLE_SHADOWS
    float shadow = shadowFactor(vViewPos);
#else
    float shadow = 1.0;
#endif

    vec3 direct  = sunColor * ndl * shadow;
    vec3 ambient = hemisphereAmbient(n);

    vec3 color = base * (ambient + direct) + sunColor * spec * shadow * 0.6;

    // --- Atmospheric distance fog (exp2) ---
    float dist = length(vViewPos);
    float fog  = 1.0 - exp(-fogDensity * fogDensity * dist * dist);
    fog = clamp(fog, 0.0, 1.0);
    color = mix(color, fogColor, fog);

    // --- Mild radial vignette from gl_FragCoord ---
    vec2 ndc = (gl_FragCoord.xy / viewportSize) * 2.0 - 1.0;
    float vig = clamp(1.0 - dot(ndc, ndc) * 0.18, 0.0, 1.0);
    color *= vig;

    // --- HDR exposure + ACES tone map + gamma ---
    color *= exposure;
    color = acesToneMap(color);
    color = applyGamma(color, gamma);

    gl_FragColor = vec4(color, tex.a * vColor.a);
}
