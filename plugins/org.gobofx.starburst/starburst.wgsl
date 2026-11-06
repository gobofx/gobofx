// Starburst — radial streaks bursting from a point: inside each of `count`
// wedges the picture is smeared outward along the ray from the centre, and
// between the wedges it is left alone. Amount mixes the streaks over the
// source; 0 is a no-op. Samples pulled from outside the frame repeat the
// edge.
const TAU: f32 = 6.28318530718;
const TAPS: i32 = 24;

struct Params {
    center: vec2f, // point — where the streaks come from
    count: i32,    // int — number of streaks around the centre
    length: f32,   // float — streak length in frame heights
    amount: f32,   // float — 0 is a no-op, 1 full streaks
}
@group(1) @binding(0) var<uniform> params: Params;

// Clamp-to-edge: a sample from outside the frame repeats the edge.
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let d = (uv - params.center) * vec2f(aspect, 1.0);
    let r = length(d);
    let dir = select(vec2f(1.0, 0.0), d / r, r > 1e-5);
    let src = src_at(uv);
    // Wedge mask: a cosine lobe per streak, sharpened so the gaps stay clean.
    let n = f32(clamp(params.count, 2, 32));
    let theta = atan2(dir.y, dir.x);
    let lobe = 0.5 + 0.5 * cos(theta * n);
    let mask = smoothstep(0.25, 0.9, lobe);
    // Smear outward: average the picture along the ray behind this pixel
    // (towards the centre), so the streak drags the centre's colour out.
    let len = clamp(params.length, 0.02, 1.0);
    let step = dir * len / f32(TAPS) / vec2f(aspect, 1.0);
    var acc = vec4f(0.0);
    for (var i = 0; i < TAPS; i++) {
        acc += src_at(uv - step * f32(i));
    }
    let streak = acc / f32(TAPS);
    let a = clamp(params.amount, 0.0, 1.0);
    return mix(src, streak, a * mask);
}
