// Chroma Keyer — key out a green or blue screen by chroma distance, with
// spill suppression on what remains.
struct Params {
    key_color: vec4f, // color — the screen colour (linear)
    tolerance: f32,   // float — chroma distance that is fully keyed
    softness: f32,    // float — width of the partial band beyond tolerance
    spill: f32,       // float — how much of the key hue to pull out of edges
    show_matte: u32,  // bool — output the alpha as grey
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

// Chroma in a perceptual-ish space: gamma-encode, then Cb/Cr style differences.
fn chroma(c: vec3f) -> vec2f {
    let p = pow(max(c, vec3f(0.0)), vec3f(0.4545));
    let y = luma(p);
    return vec2f(p.b - y, p.r - y);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let c = unpremultiply(src);
    let key = unpremultiply(params.key_color);
    let d = distance(chroma(c), chroma(key));
    let t = clamp(params.tolerance, 0.0, 1.0) * 0.5;
    let s = max(clamp(params.softness, 0.0, 1.0) * 0.5, 1e-4);
    let alpha = smoothstep(t, t + s, d);
    if (params.show_matte == 1u) {
        return vec4f(vec3f(alpha), 1.0);
    }
    // Spill: clamp the key's dominant channel to the mean of the other two.
    var o = c;
    let k = clamp(params.spill, 0.0, 1.0);
    if (key.g >= key.r && key.g >= key.b) {
        o.g = mix(o.g, min(o.g, 0.5 * (o.r + o.b)), k);
    } else if (key.b >= key.r) {
        o.b = mix(o.b, min(o.b, 0.5 * (o.r + o.g)), k);
    } else {
        o.r = mix(o.r, min(o.r, 0.5 * (o.g + o.b)), k);
    }
    let a = src.a * alpha;
    return vec4f(o * a, a);
}
