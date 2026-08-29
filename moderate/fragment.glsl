
#version 120

// ─────────────────────────────────────────────────────────────────
//  Legacy Shaders — Moderate — Fragment  (v2)
//  GLSL 1.20.
//
//  Per-pixel lighting with a proper gamma-correct pipeline:
//
//    1. Texture (sRGB) → linear
//    2. Hemisphere ambient (sky above / ground below)
//    3. Lambert diffuse + Blinn-Phong specular (NEW — was missing in v1)
//    4. Rim light (kept from v1, softened)
//    5. Atmospheric distance fog (exp², sky-tinted by view angle)
//    6. Extended Reinhard tone map
//    7. Cinematic color grading (warm highlights, cool shadows)
//    8. Vignette
//    9. Linear → sRGB for display
//
//  This is the "nice middle ground" — richer and smoother than
//  Simple, lighter and faster than Realistic, but now with specular
//  highlights, gamma-correct colors, and a filmic color grade.
// ─────────────────────────────────────────────────────────────────

uniform sampler2D diffuseTexture;
uniform vec3  sunDirection;  // view space, normalized, toward scene
uniform vec3  sunColor;
uniform vec3  ambientColor;
uniform vec3  skyColor;      // hemisphere-up tint
uniform vec3  fogColor;
uniform float fogDensity;   // exponential-squared density
uniform vec2  viewportSize;   // framebuffer pixels, for vignette

varying vec2 vTexCoord;
varying vec4 vColor;
varying vec3 vViewPos;
varying vec3 vNormal;

// ── sRGB / linear helpers ────────────────────────────────────────
// Minecraft textures are authored in sRGB.  Multiplying sRGB colors
// by light intensities directly gives incorrect (too-dark) midtones.
// Converting to linear, lighting, then converting back fixes this.
vec3 srgbToLinear(vec3 c) { return pow(c, vec3(2.2)); }
vec3 linearToSrgb(vec3 c) { return pow(c, vec3(1.0 / 2.2)); }

// Extended Reinhard tone map (preserves whites better than plain
// Reinhard).  `white` is the white point — values above it are
// clamped to white after tone mapping.
vec3 toneMap(vec3 c)
{
    float white = 4.0;
    return (c * (1.0 + c / (white * white))) / (1.0 + c);
}

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
    float ndv = max(dot(n, V), 0.0);

    // ─ 2. Hemisphere ambient (derived ground tint from sky) ────────
    float up = n.y * 0.5 + 0.5;
    vec3 groundTint = skyColor * 0.35;
    vec3 ambient = mix(groundTint, skyColor, up) * ambientColor;

    // ─ 3. Diffuse + Blinn-Phong specular ──────────────────────────
    float ndh = max(dot(n, H), 0.0);
    float shininess = 20.0;
    float spec = pow(ndh, shininess);
    // Simple Schlick Fresnel for the specular term.
    float fresnel = pow(1.0 - ndv, 5.0);
    float specIntensity = spec * (0.05 + 0.95 * fresnel) * 0.5;

    vec3 color = base * (ambient + sunColor * ndl)
              + sunColor * specIntensity * ndl;   // spec only on lit faces

    // ─ 4. Rim light (softened from v1) ───────────────────────────
    float rim = pow(1.0 - ndv, 4.0);
    color += skyColor * rim * 0.15;

    // ─ 5. Atmospheric fog (exp², sky-tinted) ─────────────────────
    float dist = length(vViewPos);
    float fog  = 1.0 - exp(-fogDensity * fogDensity * dist * dist);
    fog = clamp(fog, 0.0, 1.0);
    // Fog color shifts toward the sky when looking upward.
    vec3 fogTint = mix(fogColor, skyColor, max(V.y, 0.0) * 0.25);
    color = mix(color, srgbToLinear(fogTint), fog);

    // ─ 6. Tone map ────────────────────────────────────────────────
    color = toneMap(color);

    // ─ 7. Color grading: warm highlights, cool shadows ────────────
    vec3 warmTint = vec3(1.02, 0.98, 0.92);
    vec3 coolTint = vec3(0.92, 0.97, 1.05);
    float lum = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(color * coolTint, color * warmTint, smoothstep(0.0, 0.8, lum));

    // ─ 8. Vignette ────────────────────────────────────────────────
    vec2 ndc = (gl_FragCoord.xy / viewportSize) * 2.0 - 1.0;
    float vig = smoothstep(1.4, 0.5, length(ndc));
    color *= vig;

    // ─ 9. Linear → sRGB for display ──────────────────────────────
    color = linearToSrgb(color);

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), tex.a * vColor.a);
}
