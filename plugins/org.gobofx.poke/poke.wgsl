// Poke — a finger pushed into the picture: inside the radius the pixels are
// shoved out from the point (or drawn in, for a negative amount) with a
// pointed profile, strongest at the centre and fading to nothing at the rim.
// Pixels pulled from outside the frame repeat the edge. Amount 0 is a no-op.
struct Params {
    center: vec2f, // point — where the finger lands
    radius: f32,   // float — in frame heights
    amount: f32,   // float — positive pushes out, negative pulls in, 0 is a no-op
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
    let rad = max(params.radius, 0.05);
    let n = r / rad;
    let a = clamp(params.amount, -1.0, 1.0);
    if (n >= 1.0) {
        return src_at(uv);
    }
    // (1 - n)²: a point at the centre, zero slope at the rim, so the dent is
    // sharp in the middle and seamless at its edge — unlike Bulge's dome.
    let w = (1.0 - n) * (1.0 - n);
    let k = 2.0 * abs(a) * w;
    // Push samples from nearer the centre (the picture spreads out from the
    // finger); pull samples from farther out. Both maps are monotone, so the
    // picture never folds.
    let ns = select(n * (1.0 + k), n / (1.0 + k), a >= 0.0);
    let dir = d / max(r, 1e-6);
    return src_at(params.center + dir * ns * rad / vec2f(aspect, 1.0));
}
