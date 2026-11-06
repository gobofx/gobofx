// Disc Warp — the whole frame wrapped into a disc. Every ray from the centre
// is stretched so the frame's edge lands on the disc's rim, the corners
// pulled furthest. Outside the disc the frame is transparent. Amount blends
// from the flat frame (0, a no-op) to the full disc (1).
struct Params {
    center: vec2f, // point — the disc's centre
    radius: f32,   // float — the disc's radius, in frame heights
    amount: f32,   // float — 0 is a no-op, 1 the full disc
}
@group(1) @binding(0) var<uniform> params: Params;

// Transparent outside the frame.
fn src_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0), inside);
}
// Keep a near-zero direction component finite for the ray/edge division.
fn safe(x: f32) -> f32 {
    return select(x, 1e-6, abs(x) < 1e-6);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let size = vec2f(aspect, 1.0);
    let c = clamp(params.center, vec2f(0.01), vec2f(0.99));
    let rad = max(params.radius, 0.05);
    let a = clamp(params.amount, 0.0, 1.0);
    // Disc units: the rim is at 1.
    let d = (uv - c) * size / rad;
    let r = length(d);
    let v = d / max(r, 1e-6);
    // Where this ray leaves the frame, in disc units.
    let lo = -c * size / rad;
    let hi = (1.0 - c) * size / rad;
    let tx = select(hi.x, lo.x, v.x < 0.0) / safe(v.x);
    let ty = select(hi.y, lo.y, v.y < 0.0) / safe(v.y);
    let frame = min(tx, ty);
    // At 1 the rim meets the frame's edge; at 0 the ray is left alone.
    let stretch = mix(1.0, frame, a);
    let col = src_at(c + v * r * stretch * rad / size);
    // One pixel of anti-aliasing on the disc's rim. Pixel centres inside the
    // frame are at least half a pixel from its edge, so at amount 0 this is 1.
    let px = gobofx_globals.texel.y / rad;
    let cover = clamp((frame / stretch - r) / px + 0.5, 0.0, 1.0);
    return col * cover;
}
