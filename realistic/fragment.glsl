
#version 120

// ─────────────────────────────────────────────────────────────────
//  Legacy Shaders — Realistic — Fragment  (v2)
//  GLSL 1.20 (OpenGL 2.1).
//
//  Per-pixel cinematic shading with a fully gamma-correct pipeline:
//
//    1. Texture (sRGB) → linear
//    2. Hemisphere ambient + directional irradiance (sky/ground/sun)
//    3. Normalized Blinn-Phong specular with Schlick Fresnel
//       (energy-conserving — specular no longer gets brighter at
//       low shininess, which was a bug in v1)
//    4. Optional PCF shadow map — 4-tap Poisson disk with slope-based
//       bias and light-bleeding reduction (v1 used a plain 3×3 grid)
//    5. Sun glow — subtle bloom-like highlight when looking toward
//       the sun (NEW)
//    6. Atmospheric distance fog (exp²) + height fog — denser in low
//       areas, tinted by sky color based on view angle (NEW)
//    7. Exposure → ACES filmic tone map
//    8. Cinematic color grading — warm highlights, cool shadows,
//       gentle saturation boost (NEW)
//    9. Film grain — procedural, animated, very subtle (NEW)
//   10. Smoothstep vignette (improved from v1's linear falloff)
//   11. Linear → sRGB for display
//
//  Shadow maps are OFF by default so the shader loads on even the
//  most basic GLSL drivers.  Set ENABLE_SHADOWS to 1 and supply the
//  shadow uniforms to enable true cast shadows.
// ─────────────────────────────────────────────────────────────────

#define ENABLE_SHADOWS 0   // 0 = always loads; 1 = needs shadow uniforms

uniform sampler2D diffuseTexture;
uniform vec3  sunDirection;  // view space, normalized, toward scene
uniform vec3  sunColor;
uniform vec3  ambientColor;
uniform vec3  skyColor;      // hemisphere-up tint
uniform vec3  groundColor;   // hemisphere-down tint
uniform vec3  fogColor;
uniform float fogDensity;   // exponential-squared density
uniform float exposure;       // HDR exposure before tone map (try ~1.0)
uniform float gamma;          // output gamma (try 2.2)
uniform vec2  viewportSize;   // framebuffer pixels, for vignette
uniform vec3  cameraPosition; // world-space camera position
uniform float time;           // seconds, for grain animation

#if ENABLE_SHADOWS
uniform sampler2D shadowMap;   // depth texture from the sun's POV
uniform mat4 shadowMatrix;     // view-space -> shadow-clip-space
uniform vec2 shadowMapSize;    // texel size for PCF (1.0 / textureSize)
#endif

varying vec2 vTexCoord;
varying vec4 vColor;
varying vec3 vViewPos;
varying vec3 vNormal;
varying vec3 vWorldPos;

const float PI = 3.14159265;

// ── sRGB / linear helpers ────────────────────────────────────────
vec3 srgbToLinear(vec3 c) { return pow(c, vec3(2.2)); }
vec3 linearToSrgb(vec3 c) { return pow(c, vec3(1.0 / gamma)); }

