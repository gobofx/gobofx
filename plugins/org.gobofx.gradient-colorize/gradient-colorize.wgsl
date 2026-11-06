// Gradient Colorize — the picture's brightness indexes a three-stop gradient:
// blacks, a midtone colour at a movable position, whites. Brightness is read
// on the display scale so the stops sit where a waveform shows them; the
// colour blends and the mix with the original happen in linear light.
struct Params {
    color_a: vec4f, // color — the stop at black (premultiplied, as all colour params)
    color_b: vec4f, // color — the stop at `mid`
    color_c: vec4f, // color — the stop at white
    mid: f32,       // float — display-scale brightness where color_b sits
    amount: f32,    // float — 0 original .. 1 full gradient
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
    let t = clamp(pow(max(luma(c), 0.0), 1.0 / 2.2), 0.0, 1.0);
    let m = clamp(params.mid, 0.05, 0.95);
    let a = unpremultiply(params.color_a);
    let b = unpremultiply(params.color_b);
    let d = unpremultiply(params.color_c);
    var tone: vec3f;
    if (t < m) {
        tone = mix(a, b, t / m);
    } else {
        tone = mix(b, d, (t - m) / (1.0 - m));
    }
    let o = max(mix(c, tone, clamp(params.amount, 0.0, 1.0)), vec3f(0.0));
    return vec4f(o * src.a, src.a);
}
