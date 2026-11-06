// Multi-Flip — a grid of tiles, each a card with `from` on the front and `to`
// on the back, turns over in a wave that spreads out from a chosen point.
struct Params {
    columns: i32,     // int
    rows: i32,        // int — 0 derives square tiles
    axis: u32,        // choice — 0 vertical, 1 horizontal, 2 alternate per tile
    origin: vec2f,    // point — where the wave starts
    stagger: f32,     // float — 0 all tiles together … 1 a slow wave
    perspective: f32, // float — foreshortening of each turning tile
    ease: f32,        // float
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

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = eased(params.ease);
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let cols = f32(clamp(params.columns, 2, 32));
    let rows = select(f32(clamp(params.rows, 1, 32)), max(1.0, round(cols / aspect)), params.rows <= 0);
    let dims = vec2f(cols, rows);
    let g = uv * dims;
    let cell = floor(g);
    let local = fract(g) - 0.5;
    // Order the tiles by distance from the origin, normalised to the farthest corner.
    let scale = vec2f(aspect, 1.0);
    let o = clamp(params.origin, vec2f(0.0), vec2f(1.0)) * scale;
    let far = max(max(length(o), length(o - vec2f(aspect, 0.0))),
                  max(length(o - vec2f(0.0, 1.0)), length(o - scale)));
    let centre = (cell + 0.5) / dims * scale;
    let order = length(centre - o) / max(far, 1e-4);
    let st = clamp(params.stagger, 0.0, 1.0);
    let lt = clamp(t * (1.0 + st) - order * st, 0.0, 1.0);
    let theta = lt * 3.14159265;
    let c = cos(theta);
    let s = sin(theta);
    var horizontal = params.axis == 1u;
    if (params.axis == 2u) { horizontal = ((i32(cell.x) + i32(cell.y)) & 1) == 1; }
    var p = local;
    if (horizontal) { p = vec2f(p.y, p.x); }
    if (abs(c) < 1e-4) { return vec4f(0.0); } // edge-on
    let u = p.x / c;
    let k = clamp(params.perspective, 0.0, 1.0) * 0.8;
    let v = p.y / (1.0 + k * u * s);
    if (abs(u) > 0.5 || abs(v) > 0.5) { return vec4f(0.0); }
    var face = vec2f(u, v) + 0.5;
    if (c > 0.0) {
        if (horizontal) { face = vec2f(face.y, face.x); }
        return from_at((cell + face) / dims);
    }
    // Back face: mirrored along the turning axis so `to` reads correctly once flat.
    face.x = 1.0 - face.x;
    if (horizontal) { face = vec2f(face.y, face.x); }
    return to_at((cell + face) / dims);
}
