// Sliced Scale — 9-slice scaling: the four corner squares keep their pixel
// size, the four edge bands stretch along one axis only, and the middle
// stretches both ways. The scaled picture is centred in the frame; outside
// it the frame is transparent. Scale 1, 1 is a no-op.
struct Params {
    scale_x: f32, // float — 1 is a no-op
    scale_y: f32, // float — 1 is a no-op
    corner: f32,  // float — pixels, the size of the corner squares kept as is
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

// Map one axis of the scaled rectangle (q in 0..size_out) back to the source
// (0..size_in): corners fixed, the middle stretched.
fn slice(q: f32, size_in: f32, size_out: f32, c: f32) -> f32 {
    if (q < c) { return q; }
    if (q > size_out - c) { return size_in - (size_out - q); }
    return c + (q - c) * (size_in - 2.0 * c) / (size_out - 2.0 * c);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let res = gobofx_globals.resolution;
    let s = clamp(vec2f(params.scale_x, params.scale_y), vec2f(0.1), vec2f(3.0));
    let size_out = res * s;
    // Pixel in the scaled rectangle, centred in the frame.
    let q = uv * res - (res - size_out) * 0.5;
    let inside = all(q >= vec2f(0.0)) && all(q <= size_out);
    // A corner can never take more than half of the smaller of the two
    // rectangles, or the slices would overlap.
    let c = max(params.corner, 0.0);
    let cx = min(c, 0.5 * min(res.x, size_out.x));
    let cy = min(c, 0.5 * min(res.y, size_out.y));
    let p = vec2f(slice(q.x, res.x, size_out.x, cx), slice(q.y, res.y, size_out.y, cy));
    return select(vec4f(0.0), src_at(p / res), inside);
}
