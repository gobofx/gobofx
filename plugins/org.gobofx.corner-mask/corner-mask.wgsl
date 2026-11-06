// Corner Mask — keep the picture inside a four-corner quad, transparent
// outside, with a feathered edge. The four points are free, so the quad
// can be a keystone, a parallelogram or any shape four corners make; the
// distance is an exact polygon distance, so a non-convex or crossed quad
// still renders without holes in the maths. Feather is in frame heights.
struct Params {
    top_left: vec2f,     // point
    top_right: vec2f,    // point
    bottom_right: vec2f, // point
    bottom_left: vec2f,  // point
    feather: f32,        // float — edge width in frame heights
    invert: u32,         // bool — transparent inside instead
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

// Signed distance to a quad given in order; negative inside (even-odd fill).
fn sd_quad(p: vec2f, a: vec2f, b: vec2f, c: vec2f, d: vec2f) -> f32 {
    var v = array<vec2f, 4>(a, b, c, d);
    var dist2 = dot(p - v[0], p - v[0]);
    var s = 1.0;
    for (var i = 0; i < 4; i++) {
        let j = (i + 3) % 4;
        let e = v[j] - v[i];
        let w = p - v[i];
        let bb = w - e * clamp(dot(w, e) / max(dot(e, e), 1e-8), 0.0, 1.0);
        dist2 = min(dist2, dot(bb, bb));
        let cond = vec3<bool>(p.y >= v[i].y, p.y < v[j].y, e.x * w.y > e.y * w.x);
        if (all(cond) || all(!cond)) { s = -s; }
    }
    return s * sqrt(dist2);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    // Work in frame heights so the feather is isotropic.
    let k = vec2f(gobofx_globals.resolution.x / gobofx_globals.resolution.y, 1.0);
    let dist = sd_quad(uv * k, params.top_left * k, params.top_right * k,
                       params.bottom_right * k, params.bottom_left * k);
    let f = max(params.feather, 1.5 * gobofx_globals.texel.y);
    var m = 1.0 - smoothstep(-f * 0.5, f * 0.5, dist);
    if (params.invert == 1u) { m = 1.0 - m; }
    return src * m;
}
