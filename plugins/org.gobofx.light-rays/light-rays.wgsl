// Light Rays — crepuscular rays: the brights are smeared away from a light
// point, as if a volume of haze were lit from there. Pass 1 keeps what is
// above the threshold; pass 2 marches each pixel towards the light through
// that image with a decaying weight and adds the result. Intensity 0 passes
// through.
const SAMPLES: i32 = 48;

struct Params {
    light: vec2f,   // point — where the rays come from
    length: f32,    // float — march distance, as a fraction of the way to the light
    decay: f32,     // float — per-step weight falloff; 1 keeps the whole march
    intensity: f32, // float — strength of the rays
    threshold: f32, // float — brightness that casts rays
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn luma(c: vec3f) -> f32 {
    return dot(c, vec3f(0.2126, 0.7152, 0.0722));
}
fn hash21(p: vec2f) -> f32 {
    var q = fract(p * vec2f(123.34, 456.21));
    q = q + dot(q, q + 45.32);
    return fract(q.x * q.y);
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}
// Outside the frame nothing casts a ray; clamp-to-edge would streak the
// border colours instead.
fn bright_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0), inside);
}

@fragment
fn fs_bright(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let y = luma(unpremultiply(src));
    let t = clamp(params.threshold, 0.0, 1.0);
    return src * smoothstep(t * 0.8, t, y);
}

@fragment
fn fs_rays(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let k = clamp(params.intensity, 0.0, 3.0);
    if (k < 1e-4) { return src; }
    let step = (params.light - uv) * clamp(params.length, 0.0, 1.0) / f32(SAMPLES);
    let decay = clamp(params.decay, 0.5, 1.0);
    let j = hash21(uv * gobofx_globals.resolution); // per-pixel jitter hides the steps
    var acc = vec4f(0.0);
    var w = 1.0;
    var wsum = 0.0;
    for (var i = 0; i < SAMPLES; i++) {
        acc += bright_at(uv + step * (f32(i) + j)) * w;
        wsum += w;
        w *= decay;
    }
    let rays = acc / wsum * k;
    let a = clamp(src.a + rays.a, 0.0, 1.0);
    return vec4f(src.rgb + rays.rgb, a);
}
