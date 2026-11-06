// Dot Grid — the picture as a grid of equal round dots, each the colour of
// the picture at its centre, on a background colour. Unlike a halftone the
// dots never change size with tone; the colour carries the image.
struct Params {
    size: f32,          // float — grid pitch in pixels (dot-centre spacing)
    dot_size: f32,      // float — dot diameter as a fraction of the pitch, 0..1
    background: vec4f,  // color — between the dots (premultiplied)
    amount: f32,        // float — 0 is the source, 1 is the full grid
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let res = gobofx_globals.resolution;
    let px = uv * res;
    let s = clamp(params.size, 2.0, 64.0);
    let centre = (floor(px / s) + 0.5) * s;
    let dist = distance(px, centre);
    let r = clamp(params.dot_size, 0.0, 1.0) * s * 0.5;
    let cover = 1.0 - smoothstep(r - 0.7, r + 0.7, dist);
    // One colour per cell, read at the dot's centre (premultiplied, so a
    // transparent cell draws nothing — the grid keeps the source's shape).
    let dot = src_at(centre / res);
    let grid = mix(params.background * dot.a, dot, cover);
    let src = src_at(uv);
    return mix(src, grid, clamp(params.amount, 0.0, 1.0));
}
