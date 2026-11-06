// Stretch Mirror — a funhouse mirror: bands across the frame alternately
// stretch and squeeze the picture along one axis. The frame's edges and its
// centre line stay pinned, so nothing is pulled from outside the frame.
// Amount 0 is a no-op.
const TAU: f32 = 6.28318530718;

struct Params {
    waves: f32,  // float — stretch/squeeze cycles across the frame
    amount: f32, // float — 0 is a no-op, 1 the strongest the map allows
    axis: u32,   // choice — 0 stretch left/right (bands stacked top to bottom), 1 stretch up/down
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let a = clamp(params.amount, 0.0, 1.0);
    let w = clamp(params.waves, 0.25, 12.0);
    // Work with x as the stretched axis and y as the band axis.
    var p = uv;
    if (params.axis == 1u) { p = uv.yx; }
    // Each band picks k in -1..1. The map s(x) = x + k sin(2πx) / 2π has slope
    // 1 + k cos(2πx): k > 0 magnifies the middle and squeezes the edges, k < 0
    // the reverse. It pins 0, ½ and 1 and stays monotone for |k| ≤ 1, so the
    // picture never folds and never leaves the frame.
    let k = a * sin(TAU * w * p.y);
    var s = vec2f(p.x + k * sin(TAU * p.x) / TAU, p.y);
    if (params.axis == 1u) { s = s.yx; }
    return src_at(s);
}
