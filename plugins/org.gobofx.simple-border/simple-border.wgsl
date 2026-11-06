// Simple Border — a solid frame along the picture's edge. Inset draws the
// frame over the outer pixels; off, the picture is scaled down to fit
// inside it. The inner corners can be rounded. Width 0 passes through.
struct Params {
    width: f32,         // float — frame width in pixels
    color: vec4f,       // color — the frame, premultiplied
    corner_radius: f32, // float — radius of the frame's inner corners in pixels
    inset: u32,         // bool — 1 frame covers the edge, 0 picture shrinks to fit
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}
// Signed distance to a rounded box of half-size `b` and corner radius `r`,
// centred on the origin.
fn sd_round_box(p: vec2f, b: vec2f, r: f32) -> f32 {
    let q = abs(p) - b + vec2f(r);
    return length(max(q, vec2f(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let res = gobofx_globals.resolution;
    let half = res * 0.5;
    let w = clamp(params.width, 0.0, min(half.x, half.y));
    let inner = half - vec2f(w);
    let r = min(clamp(params.corner_radius, 0.0, 128.0), min(inner.x, inner.y));
    let p = uv * res - half;
    // Coverage of the frame at this pixel, antialiased over one pixel.
    let d = sd_round_box(p, inner, r);
    let frame = smoothstep(-0.5, 0.5, d);
    var picture: vec4f;
    if (params.inset == 1u) {
        picture = src_at(uv);
    } else {
        picture = src_at((p + inner) / (2.0 * inner));
    }
    // The frame goes over the picture with its own alpha, premultiplied.
    let top = params.color * frame;
    return top + picture * (1.0 - top.a);
}
