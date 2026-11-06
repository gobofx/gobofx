// Hex Lens — a compound eye: the frame is tiled with hexagonal cells and
// each cell is a small lens that magnifies the picture under it. The facet
// joints are shaded faintly so the cells read on flat colour. Pixels pulled
// from outside the frame repeat the edge. Amount 0 is a no-op.
struct Params {
    size: f32,   // float — cell size, centre to centre, in frame heights
    amount: f32, // float — lens strength, 0 is a no-op
}
@group(1) @binding(0) var<uniform> params: Params;

// Clamp-to-edge: a pixel pulled from outside the frame repeats the edge.
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}
// Nearest centre of a pointy-top hex grid whose neighbours are 1 apart: two
// rectangular lattices offset by half a cell, pick the closer point.
fn hex_center(p: vec2f) -> vec2f {
    let r = vec2f(1.0, 1.7320508);
    let h = r * 0.5;
    let a = round(p / r) * r;
    let b = round((p - h) / r) * r + h;
    return select(b, a, length(p - a) < length(p - b));
}
// Hexagonal distance from a cell centre: 0.5 on the cell's boundary.
fn hex_dist(p: vec2f) -> f32 {
    let q = abs(p);
    return max(q.x, 0.5 * q.x + 0.8660254 * q.y);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let size = max(params.size, 0.02);
    let a = clamp(params.amount, 0.0, 1.0);
    let p = uv * vec2f(aspect, 1.0) / size;
    let c = hex_center(p);
    let d = p - c;
    // Each cell is a bulge: sample closer to its centre to magnify. The
    // profile has zero slope at the circumradius, so the vertices are seamless;
    // the small step left at the edge midpoints is the facet joint.
    let n = min(length(d) / 0.57735, 1.0);
    let w = 1.0 - n * n;
    let f = 1.0 - a * w * w;
    let col = src_at((c + d * f) * size / vec2f(aspect, 1.0));
    // Facet lines: exactly 1 at amount 0, never above 1, so premultiplied
    // colour stays within alpha.
    let joint = smoothstep(0.42, 0.5, hex_dist(d));
    let shade = 1.0 - 0.3 * a * joint;
    return vec4f(col.rgb * shade, col.a);
}
