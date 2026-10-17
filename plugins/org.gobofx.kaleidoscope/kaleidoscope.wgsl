// Kaleidoscope — the keyboard picks how far the picture folds.
// `key` (notes C1–B1, mode pitch) chooses the segment count between
// `min_segments` and `max_segments`; it latches. `held` (same keys, gate)
// mixes the fold in, so a kick drum or a held key opens it and the release
// closes it. `spin` (cc 1) rotates, `bend` zooms in and out.

struct Params {
    min_segments: i32,
    max_segments: i32,
    zoom: f32,
    bend_zoom: f32,
    center: vec2f,
}
@group(1) @binding(0) var<uniform> params: Params;

struct Signals {
    key: f32,   // 0..1 across C1–B1, latched
    held: f32,  // 0..1 with release
    spin: f32,  // 0..1 → one full turn
    bend: f32,  // 0.5 at rest
}
@group(1) @binding(1) var<uniform> gobofx_signals: Signals;

const PI = 3.14159265359;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let segf = mix(f32(params.min_segments), f32(params.max_segments), gobofx_signals.key);
    let segments = max(round(segf), 1.0);

    // Polar coordinates around the centre, in a square space so wedges are even.
    var d = (uv - params.center) * vec2f(aspect, 1.0);
    let zoom = params.zoom * exp2((gobofx_signals.bend - 0.5) * 2.0 * params.bend_zoom);
    d = d / zoom;
    let r = length(d);
    var ang = atan2(d.y, d.x) + gobofx_signals.spin * 2.0 * PI;

    // Fold the angle into one wedge and mirror every other wedge.
    let wedge = 2.0 * PI / segments;
    ang = ang - wedge * floor(ang / wedge);          // 0..wedge
    ang = abs(ang - wedge * 0.5);                    // mirrored, 0..wedge/2

    let folded = params.center + vec2f(cos(ang), sin(ang)) * r / vec2f(aspect, 1.0);
    // Mirror-repeat so the sample never leaves the picture.
    let m = abs(fract(folded * 0.5) * 2.0 - 1.0);

    let a = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    let k = textureSampleLevel(gobofx_input0, gobofx_sampler, m, 0.0);
    return mix(a, k, gobofx_signals.held);
}
