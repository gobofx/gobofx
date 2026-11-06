// MinMax — erode (Min) or dilate (Max) with a square window, separable into
// a horizontal and a vertical pass. Radius 0 is the source untouched.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_RADIUS: f32 = 8.0;

struct Params {
    mode: u32,     // choice — 0 Min (erode), 1 Max (dilate)
    radius: f32,   // float — px; half the window, 0 is a no-op
    channels: u32, // choice — 0 RGB only, 1 alpha only, 2 both
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

// Picks the "better" of two premultiplied pixels for the mode: the
// per-channel extreme for Both and RGB, the whole pixel with the extreme
// alpha for Alpha (so a dilated shape carries its own colour outward
// rather than a black fringe).
fn pick(acc: vec4f, s: vec4f) -> vec4f {
    let want_max = params.mode == 1u;
    if (params.channels == 1u) {
        let take = select(s.a < acc.a, s.a > acc.a, want_max);
        return select(acc, s, take);
    }
    return select(min(acc, s), max(acc, s), want_max);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let centre = src_at(uv);
    let r = clamp(params.radius, 0.0, MAX_RADIUS);
    if (r < 0.01) {
        return centre;
    }
    let dir = vec2f(DIR_X, DIR_Y) * gobofx_globals.texel;
    let n = i32(ceil(r));
    // The outermost taps only count for the fractional part of the radius,
    // so an animated radius grows smoothly instead of in pixel steps.
    let outer = r - f32(n - 1);
    var acc = centre;
    for (var i = -n; i <= n; i++) {
        if (i == 0) {
            continue;
        }
        var s = src_at(uv + dir * f32(i));
        if (abs(i) == n) {
            s = mix(centre, s, outer);
        }
        acc = pick(acc, s);
    }
    if (params.channels == 0u) {
        // Colour moves, the shape stays: keep the centre's alpha and stay premultiplied.
        return vec4f(min(acc.rgb, vec3f(centre.a)), centre.a);
    }
    return acc;
}
