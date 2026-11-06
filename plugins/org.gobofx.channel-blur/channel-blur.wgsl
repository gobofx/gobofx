// Channel Blur — a separate Gaussian radius for each of R, G, B and A.
// Separable, two passes; one loop covers the widest channel and each channel
// takes its own weight per tap. The blur runs on the premultiplied data, so a
// colour blurred wider than the alpha is held back to the coverage it has:
// it fades at the shape's edge instead of spilling colour over nothing.
// All four at 0 pass through.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_RADIUS: f32 = 64.0;

struct Params {
    red: f32,   // float — pixels
    green: f32, // float — pixels
    blue: f32,  // float — pixels
    alpha: f32, // float — pixels
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let r = clamp(vec4f(params.red, params.green, params.blue, params.alpha), vec4f(0.0), vec4f(MAX_RADIUS));
    let widest = max(max(r.x, r.y), max(r.z, r.w));
    if (widest < 0.5) {
        return src_at(uv);
    }
    // Sigma = radius / 3 per channel; a channel under half a pixel keeps a
    // unit weight at the centre tap and nothing elsewhere.
    let sigma = max(r, vec4f(0.5)) / 3.0;
    let inv_two_sigma2 = 1.0 / (2.0 * sigma * sigma);
    let on = r >= vec4f(0.5);
    let dir = vec2f(DIR_X, DIR_Y) * gobofx_globals.texel;
    let n = i32(ceil(widest));
    var acc = vec4f(0.0);
    var wsum = vec4f(0.0);
    for (var i = -n; i <= n; i++) {
        let x = f32(i);
        let centre = select(vec4f(0.0), vec4f(1.0), i == 0);
        let w = select(centre, exp(-x * x * inv_two_sigma2), on);
        acc += src_at(uv + dir * x) * w;
        wsum += w;
    }
    let c = acc / wsum;
    // Keep the result premultiplied: colour never above coverage, except at
    // full alpha where HDR values are allowed through.
    let rgb = select(min(c.rgb, vec3f(c.a)), c.rgb, c.a >= 1.0);
    return vec4f(rgb, c.a);
}
