// Prism — the three colour channels pulled apart along one angle, each
// smeared over its own stretch: red forward, blue back, green across the
// middle. One pass, a bounded tap count per channel. The smear is a soft
// box, denser toward the unshifted end so the sharp image still reads
// through the fringe. Amount 0 passes through.
const TAPS: i32 = 24;
const MAX_AMOUNT: f32 = 64.0;

struct Params {
    amount: f32, // float — split distance in pixels
    angle: f32,  // float — degrees, 0 horizontal
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let amt = clamp(params.amount, 0.0, MAX_AMOUNT);
    if (amt < 0.5) {
        return src_at(uv);
    }
    let a = radians(params.angle);
    let dir = vec2f(cos(a), sin(a)) * amt * gobofx_globals.texel;
    var red = vec2f(0.0);   // premultiplied red, and the alpha along its path
    var green = vec2f(0.0);
    var blue = vec2f(0.0);
    var wsum = 0.0;
    for (var i = 0; i < TAPS; i++) {
        let t = (f32(i) + 0.5) / f32(TAPS);
        // Heavier near t = 0 so the picture does not go mushy; the tail is
        // the fringe.
        let w = 1.0 - 0.6 * t;
        let r = src_at(uv + dir * t);
        let b = src_at(uv - dir * t);
        let g = src_at(uv + dir * (t - 0.5));
        red += vec2f(r.r, r.a) * w;
        blue += vec2f(b.b, b.a) * w;
        green += vec2f(g.g, g.a) * w;
        wsum += w;
    }
    red /= wsum;
    green /= wsum;
    blue /= wsum;
    // Each channel stays under the alpha it was gathered with, so the union
    // of the three coverages keeps the output premultiplied.
    let alpha = max(max(red.y, green.y), blue.y);
    return vec4f(red.x, green.x, blue.x, alpha);
}
