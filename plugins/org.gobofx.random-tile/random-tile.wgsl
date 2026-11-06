// Random Tile — the picture cut into a grid and the tiles shuffled. The
// shuffle is a true permutation (every source tile appears exactly once),
// built from a seeded Feistel network over the tile index with cycle
// walking for grids that are not a power of two, so a seed is a fixed
// arrangement, not a random pick. With `flip` on, each tile may also be
// mirrored. 1×1 without flip passes through.
struct Params {
    columns: i32, // int
    rows: i32,    // int
    seed: i32,    // int — picks the arrangement
    flip: u32,    // bool — mirror tiles at random too
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

fn ihash(v: u32) -> u32 {
    var h = v;
    h ^= h >> 16u;
    h *= 0x7feb352du;
    h ^= h >> 15u;
    h *= 0x846ca68bu;
    h ^= h >> 16u;
    return h;
}

// A permutation of 0..n (n ≤ 144): a 4-round Feistel over the smallest
// even-bit domain holding n, walked until the image lands below n. The
// walk is bounded; the fallback (identity) is reached with vanishing odds.
fn permute(i: u32, n: u32, seed: u32) -> u32 {
    if (n <= 1u) {
        return 0u;
    }
    var k = 2u;
    for (var j = 0; j < 4; j++) {
        if ((1u << k) < n) {
            k += 2u;
        }
    }
    let hb = k / 2u;
    let mask = (1u << hb) - 1u;
    var x = i;
    for (var walk = 0; walk < 32; walk++) {
        var l = x >> hb;
        var r = x & mask;
        for (var round = 0u; round < 4u; round++) {
            let f = ihash(r ^ (seed * 0x9e3779b9u) ^ (round * 0x85ebca6bu)) & mask;
            let nl = r;
            let nr = l ^ f;
            l = nl;
            r = nr;
        }
        x = (l << hb) | r;
        if (x < n) {
            return x;
        }
    }
    return i;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let cols = clamp(params.columns, 1, 12);
    let rows = clamp(params.rows, 1, 12);
    let grid = vec2f(f32(cols), f32(rows));
    let cell = uv * grid;
    let idx = clamp(vec2i(floor(cell)), vec2i(0), vec2i(cols - 1, rows - 1));
    var local = fract(cell);
    let n = u32(cols * rows);
    let seed = u32(clamp(params.seed, 0, 99));
    let i = u32(idx.y * cols + idx.x);
    let j = permute(i, n, seed);
    if (params.flip == 1u) {
        let bits = ihash(i * 0x27d4eb2fu + seed * 0x165667b1u + 1u);
        local.x = select(local.x, 1.0 - local.x, (bits & 1u) == 1u);
        local.y = select(local.y, 1.0 - local.y, (bits & 2u) == 2u);
    }
    let src_cell = vec2f(f32(j % u32(cols)), f32(j / u32(cols)));
    return src_at((src_cell + local) / grid);
}
