// Mosaic — the frame is a grid of tiles; each flips from `from` to `to`
// in its own time.
struct Params {
    columns: i32, // int
    rows: i32,    // int — 0 derives square tiles
    stagger: f32, // float — 0 all tiles together … 1 one after another
    order: u32,   // choice — 0 diagonal sweep, 1 random, 2 row by row
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

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = eased(params.ease);
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let cols = f32(clamp(params.columns, 2, 32));
    let rows = select(f32(clamp(params.rows, 1, 32)), round(cols / aspect), params.rows <= 0);
    let g = uv * vec2f(cols, rows);
    let cell = floor(g);
    var order: f32;
    switch params.order {
        case 1u: { order = hash21(cell + 0.5); }
        case 2u: { order = cell.y / max(rows - 1.0, 1.0); }
        default: { order = (cell.x + cell.y) / max(cols + rows - 2.0, 1.0); }
    }
    let st = clamp(params.stagger, 0.0, 1.0);
    let lt = clamp(t * (1.0 + st) - order * st, 0.0, 1.0);
    // Flip the tile about its vertical centre line.
    let theta = lt * 3.14159265;
    let c = cos(theta);
    let local = fract(g) - 0.5;
    if (abs(c) < 1e-4) { return vec4f(0.0); }
    let u = local.x / c;
    if (abs(u) > 0.5) { return vec4f(0.0); }
    let src = (cell + vec2f(u + 0.5, local.y + 0.5)) / vec2f(cols, rows);
    if (c > 0.0) {
        return textureSampleLevel(gobofx_input0, gobofx_sampler, src, 0.0);
    }
    let back = (cell + vec2f(0.5 - u, local.y + 0.5)) / vec2f(cols, rows);
    return textureSampleLevel(gobofx_input1, gobofx_sampler, back, 0.0);
}
