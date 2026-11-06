// Threshold, pass 4 — composite. The blurred mask comes back as (m·a, _, _, a);
// dividing by its alpha gives a coverage-weighted soft mask, so a soft edge
// against transparency does not darken. Invert swaps black and white and
// Amount blends back to the original in linear light; 0 is a no-op.
struct Params {
    level: f32,    // float — unused here, see threshold-mask.wgsl
    softness: f32, // float — unused here, see threshold-blur.wgsl
    invert: u32,   // bool — 1 swaps black and white
    amount: f32,   // float — 0 original .. 1 full cutoff
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let soft = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    let src = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    let c = unpremultiply(src);
    var m = clamp(select(0.0, soft.r / max(soft.a, 1e-6), soft.a > 0.0), 0.0, 1.0);
    if (params.invert == 1u) {
        m = 1.0 - m;
    }
    let o = max(mix(c, vec3f(m), clamp(params.amount, 0.0, 1.0)), vec3f(0.0));
    return vec4f(o * src.a, src.a);
}
