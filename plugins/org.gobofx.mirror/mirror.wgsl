// Mirror — reflect one side of the picture onto the other across an axis.
struct Params {
    axis: u32,     // choice — 0 vertical line (left/right), 1 horizontal (top/bottom), 2 both
    position: f32, // float — where the axis sits, 0..1
    keep: u32,     // choice — 0 keep left / top, 1 keep right / bottom
}
@group(1) @binding(0) var<uniform> params: Params;

// Transparent where the reflection runs out of picture (an off-centre axis).
fn src_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0), inside);
}
// Fold one coordinate about `c`, keeping the low side (keep == 0) or the high side.
fn fold(x: f32, c: f32, keep: u32) -> f32 {
    let mirrored = select(x > c, x < c, keep == 1u);
    return select(x, 2.0 * c - x, mirrored);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let c = clamp(params.position, 0.0, 1.0);
    var p = uv;
    if (params.axis == 0u || params.axis == 2u) { p.x = fold(p.x, c, params.keep); }
    if (params.axis == 1u || params.axis == 2u) { p.y = fold(p.y, c, params.keep); }
    return src_at(p);
}
