
# Legacy Shaders

Three GLSL shader sets for Minecraft, written for **GLSL 1.20** (`#version 120`)
— the classic, broadly-compatible OpenGL 2.1 shader dialect (the era the
loader mod targets). Each shader is a self-contained **vertex + fragment** pair
meant to be compiled over Minecraft's geometry.

All three share **one uniform/attribute interface**, so the mod only has to wire
the uniforms once. A shader simply ignores the uniforms it doesn't use.

## Shaders

| Folder | Style | What it does |
|--------|-------|--------------|
| `simple/` | Clean, punchy, **playable** | Per-vertex directional (Lambert) lighting + directional ambient (sky factor) + linear distance fog. Fast, light, easy to tweak. Not realistic — just pleasant to look at. |
| `moderate/` | Balanced, pleasant | Per-pixel lighting with **gamma-correct color pipeline**, hemisphere ambient, Blinn-Phong specular, soft rim light, atmospheric fog, extended Reinhard tone map, cinematic color grading, and a vignette. |
| `realistic/` | Cinematic, beautiful | Gamma-correct pipeline, hemisphere ambient + directional irradiance, **energy-conserving normalized Blinn-Phong** with Schlick Fresnel, optional Poisson-disk PCF shadow maps, sun glow, height fog + atmospheric perspective, ACES filmic tone mapping, color grading, film grain, and a smoothstep vignette. |

### What's new in v2

| Feature | Simple | Moderate | Realistic |
|---------|:------:|:--------:|:---------:|
| Directional ambient (sky factor) | ✅ | ✅ (hemisphere) | ✅ (hemisphere + sun irradiance) |
| Blinn-Phong specular | — | ✅ (new) | ✅ (normalized, energy-conserving) |
| Schlick Fresnel | — | ✅ (simple) | ✅ (full) |
| Gamma-correct lighting (sRGB ↔ linear) | — | ✅ (new) | ✅ (new) |
| Atmospheric fog (sky-tinted by view angle) | — | ✅ (new) | ✅ (new) |
| Height fog | — | — | ✅ (new) |
| Sun glow | — | — | ✅ (new) |
| Color grading (warm/cool) | — | ✅ (new) | ✅ (new, + saturation) |
| Film grain | — | — | ✅ (new) |
| Vignette | — | ✅ (new) | ✅ (smoothstep, improved) |
| Tone mapping | — | Reinhard extended (new) | ACES (same) |
| Shadow quality | — | — | Poisson disk + slope bias + bleed reduction (improved) |

## File layout

```
legacy-shaders/
├── README.md
├── simple/
│   ├── vertex.glsl
│   └── fragment.glsl
├── moderate/
│   ├── vertex.glsl
│   └── fragment.glsl
└── realistic/
    ├── vertex.glsl
    └── fragment.glsl
```

## Shared interface

### Vertex attributes

```glsl
attribute vec3 position;   // model-space position
attribute vec3 normal;     // model-space normal
attribute vec4 color;      // per-vertex tint (rgba) — Minecraft block/entity colors
attribute vec2 texCoord;   // texture coordinates
```

### Uniforms

```glsl
// Transforms
uniform mat4 modelMatrix;                 // model -> world (realistic only, for height fog)
uniform mat4 modelViewMatrix;             // view * model
uniform mat4 projectionMatrix;            // projection
uniform mat4 modelViewProjectionMatrix;   // projection * view * model (premultiplied)
uniform mat3 normalMatrix;               // transpose(inverse(mat3(modelViewMatrix)))

// Lighting (view space)
uniform vec3  sunDirection;  // NORMALIZED, view space, points FROM the sun TOWARD the scene
uniform vec3  sunColor;     // direct light color
uniform vec3  ambientColor; // global ambient scale
uniform vec3  skyColor;     // sky / hemisphere-up tint
uniform vec3  groundColor;  // hemisphere-down tint (realistic only; moderate derives it from sky)

// Fog
uniform vec3  fogColor;
uniform float fogStart;     // linear fog start distance (simple)
uniform float fogEnd;       // linear fog end distance (simple)
uniform float fogDensity;  // exponential-squared density (moderate / realistic)

// Camera / scene
uniform vec3  cameraPosition; // world-space camera position (realistic, for height fog)
uniform float time;           // seconds, for animation (realistic, for film grain)
uniform vec2  viewportSize;    // framebuffer size in pixels (moderate + realistic, for vignette)

// Tone (realistic)
uniform float exposure;  // HDR exposure before tone map (try ~1.0)
uniform float gamma;     // output gamma (try 2.2)

// Texture
uniform sampler2D diffuseTexture;

// Optional shadow maps (realistic, only when ENABLE_SHADOWS == 1)
uniform sampler2D shadowMap;    // depth texture from the sun's POV
uniform mat4 shadowMatrix;      // view-space -> shadow-clip-space
uniform vec2 shadowMapSize;     // texel size for PCF (1.0 / textureSize)
```

