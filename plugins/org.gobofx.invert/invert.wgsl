// Invert — negative image, per channel or brightness only.
struct Params {
    amount: f32,   // float — 0 none … 1 full negative
    channels: u32, // choice — 0 rgb, 1 red, 2 green, 3 blue, 4 luma (keeps the hue)
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

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let c = unpremultiply(src);
    var inv = c;
    switch params.channels {
        case 1u: { inv.r = 1.0 - c.r; }
        case 2u: { inv.g = 1.0 - c.g; }
        case 3u: { inv.b = 1.0 - c.b; }
        case 4u: {
            let y = luma(c);
            inv = c - y + (1.0 - y); // move the luma to its negative, keep the chroma
        }
        default: { inv = 1.0 - c; }
    }
    let o = max(mix(c, inv, clamp(params.amount, 0.0, 1.0)), vec3f(0.0));
    return vec4f(o * src.a, src.a);
}
