// Ring Lens — a ring-shaped lens: between the inner and the outer radius the
// picture is magnified towards the ring's midline (or shrunk, for a negative
// amount). Inside the inner radius and outside the outer the picture is
// untouched, and both edges are seamless. Pixels pulled from outside the
// frame repeat the edge. Amount 0 is a no-op.
struct Params {
    center: vec2f, // point
    inner: f32,    // float — inner radius, in frame heights
    outer: f32,    // float — outer radius, in frame heights
    amount: f32,   // float — positive magnifies the ring, negative shrinks, 0 is a no-op
}
@group(1) @binding(0) var<uniform> params: Params;

// Clamp-to-edge: a pixel pulled from outside the frame repeats the edge.
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let d = (uv - params.center) * vec2f(aspect, 1.0);
    let r = length(d);
    let ri = max(params.inner, 0.0);
    let ro = max(params.outer, ri + 0.02);
    let mid = 0.5 * (ri + ro);
    let half = 0.5 * (ro - ri);
    let n = (r - mid) / half; // -1 on the inner edge, 1 on the outer
    let a = clamp(params.amount, -1.0, 1.0);
    if (abs(n) >= 1.0) {
        return src_at(uv);
    }
    // A bulge across the ring's width: sample towards the midline to magnify.
    // (1 - n²)² is 0 with zero slope at both edges, so neither shows a seam,
    // and the map stays monotone for |amount| ≤ 1.
    let w = 1.0 - n * n;
    let rs = mid + (r - mid) * (1.0 - a * w * w);
    let dir = d / max(r, 1e-6);
    return src_at(params.center + dir * rs / vec2f(aspect, 1.0));
}