### Coordinate space & conventions

- Lighting is done in **view (eye) spaces**. The camera sits at the origin, so the
  view direction is `normalize(-viewPosition)`.
- Transform your world-space sun direction into view space before passing it as
  `sunDirection`: `sunDirectionView = mat3(modelViewMatrix) * sunDirectionWorld`.
- `sunDirection` points **from the sun toward the scene** (the direction light
  travels). A surface is lit when its normal faces the source, i.e. `dot(n, -sunDirection) > 0`.
- `modelMatrix` (realistic only) should be the model-to-world transform so that
  `vWorldPos.y` is the world-space height for height fog.

### Gamma-correct pipeline (moderate & realistic)

Minecraft textures are authored in sRGB. These shaders convert the texture to
**linear** before any lighting math, then convert back to sRGB at the end:

```
texture (sRGB) → linear → lighting → fog → tone map → color grade → vignette → sRGB
```

This prevents the "too-dark midtones" problem you get when multiplying sRGB
colors directly by light intensities. The `gamma` uniform (realistic) controls
the final output gamma; moderate hardcodes 2.2.

## Real cast shadows (optional)

Directional shading already darkens faces turned away from the sun — the
"shadow" look early Minecraft shaders were known for. **True cast shadows**
require a separate shadow-map render pass from your mod (render the scene depth
from the sun's point of view).

`realistic/fragment.glsl` has a toggle at the top:

```glsl
#define ENABLE_SHADOWS 0   // 0 = always loads; 1 = needs shadow uniforms
```

Set it to `1`, have the mod supply `shadowMap`, `shadowMatrix`, and
`shadowMapSize`, and the shader will apply a 4-tap Poisson-disk PCF soft shadow
to the direct light. The shadow uses slope-based bias (more bias on steep angles
to reduce acne) and light-bleeding reduction (smoothstep contrast on the
penumbra). With it left at `0` the shader uses no shadow-map uniforms and loads
anywhere, even on the most basic GLSL drivers.

## Suggested starting values

| Uniform | Simple | Moderate | Realistic |
|---------|--------|----------|-----------|
| `sunColor` | (1.0, 0.95, 0.85) | (1.0, 0.95, 0.85) | (1.0, 0.95, 0.85) |
| `ambientColor` | (0.25, 0.25, 0.3) | (0.25, 0.25, 0.3) | (0.35, 0.38, 0.45) |
| `skyColor` | — | (0.4, 0.6, 1.0) | (0.45, 0.65, 1.0) |
| `groundColor` | — | — | (0.25, 0.22, 0.18) |
| `fogColor` | (0.6, 0.75, 1.0) | (0.6, 0.75, 1.0) | (0.62, 0.78, 1.0) |
| `fogStart` / `fogEnd` | 8 / 60 | — | — |
| `fogDensity` | — | 0.012 | 0.010 |
| `exposure` | — | — | 1.1 |
| `gamma` | — | — | 2.2 |
| `viewportSize` | — | (width, height) | (width, height) |
| `cameraPosition` | — | — | world-space camera pos |
| `time` | — | — | seconds (for grain) |

## Compatibility

Everything targets `#version 120`:

- Vertex stage uses `attribute` / `varying` and writes `gl_Position`.
- Fragment stage uses `varying`, samples with `texture2D`, and writes the
  built-in `gl_FragColor`.
- No `in`/`out` qualifiers, no `texture()` sampler functions, no integer
  textures, no `textureSize()`, no derivative functions, no custom fragment
  outputs — all of which require GLSL 1.30+ or extensions.
- Loops use constant bounds; the optional shadow PCF uses manually unrolled
  Poisson-disk taps (no dynamic array indexing).
- `const float` and `vec3()` constructors are used (both valid in 1.20).

If your mod also supports a newer GLSL version these will still load — 1.20
constructs remain valid in later versions.
