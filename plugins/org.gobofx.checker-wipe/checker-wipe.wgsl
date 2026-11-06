// Checker Wipe — a checkerboard of cells dissolves to `to`, the two
// colours of the board in turn.
struct Params {
    columns: i32,  // int
    rows: i32,     // int — 0 derives square cells
    spread: f32,   // float — how far apart in time the two sets of cells change
    jitter: f32,   // float — randomises each cell's moment
    softness: f32, // float — 0 hard cell edges … 1 each cell fades
    ease: f32,     // float
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
    let a = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    let b = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let cols = f32(clamp(params.columns, 2, 32));
    let rows = select(f32(clamp(params.rows, 1, 32)), round(cols / aspect), params.rows <= 0);
    let cell = floor(uv * vec2f(cols, rows));
    let parity = f32((i32(cell.x) + i32(cell.y)) & 1);
    let delay = clamp(parity * 0.5 + (hash21(cell + 0.5) - 0.5) * clamp(params.jitter, 0.0, 1.0) * 0.5, 0.0, 1.0);
    let spread = clamp(params.spread, 0.0, 0.9);
    let t = eased(params.ease);
    let lt = clamp((t - delay * spread) / (1.0 - spread), 0.0, 1.0);
    // Within a cell: either a hard flip at lt = 0.5 or a fade, per softness.
    let w = clamp(params.softness, 0.0, 1.0) * 0.5 + 1e-4;
    let k = smoothstep(0.5 - w, 0.5 + w, lt);
    return mix(a, b, k);
}
