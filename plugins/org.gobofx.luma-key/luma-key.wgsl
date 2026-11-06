// Luma Keyer — key out by brightness. Pixels darker than Threshold become
// transparent, with a Softness band above it where the key is partial;
// Invert keys the bright end instead. Brightness is read on the display
// scale (gamma 2.2), so 0.5 is mid grey as a waveform shows it. There is no
// spill to suppress: a luma key never tints what it keeps.
struct Params {
    threshold: f32,  // float — display-scale luma below which pixels are keyed
    softness: f32,   // float — width of the partial band above the threshold
    invert: u32,     // bool — key the bright end, keep the dark
    show_matte: u32, // bool — output the alpha as grey
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
    let y = pow(max(luma(c), 0.0), 1.0 / 2.2);
    let t = clamp(params.threshold, 0.0, 1.0);
    let s = max(clamp(params.softness, 0.0, 1.0), 1e-4);
    var alpha = smoothstep(t, t + s, y);
    if (params.invert == 1u) { alpha = 1.0 - alpha; }
    if (params.show_matte == 1u) {
        return vec4f(vec3f(alpha), 1.0);
    }
    let a = src.a * alpha;
    return vec4f(c * a, a);
}
