// Circle Blur — a Gaussian blur confined to a circle, or to everything but
// the circle. Separable in two passes with a per-pixel radius that follows a
// feathered disc, so the blur fades to sharp instead of stopping at a seam.
// Blur 0 passes through.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_BLUR: f32 = 48.0;

struct Params {
    center: vec2f, // point — the circle's centre
    radius: f32,   // float — circle radius in frame heights
    feather: f32,  // float — width of the soft rim in frame heights
    blur: f32,     // float — blur radius in pixels, reached inside the circle
    outside: u32,  // bool — 1 blurs outside the circle instead
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

// 1 where the blur is full, 0 where the picture stays sharp. Distances are
// in frame heights, so the circle is round at any aspect.
fn blur_amount(uv: vec2f) -> f32 {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let d = length((uv - params.center) * vec2f(aspect, 1.0));
    let r = max(params.radius, 0.05);
    let f = max(clamp(params.feather, 0.0, 1.0), 1e-3) * 0.5;
    let past_rim = smoothstep(r - f, r + f, d);
    return select(1.0 - past_rim, past_rim, params.outside == 1u);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let r = clamp(params.blur, 0.0, MAX_BLUR) * blur_amount(uv);
    if (r < 0.5) {
        return src_at(uv);
    }
    let sigma = r / 3.0;
    let inv_two_sigma2 = 1.0 / (2.0 * sigma * sigma);
    let dir = vec2f(DIR_X, DIR_Y) * gobofx_globals.texel;
    let n = i32(ceil(r));
    var acc = vec4f(0.0);
    var wsum = 0.0;
    for (var i = -n; i <= n; i++) {
        let x = f32(i);
        let w = exp(-x * x * inv_two_sigma2);
        acc += src_at(uv + dir * x) * w;
        wsum += w;
    }
    return acc / wsum;
}
