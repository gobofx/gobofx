// Crystallize — the picture as Voronoi crystal cells: one jittered point per
// grid cell, every pixel takes the colour of its nearest point's cell, and
// the borders between cells are darkened like the facets of a crystal.
struct Params {
    size: f32,   // float — average cell size in pixels
    edge: f32,   // float — how dark the cell borders are, 0 none, 1 black lines
    seed: f32,   // float — reshuffles the cell layout
    amount: f32, // float — 0 is the source, 1 the full effect
}
@group(1) @binding(0) var<uniform> params: Params;

fn hash21(p: vec2f) -> f32 {
    var q = fract(p * vec2f(123.34, 456.21));
    q = q + dot(q, q + 45.32);
    return fract(q.x * q.y);
}
fn hash22(p: vec2f) -> vec2f {
    return vec2f(hash21(p), hash21(p + vec2f(31.7, 17.3)));
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

// The cell's colour: an average of five taps around its point, so a cell
// reads as the area it covers rather than one pixel of it (premultiplied).
fn cell_colour(centre_px: vec2f, s: f32) -> vec4f {
    let res = gobofx_globals.resolution;
    let r = s * 0.25;
    var acc = src_at(centre_px / res);
    acc += src_at((centre_px + vec2f(r, 0.0)) / res);
    acc += src_at((centre_px - vec2f(r, 0.0)) / res);
    acc += src_at((centre_px + vec2f(0.0, r)) / res);
    acc += src_at((centre_px - vec2f(0.0, r)) / res);
    return acc / 5.0;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let res = gobofx_globals.resolution;
    let s = clamp(params.size, 4.0, 128.0);
    let g = uv * res / s;
    let i = floor(g);
    let f = g - i;
    let seed = vec2f(params.seed * 7.13, params.seed * 3.71);
    // Nearest and second-nearest jittered points over the 3×3 neighbourhood.
    var d1 = 1e9;
    var d2 = 1e9;
    var p1 = vec2f(0.0);
    for (var y = -1; y <= 1; y++) {
        for (var x = -1; x <= 1; x++) {
            let o = vec2f(f32(x), f32(y));
            let pt = o + hash22(i + o + seed);
            let d = dot(pt - f, pt - f);
            if (d < d1) {
                d2 = d1;
                d1 = d;
                p1 = pt;
            } else if (d < d2) {
                d2 = d;
            }
        }
    }
    let crystal = cell_colour((i + p1) * s, s);
    // A border where the two nearest points are nearly equidistant; its
    // width is fixed in pixels so it stays a line at any cell size.
    let gap = (sqrt(d2) - sqrt(d1)) * s;
    let border = 1.0 - smoothstep(0.0, 2.5, gap);
    let shade = 1.0 - clamp(params.edge, 0.0, 1.0) * border;
    let faceted = vec4f(crystal.rgb * shade, crystal.a);
    let src = src_at(uv);
    return mix(src, faceted, clamp(params.amount, 0.0, 1.0));
}
