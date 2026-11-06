// Highpass — the picture minus a blurred copy of itself, re-centred on
// mid grey, so only detail finer than the radius survives. Three passes:
// blur H, blur V, combine.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_RADIUS: f32 = 64.0;

struct Params {
    radius: f32, // float — px; detail coarser than this is removed
    amount: f32, // float — 0 is the source, 1 is the pure highpass
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn luma(c: vec3f) -> f32 {
    return dot(c, vec3f(0.2126, 0.7152, 0.0722));
}
fn hash21(p: vec2f) -> f32 {
    var q = fract(p * vec2f(123.34, 456.21));
    q = q + dot(q, q + 45.32);
    return fract(q.x * q.y);
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_blur(@location(0) uv: vec2f) -> @location(0) vec4f {
    let r = clamp(params.radius, 0.5, MAX_RADIUS);
    let sigma = r / 3.0;
    let inv = 1.0 / (2.0 * sigma * sigma);
    let dir = vec2f(DIR_X, DIR_Y) * gobofx_globals.texel;
    let n = i32(ceil(r));
    var acc = vec4f(0.0);
    var wsum = 0.0;
    for (var i = -n; i <= n; i++) {
        let x = f32(i);
        let w = exp(-x * x * inv);
        acc += textureSampleLevel(gobofx_input0, gobofx_sampler, uv + dir * x, 0.0) * w;
        wsum += w;
    }
    return acc / wsum;
}

// The subtraction happens on gamma-encoded colour, so the result sits on the
// 50 % grey a viewer expects and shadows and highlights carry equal weight.
@fragment
fn fs_combine(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let blur = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    let gs = pow(clamp(unpremultiply(src), vec3f(0.0), vec3f(1.0)), vec3f(1.0 / 2.2));
    let gb = pow(clamp(unpremultiply(blur), vec3f(0.0), vec3f(1.0)), vec3f(1.0 / 2.2));
    let hp = clamp(vec3f(0.5) + (gs - gb), vec3f(0.0), vec3f(1.0));
    let g = mix(gs, hp, clamp(params.amount, 0.0, 1.0));
    let o = pow(g, vec3f(2.2));
    return vec4f(o * src.a, src.a);
}