// ── ACES filmic tone mapping (Narkowicz approximation) ───────────
vec3 acesToneMap(vec3 x)
{
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

// ── Schlick Fresnel ───────────────────────────────────────────────
float schlickFresnel(float cosTheta, float F0)
{
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

// ── Hemisphere ambient with directional sun irradiance ──────────
// Blends sky/ground by normal-up, then adds a gentle directional
// component from the sun so faces turned toward the light get a
// little extra ambient even before the direct term kicks in.
vec3 hemisphereAmbient(vec3 n, vec3 L)
{
    float up = n.y * 0.5 + 0.5;
    vec3 hemi = mix(groundColor, skyColor, up);
    float sunBounce = max(dot(n, L), 0.0) * 0.12;
    return (hemi + skyColor * sunBounce) * ambientColor;
}

// ── Procedural hash for film grain ───────────────────────────────
float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

#if ENABLE_SHADOWS
// ── 4-tap Poisson-disk PCF shadow ────────────────────────────────
// Improvements over v1:
//   • Poisson disk (rotated, less banding than a grid)
//   • Slope-based bias (more bias on steep angles → less acne)
//   • Light-bleeding reduction via smoothstep contrast
float shadowFactor(vec3 viewPos, vec3 n, vec3 L)
{
    vec4 clip = shadowMatrix * vec4(viewPos, 1.0);
    vec3 ndc  = clip.xyz / clip.w;
    vec3 uvw  = ndc * 0.5 + 0.5;

    // Outside the shadow frustum → treat as lit.
    if (uvw.x < 0.0 || uvw.x > 1.0 ||
        uvw.y < 0.0 || uvw.y > 1.0 ||
        uvw.z < 0.0 || uvw.z > 1.0)
    {
        return 1.0;
    }

    // Slope-based bias: more bias on surfaces facing away from the
    // light (steep angles cause more shadow acne).
    float bias = 0.003 + (1.0 - max(dot(n, L), 0.0)) * 0.01;

    // 4-tap Poisson disk — manually unrolled for GLSL 1.20
    // (avoids dynamic array indexing, which some old drivers
    // mishandle in the fragment stage).
    vec2 spread = shadowMapSize * 1.5;
    vec2 d0 = vec2(-0.94201624, -0.39906216) * spread;
    vec2 d1 = vec2( 0.94201624,  0.39906216) * spread;
    vec2 d2 = vec2(-0.39906216,  0.94201624) * spread;
    vec2 d3 = vec2( 0.39906216, -0.94201624) * spread;

    float s0 = texture2D(shadowMap, uvw.xy + d0).r;
    float s1 = texture2D(shadowMap, uvw.xy + d1).r;
    float s2 = texture2D(shadowMap, uvw.xy + d2).r;
    float s3 = texture2D(shadowMap, uvw.xy + d3).r;

    float shadow = 0.0;
    shadow += (uvw.z - bias > s0) ? 0.0 : 1.0;
    shadow += (uvw.z - bias > s1) ? 0.0 : 1.0;
    shadow += (uvw.z - bias > s2) ? 0.0 : 1.0;
    shadow += (uvw.z - bias > s3) ? 0.0 : 1.0;
    shadow *= 0.25;

    // Light-bleeding reduction: sharpen the penumbra so partially
    // shadowed areas don't bleed too much light through.
    shadow = smoothstep(0.2, 0.8, shadow);

    return shadow;
}
#endif

void main()
{
    // ─ 1. Sample & convert to linear ──────────────────────────────
    vec4 tex  = texture2D(diffuseTexture, vTexCoord);
    vec3 base = srgbToLinear(tex.rgb * vColor.rgb);

    vec3 n = normalize(vNormal);
    vec3 L = -sunDirection;           // toward the light source
    vec3 V = normalize(-vViewPos);   // toward the camera (eye at origin)
    vec3 H = normalize(L + V);       // Blinn half-vector

    float ndl = max(dot(n, L), 0.0);
    float ndh = max(dot(n, H), 0.0);
    float ndv = max(dot(n, V), 0.0);

    // ─ 2. Ambient ─────────────────────────────────────────────────
    vec3 ambient = hemisphereAmbient(n, L);

    // ─ 3. Direct light + shadow ───────────────────────────────────
#if ENABLE_SHADOWS
    float shadow = shadowFactor(vViewPos, n, L);
#else
    float shadow = 1.0;
#endif

    vec3 directLight = sunColor * ndl * shadow;

    // ─ 4. Normalized Blinn-Phong specular with Schlick Fresnel ────
    // The (shininess + 2) / (8π) normalization factor conserves
    // energy — the specular lobe's total energy stays constant
    // regardless of shininess, so tighter highlights are brighter
    // but narrower (correct), not just brighter (wrong).
    float shininess = 48.0;
    float specNorm  = (shininess + 2.0) / (8.0 * PI);
    float specPow   = pow(ndh, shininess);
    float F0        = 0.04;                    // dielectric at normal incidence
    float fresnel   = schlickFresnel(ndv, F0);
    float spec      = specPow * specNorm * fresnel;

    vec3 color = base * (ambient + directLight)
               + sunColor * spec * shadow;

    // ─ 5. Sun glow — subtle highlight when looking toward the sun ─
    float sunGlow = pow(max(dot(V, -sunDirection), 0.0), 256.0);
    color += sunColor * sunGlow * 0.15 * shadow;

    // ─ 6. Atmospheric fog (exp² + height fog) ─────────────────────
    float dist = length(vViewPos);
    float fog  = 1.0 - exp(-fogDensity * fogDensity * dist * dist);
    fog = clamp(fog, 0.0, 1.0);

    // Height fog: slightly denser in low areas (camera-relative).
    float heightFog = clamp((cameraPosition.y - vWorldPos.y)
                            * fogDensity * 0.005, 0.0, 0.25);
    fog = clamp(fog + heightFog, 0.0, 1.0);

    // Atmospheric perspective: fog tint shifts toward the sky when
    // looking upward, and toward the fog color when looking down.
    vec3 fogTint = mix(fogColor, skyColor, max(V.y, 0.0) * 0.3);
    color = mix(color, srgbToLinear(fogTint), fog);

    // ─ 7. Exposure + tone map ─────────────────────────────────────
    color *= exposure;
    color  = acesToneMap(color);

    // ─ 8. Color grading ───────────────────────────────────────────
    // Warm highlights / cool shadows (classic cinematic split-tone).
    vec3 warmTint = vec3(1.03, 0.98, 0.90);
    vec3 coolTint = vec3(0.90, 0.96, 1.06);
    float lum = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(color * coolTint, color * warmTint,
               smoothstep(0.0, 0.8, lum));

    // Gentle saturation boost.
    float gray = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(gray), color, 1.08);

    // ─ 9. Vignette (smoothstep for a softer falloff) ─────────────
    vec2 ndc = (gl_FragCoord.xy / viewportSize) * 2.0 - 1.0;
    float vig = smoothstep(1.5, 0.4, length(ndc));
    color *= vig;

    // ─ 10. Linear → sRGB for display ──────────────────────────────
    color = linearToSrgb(color);

    // ─ 11. Film grain (in display space, very subtle) ────────────
    float grain = hash(gl_FragCoord.xy + time * 60.0) - 0.5;
    color += grain * 0.012;

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), tex.a * vColor.a);
}
