// Puzzle — `from` breaks into jigsaw pieces that spin off, shrink and fade
// in their own time, revealing `to`. Each piece is its grid cell plus the
// knobs it owns minus the sockets its neighbours' knobs fill; which side
// of an edge owns the knob is a hash of the edge, so both pieces agree.
const PI: f32 = 3.14159265;
const KNOB_OFFSET: f32 = 0.1;  // knob centre beyond the edge, in cells
const KNOB_RADIUS: f32 = 0.16;
const EDGE_V: vec2f = vec2f(0.37, 0.11);
const EDGE_H: vec2f = vec2f(0.71, 0.53);

struct Params {
    columns: i32, // int — pieces across (rows follow, roughly square)
    scatter: f32, // float — how far a piece flies, in cells
    stagger: f32, // float — 0 all pieces together … 1 one after another
    ease: f32,    // float
}
@group(1) @binding(0) var<uniform> params: Params;

fn from_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0), inside);
}
fn to_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0), inside);
}
fn eased(ease: f32) -> f32 {
    let p = clamp(gobofx_globals.progress, 0.0, 1.0);
    return mix(p, smoothstep(0.0, 1.0, p), clamp(ease, 0.0, 1.0));
}
// Premultiplied `over`.
fn over(top: vec4f, bottom: vec4f) -> vec4f {
    return top + bottom * (1.0 - top.a);
}
fn hash21(p: vec2f) -> f32 {
    var q = fract(p * vec2f(123.34, 456.21));
    q = q + dot(q, q + 45.32);
    return fract(q.x * q.y);
}
// Direction 0..3 → the axis coordinate that grows along the wipe.
fn axis(uv: vec2f, direction: u32) -> f32 {
    switch direction {
        case 1u: { return 1.0 - uv.x; }
        case 2u: { return uv.y; }
        case 3u: { return 1.0 - uv.y; }
        default: { return uv.x; }
    }
}
fn dir_vec(direction: u32) -> vec2f {
    switch direction {
        case 1u: { return vec2f(-1.0, 0.0); }
        case 2u: { return vec2f(0.0, 1.0); }
        case 3u: { return vec2f(0.0, -1.0); }
        default: { return vec2f(1.0, 0.0); }
    }
}

fn in_circle(l: vec2f, centre: vec2f) -> bool {
    let q = l - centre;
    return dot(q, q) < KNOB_RADIUS * KNOB_RADIUS;
}
// Is local point `l` (cell units, 0 at the cell centre) on piece `cell`?
fn on_piece(l: vec2f, cell: vec2f, grid: vec2f) -> bool {
    var knob = false;
    var socket = false;
    // Right edge: the edge's hash says whether this piece's knob reaches into the next cell.
    if (cell.x < grid.x - 1.0) {
        let k = hash21(cell + vec2f(1.0, 0.0) + EDGE_V) > 0.5;
        knob = knob || (k && in_circle(l, vec2f(0.5 + KNOB_OFFSET, 0.0)));
        socket = socket || (!k && in_circle(l, vec2f(0.5 - KNOB_OFFSET, 0.0)));
    }
    if (cell.x > 0.0) {
        let k = hash21(cell + EDGE_V) > 0.5; // the left neighbour's knob reaches into this cell
        socket = socket || (k && in_circle(l, vec2f(-0.5 + KNOB_OFFSET, 0.0)));
        knob = knob || (!k && in_circle(l, vec2f(-0.5 - KNOB_OFFSET, 0.0)));
    }
    if (cell.y < grid.y - 1.0) {
        let k = hash21(cell + vec2f(0.0, 1.0) + EDGE_H) > 0.5;
        knob = knob || (k && in_circle(l, vec2f(0.0, 0.5 + KNOB_OFFSET)));
        socket = socket || (!k && in_circle(l, vec2f(0.0, 0.5 - KNOB_OFFSET)));
    }
    if (cell.y > 0.0) {
        let k = hash21(cell + EDGE_H) > 0.5;
        socket = socket || (k && in_circle(l, vec2f(0.0, -0.5 + KNOB_OFFSET)));
        knob = knob || (!k && in_circle(l, vec2f(0.0, -0.5 - KNOB_OFFSET)));
    }
    let in_rect = all(abs(l) <= vec2f(0.5));
    return (in_rect && !socket) || knob;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = eased(params.ease);
    let b = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    if (t <= 0.0) { return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0); }
    if (t >= 1.0) { return b; }
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let cols = f32(clamp(params.columns, 2, 16));
    let rows = max(round(cols / aspect), 1.0);
    let grid = vec2f(cols, rows);
    let g = uv * grid;
    let base = floor(g);
    let st = clamp(params.stagger, 0.0, 1.0);
    let sc = clamp(params.scatter, 0.0, 1.0);
    var top = vec4f(0.0);
    // A piece never reaches further than one cell from its centre (it shrinks
    // as it flies), so the 3×3 neighbourhood holds every piece that can cover this pixel.
    for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
            let cell = base + vec2f(f32(dx), f32(dy));
            if (any(cell < vec2f(0.0)) || any(cell >= grid)) { continue; }
            let order = hash21(cell + 0.5);
            let lt = clamp(t * (1.0 + st) - order * st, 0.0, 1.0);
            let scale = 1.0 - lt;
            let alpha = 1.0 - smoothstep(0.5, 1.0, lt);
            if (scale < 1e-3 || alpha <= 0.0) { continue; }
            let fly = hash21(cell + 7.3) * 2.0 * PI;
            let disp = vec2f(cos(fly), sin(fly)) * sc * lt;
            let ang = (hash21(cell + 3.1) - 0.5) * PI * lt;
            var l = g - (cell + 0.5) - disp;
            l = vec2f(l.x * cos(ang) + l.y * sin(ang), -l.x * sin(ang) + l.y * cos(ang)) / scale;
            if (on_piece(l, cell, grid)) {
                let src = (cell + 0.5 + l) / grid;
                top = over(top, from_at(src) * alpha);
            }
        }
    }
    return over(top, b);
}
