// Shake — hand-held camera shake: the frame jitters and tilts along a
// smooth noise curve driven by time. Same time, same frame: the noise is a
// hash of the time step and the seed, so renders are deterministic.
struct Params {
    amplitude: f32, // float — pixels of travel
    frequency: f32, // float — jolts per second
    rotation: f32,  // float — degrees of tilt
    seed: i32,      // int — picks a different curve
}
@group(1) @binding(0) var<uniform> params: Params;

fn hash21(p: vec2f) -> f32 {
    var q = fract(p * vec2f(123.34, 456.21));
    q = q + dot(q, q + 45.32);
    return fract(q.x * q.y);
}
// Smooth value noise in -1..1 along t; `s` separates the axes and seeds.
fn vnoise(t: f32, s: f32) -> f32 {
    let i = floor(t);
    let f = t - i;
    let u = f * f * (3.0 - 2.0 * f);
    return mix(hash21(vec2f(i, s)), hash21(vec2f(i + 1.0, s)), u) * 2.0 - 1.0;
}
// Two octaves: the slow sway of a body plus a faster tremor on top.
fn shake(t: f32, s: f32) -> f32 {
    return vnoise(t, s) * 0.75 + vnoise(t * 2.7 + 13.0, s + 7.0) * 0.25;
}
// Transparent outside the frame: what the move uncovers is empty, so the
// host shows whatever lies beneath.
fn src_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0), inside);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = gobofx_globals.time * max(params.frequency, 0.0);
    let s = f32(params.seed) * 0.37;
    let off = vec2f(shake(t, s + 1.3), shake(t, s + 2.7)) * params.amplitude;
    let ang = radians(params.rotation) * shake(t, s + 4.1);
    // Work in pixels about the frame centre, then invert the camera move:
    // the picture moved by `off` and tilted by `ang`, so sample the reverse.
    let res = gobofx_globals.resolution;
    let p = (uv - 0.5) * res - off;
    let c = cos(ang);
    let sn = sin(ang);
    let q = vec2f(p.x * c + p.y * sn, -p.x * sn + p.y * c);
    return src_at(q / res + 0.5);
}
