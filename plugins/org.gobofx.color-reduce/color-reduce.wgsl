// Color Reduce — snap every channel to a few evenly spaced levels on the
// display scale, so the palette is levels³ colours, with an optional 4×4
// ordered dither that trades the bands for a regular pattern, the way an
// indexed-colour image was made. Amount blends back to the original in
// linear light; 0 is a no-op (the top of the Levels range is close to the
// source but not exact, so Amount is the neutral setting).
struct Params {
    levels: i32, // int — steps per channel, 2..32
    dither: u32, // bool — 1: 4×4 ordered dither before the snap
    amount: f32, // float — 0 original .. 1 reduced
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}
fn encode(c: vec3f) -> vec3f {
    return pow(max(c, vec3f(0.0)), vec3f(1.0 / 2.2));
}
fn decode(c: vec3f) -> vec3f {
    return pow(max(c, vec3f(0.0)), vec3f(2.2));
}
// The 4×4 Bayer matrix (0..15) from the pixel coordinate, by bit interleave:
// no array lookup, so it is the same on every backend.
fn bayer4(p: vec2u) -> f32 {
    let x = p.x & 3u;
    let y = p.y & 3u;
    let xy = x ^ y;
    let v = ((xy & 1u) << 3u) | ((y & 1u) << 2u) | (xy & 2u) | ((y & 2u) >> 1u);
    return (f32(v) + 0.5) / 16.0;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let c = unpremultiply(src);
    let n = f32(clamp(params.levels, 2, 32)) - 1.0;
    let e = min(encode(c), vec3f(1.0));
    var q: vec3f;
    if (params.dither == 1u) {
        let px = vec2u(floor(uv * gobofx_globals.resolution));
        q = floor(e * n + bayer4(px)) / n;
    } else {
        q = round(e * n) / n;
    }
    let o = max(mix(c, decode(q), clamp(params.amount, 0.0, 1.0)), vec3f(0.0));
    return vec4f(o * src.a, src.a);
}
