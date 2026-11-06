// Contrast — scale the distance of every value from a pivot grey, in linear
// light. The pivot reads on the display scale (0.5 is mid-grey on a monitor,
// about 18 % in linear light), so it sits where a waveform shows it; the
// scaling itself happens in linear light so highlights stay HDR-safe.
// Amount 1 is a no-op whatever the pivot.
struct Params {
    amount: f32, // float — 0 flat .. 1 neutral .. 2 doubled
    pivot: f32,  // float — the grey that does not move, display scale
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let c = unpremultiply(src);
    let pivot = pow(clamp(params.pivot, 0.0, 1.0), 2.2);
    let o = max(mix(vec3f(pivot), c, clamp(params.amount, 0.0, 2.0)), vec3f(0.0));
    return vec4f(o * src.a, src.a);
}
