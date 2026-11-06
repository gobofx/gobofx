// Threshold, pass 1 — the hard cut. Brightness above the level is 1, below
// it 0; the level reads on the display scale, as a waveform shows it. The
// mask travels premultiplied, (m·a, 0, 0, a), so the blur that follows
// weights it by coverage and transparent pixels never vote.
struct Params {
    level: f32,    // float — display-scale brightness of the cut
    softness: f32, // float — unused here, see threshold-blur.wgsl
    invert: u32,   // bool — unused here, see threshold.wgsl
    amount: f32,   // float — unused here, see threshold.wgsl
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn luma(c: vec3f) -> f32 {
    return dot(c, vec3f(0.2126, 0.7152, 0.0722));
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    let y = pow(max(luma(unpremultiply(src)), 0.0), 1.0 / 2.2);
    let m = step(clamp(params.level, 0.0, 1.0), y);
    return vec4f(m * src.a, 0.0, 0.0, src.a);
}
