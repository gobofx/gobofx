// Parallelogram Tile — the picture repeated on a sheared grid. The grid is
// skewed so each tile is a parallelogram leaning by `skew` tiles per tile
// of height, and the picture inside each tile leans with it. 1×1 with no
// skew passes through.
struct Params {
    columns: i32, // int
    rows: i32,    // int
    skew: f32,    // float — lean, in tile widths per tile height
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let grid = vec2f(f32(clamp(params.columns, 1, 12)), f32(clamp(params.rows, 1, 12)));
    var cell = uv * grid;
    // The shear is continuous in y, so the tile edges lean rather than step.
    cell.x += clamp(params.skew, -1.0, 1.0) * cell.y;
    return src_at(fract(cell));
}
