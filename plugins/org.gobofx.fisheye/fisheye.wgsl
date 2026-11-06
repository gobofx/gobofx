// Fisheye — wide-angle barrel distortion: straight lines bow outward and the
// corners pull in. The corners the lens cannot reach are transparent; `zoom`
// scales the picture up to hide them.
struct Params {
    center: vec2f, // point — the optical axis
    amount: f32,   // float — 0 is a no-op, 1 a full barrel
    zoom: f32,     // float — 1 shows the pulled-in edges, 2 hides them
}
@group(1) @binding(0) var<uniform> params: Params;

// Transparent outside the frame.
fn src_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0), inside);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    // Radius normalised so the frame corner sits at 1.
    let half_diag = 0.5 * length(vec2f(aspect, 1.0));
    let q = (uv - params.center) * vec2f(aspect, 1.0) / max(params.zoom, 1.0);
    let rn = length(q) / half_diag;
    let k = clamp(params.amount, 0.0, 1.0);
    // Barrel: the source is sampled farther out than the output pixel, more
    // so towards the corners, so the edges compress and bow.
    let suv = params.center + q * (1.0 + k * rn * rn) / vec2f(aspect, 1.0);
    return src_at(suv);
}
