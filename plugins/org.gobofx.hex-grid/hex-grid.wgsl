// Hex Grid — hexagonal cells drawn as lines over transparent, with an
// optional fill inside each cell. Signed-distance based, so the lines stay
// crisp at any cell size.
struct Params {
    size: f32,       // float — cell width (flat to flat) in frame heights
    line_width: f32, // float — pixels
    color: vec4f,    // color — the lines, premultiplied
    fill: vec4f,     // color — inside the cells, premultiplied
    center: vec2f,   // point — a cell centre sits here
    angle: f32,      // float — degrees
}
@group(1) @binding(0) var<uniform> params: Params;

// Distance from `p` to the nearest hex edge, for pointy-top hexagons of
// width `s` (flat to flat). Two offset rectangular lattices cover the
// plane; the nearer of the two candidate centres is the cell's.
fn hex_edge_dist(p: vec2f, s: f32) -> f32 {
    let h = s * 0.5;                  // half width (apothem)
    let r = h / 0.86602540378;        // circumradius
    // Rows are 1.5 r apart; one lattice holds the even rows, the other
    // the odd ones, so each lattice repeats every 3 r vertically.
    let step = vec2f(s, 3.0 * r);
    let a = (fract(p / step) - 0.5) * step;
    let b = (fract((p + step * 0.5) / step) - 0.5) * step;
    let q = select(b, a, dot(a, a) < dot(b, b));
    // Hexagon signed distance (pointy top): the max over the three edge
    // normals of the projection minus the apothem.
    let n1 = vec2f(1.0, 0.0);
    let n2 = vec2f(0.5, 0.86602540378);
    let n3 = vec2f(-0.5, 0.86602540378);
    let d = max(abs(dot(q, n1)), max(abs(dot(q, n2)), abs(dot(q, n3))));
    return h - d; // positive inside, 0 on the edge
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let a = radians(params.angle);
    var d = (uv - params.center) * vec2f(aspect, 1.0);
    d = vec2f(d.x * cos(a) + d.y * sin(a), -d.x * sin(a) + d.y * cos(a));
    let size = max(params.size, 0.02);
    let px = gobofx_globals.texel.y;
    let edge = hex_edge_dist(d, size);
    let half_w = max(params.line_width, 0.5) * px * 0.5;
    let aa = 0.75 * px;
    let line = 1.0 - smoothstep(half_w - aa, half_w + aa, edge);
    return mix(params.fill, params.color, line);
}
