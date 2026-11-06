// Tile — the picture repeated on a grid. Every other tile can be mirrored
// so the seams vanish, alternate rows can be shifted like brickwork, and a
// gap leaves transparent gutters between the tiles. 1×1 passes through.
struct Params {
    columns: i32, // int
    rows: i32,    // int
    mirror: u32,  // bool — flip every other tile
    offset: f32,  // float — shift of odd rows, in tiles
    gap: f32,     // float — transparent gutter between tiles, in pixels
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let grid = vec2f(f32(clamp(params.columns, 1, 12)), f32(clamp(params.rows, 1, 12)));
    var cell = uv * grid;
    // Brickwork: odd rows slide along by `offset` tiles.
    let row = floor(cell.y);
    let odd_row = row - 2.0 * floor(row * 0.5);
    cell.x += clamp(params.offset, -0.5, 0.5) * odd_row;
    let index = floor(cell);
    var local = fract(cell);
    if (params.mirror == 1u) {
        let odd = index - 2.0 * floor(index * 0.5);
        local = mix(local, 1.0 - local, odd);
    }
    // The gap is centred on each seam, measured in pixels of the output.
    let gap_tiles = clamp(params.gap, 0.0, 32.0) * gobofx_globals.texel * grid * 0.5;
    let in_gap = any(local < gap_tiles) || any(local > 1.0 - gap_tiles);
    let c = src_at(local);
    return select(c, vec4f(0.0), in_gap);
}
