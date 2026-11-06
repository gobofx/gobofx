// Clone Spin — the frame splits into tiles; each spins in place, becoming a
// small copy of the whole of `from` as it turns, and shrinks away into `to`.
struct Params {
    grid: i32,    // int — tiles across; rows follow the aspect
    turns: f32,   // float — full rotations per tile
    stagger: f32, // float — 0 all tiles together … 1 a diagonal wave
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
fn rot(p: vec2f, a: f32) -> vec2f {
    let c = cos(a);
    let s = sin(a);
    return vec2f(c * p.x - s * p.y, s * p.x + c * p.y);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = eased(params.ease);
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let cols = f32(clamp(params.grid, 2, 12));
    let rows = max(1.0, round(cols / aspect));
    let dims = vec2f(cols, rows);
    let g = uv * dims;
    let cell = floor(g);
    let local = fract(g);
    // A diagonal wave from the top-left corner; stagger 1 keeps a little overlap.
    let order = (cell.x + cell.y) / max(cols + rows - 2.0, 1.0);
    let st = clamp(params.stagger, 0.0, 1.0) * 0.9;
    let lt = clamp((t - order * st) / (1.0 - st), 0.0, 1.0);
    let bg = to_at(uv) * smoothstep(0.25, 0.6, t);
    let shrink = 1.0 - smoothstep(0.5, 1.0, lt);
    if (shrink <= 1e-4) { return bg; }
    // Spin in the tile's own pixel space so the turn is round, not sheared.
    let size = vec2f(aspect, 1.0) / dims;
    let theta = clamp(params.turns, 0.25, 3.0) * 6.2831853 * lt;
    let q = rot((local - 0.5) * size, -theta) / size;
    let h = 0.5 * shrink;
    if (any(abs(q) >= vec2f(h))) { return bg; }
    let inner = 0.5 + q / (2.0 * h);
    // The tile starts as its own crop of the frame and zooms out to a whole copy.
    let zoom = smoothstep(0.0, 0.5, lt);
    let src = mix((cell + inner) / dims, inner, zoom);
    return over(from_at(src), bg);
}
