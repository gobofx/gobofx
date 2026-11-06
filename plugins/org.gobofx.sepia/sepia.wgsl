// Sepia — a chemically toned print: the picture goes monochrome, then red is
// lifted and blue sunk in the midtones with a per-channel gamma on the
// display scale, so black stays black, paper-white stays white and only the
// midtones go brown, the way a toner works. Warmth is how far the gammas
// move (0 is a plain black-and-white); Amount blends back to the original in
// linear light, and 0 is a no-op.
struct Params {
    amount: f32, // float — 0 original .. 1 full sepia
    warmth: f32, // float — 0 neutral monochrome .. 1 deep brown midtones
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn luma(c: vec3f) -> f32 {
    return dot(c, vec3f(0.2126, 0.7152, 0.0722));
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let c = unpremultiply(src);
    let y = pow(max(luma(c), 0.0), 1.0 / 2.2); // display-scale brightness, HDR allowed
    let w = clamp(params.warmth, 0.0, 1.0);
    // Per-channel gamma: red lifted, green a touch, blue sunk. At y = 0.5 and
    // full warmth this lands on (0.60, 0.52, 0.31), a print-like brown.
    let g = vec3f(1.0 / (1.0 + 0.40 * w), 1.0 / (1.0 + 0.08 * w), 1.0 + 0.70 * w);
    let toned = pow(vec3f(y), g);
    let sep = pow(toned, vec3f(2.2));
    let o = max(mix(c, sep, clamp(params.amount, 0.0, 1.0)), vec3f(0.0));
    return vec4f(o * src.a, src.a);
}
