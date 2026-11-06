// Bulge — spherical bulge (or pinch, for a negative amount) inside a radius.
// The mapping is C1 at the radius, so the edge of the bulge shows no seam.
struct Params {
    center: vec2f, // point
    radius: f32,   // float — in frame heights
    amount: f32,   // float — positive bulges, negative pinches, 0 is a no-op
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
    let n = length(d) / max(params.radius, 0.05);
    let a = clamp(params.amount, -1.0, 1.0);
    // Sample closer to the centre to magnify (bulge), farther to shrink
    // (pinch). (1 - n²)² is 0 with zero slope at n = 1: no seam at the rim.
    let w = 1.0 - n * n;
    let f = select(1.0, 1.0 - a * w * w, n < 1.0);
    return src_at(params.center + d * f / vec2f(aspect, 1.0));
}
