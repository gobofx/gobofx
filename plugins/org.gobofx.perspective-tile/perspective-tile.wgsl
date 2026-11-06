// Perspective Tile — the picture tiled on a floor that recedes to a
// horizon. The bottom row of the frame keeps the flat grid's scale; rows
// above it shrink projectively towards the vanishing line, and the tiles
// narrow at the same rate, as a real plane does. `tilt` pulls the vanishing
// line down from infinity (flat grid) to `horizon`; above the line the
// output is transparent. 1×1 with no tilt passes through.
struct Params {
    columns: i32, // int — tiles across the bottom edge
    rows: i32,    // int — tiles per frame height at the bottom edge's scale
    tilt: f32,    // float — 0 flat, 1 vanishing at the horizon
    horizon: f32, // float — the vanishing line at full tilt, 0 top .. 0.9
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let grid = vec2f(f32(clamp(params.columns, 1, 12)), f32(clamp(params.rows, 1, 12)));
    let t = clamp(params.tilt, 0.0, 1.0);
    let h = clamp(params.horizon, 0.0, 0.9);
    // Projective row map with the bottom edge fixed: denominator (1-h) at the
    // bottom for any tilt, zero on the vanishing line, which sits at `h` when
    // tilt is 1 and climbs out of frame as tilt falls to 0.
    let d = (uv.y - h) * t + (1.0 - h) * (1.0 - t);
    if (d <= 1e-4) {
        return vec4f(0.0);
    }
    let s = (1.0 - h) / d; // 1 at the bottom edge, growing towards the horizon
    let plane = vec2f((uv.x - 0.5) * s + 0.5, (uv.y - 1.0) * s);
    let c = src_at(fract(plane * grid));
    // The last few per cent before the line hold sub-pixel tiles; fade them out
    // rather than shimmer.
    let fade = smoothstep(0.0, 0.08, d / (1.0 - h));
    return c * fade;
}
