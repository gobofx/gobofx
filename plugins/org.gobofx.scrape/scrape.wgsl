// Scrape — smear the picture from one edge inward: the line of pixels at
// `position` is dragged towards the chosen edge, stretching everything in
// between. At Amount 1 the strip is that one line repeated; at 0 it is a
// no-op. Samples never leave the frame, so there is no edge policy to pick.
struct Params {
    edge: u32,     // choice — 0 left, 1 right, 2 top, 3 bottom
    position: f32, // float — where the smear starts, 0..1 across the frame
    amount: f32,   // float — 0 is a no-op, 1 a full smear
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

// Pull `x` towards the line at `pos` when it lies on the edge side of it.
// `low` is true when the edge is at coordinate 0 (left or top).
fn drag(x: f32, pos: f32, low: bool, keep: f32) -> f32 {
    let in_strip = select(x > pos, x < pos, low);
    return select(x, pos + (x - pos) * keep, in_strip);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let pos = clamp(params.position, 0.0, 1.0);
    let keep = 1.0 - clamp(params.amount, 0.0, 1.0);
    var p = uv;
    switch (params.edge) {
        case 0u: { p.x = drag(uv.x, pos, true, keep); }
        case 1u: { p.x = drag(uv.x, 1.0 - pos, false, keep); }
        case 2u: { p.y = drag(uv.y, pos, true, keep); }
        default: { p.y = drag(uv.y, 1.0 - pos, false, keep); }
    }
    return src_at(p);
}
