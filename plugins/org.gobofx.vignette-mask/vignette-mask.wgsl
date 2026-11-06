// Vignette Mask — keep the picture inside a soft ellipse, transparent
// outside. Size is the ellipse width as a fraction of the frame width and
// Aspect its height over its width, so the default is a wide, horizontal
// oval; Feather is measured in frame heights so it looks the same at any
// aspect ratio.
struct Params {
    center: vec2f, // point
    size: f32,     // float — ellipse width in frame widths
    aspect: f32,   // float — ellipse height / width
    feather: f32,  // float — edge width in frame heights
    invert: u32,   // bool — transparent inside instead
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let frame_aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    // Work in frame heights so the feather is isotropic.
    let d = (uv - params.center) * vec2f(frame_aspect, 1.0);
    let rx = max(params.size, 0.05) * frame_aspect * 0.5;
    let r = vec2f(rx, rx * max(params.aspect, 0.1));
    // Approximate signed distance to the ellipse (exact on the axes).
    let k0 = length(d / r);
    let k1 = length(d / (r * r));
    let dist = k0 * (k0 - 1.0) / max(k1, 1e-5);
    let f = max(params.feather, 1.5 * gobofx_globals.texel.y);
    var m = 1.0 - smoothstep(-f * 0.5, f * 0.5, dist);
    if (params.invert == 1u) { m = 1.0 - m; }
    return src * m;
}
