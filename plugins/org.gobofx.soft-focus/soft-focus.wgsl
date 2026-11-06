// Soft Focus — a diffusion filter: a blurred copy is screened over the sharp
// picture, so highlights bloom into their surroundings while the detail
// underneath stays. Three passes: blur horizontally, vertically, then mix.
// Highlights biases the diffusion toward the brights, the way a net or a
// mist filter lifts the lights more than the shadows. Amount 0 passes through.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_RADIUS: f32 = 64.0;

struct Params {
    radius: f32,     // float — spread of the diffusion in pixels
    amount: f32,     // float — how much of the diffused copy shows; 0 is off
    highlights: f32, // float — 0 diffuses everything evenly, 1 only the brights
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn luma(c: vec3f) -> f32 {
    return dot(c, vec3f(0.2126, 0.7152, 0.0722));
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_blur(@location(0) uv: vec2f) -> @location(0) vec4f {
    let r = clamp(params.radius, 1.0, MAX_RADIUS);
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

@fragment
fn fs_mix(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let soft = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    let c = unpremultiply(src);
    let b = unpremultiply(soft);
    // Screen lightens toward the blur without clipping; the max keeps HDR
    // values from being pulled down by it.
    let screened = max(c, c + b - c * b);
    // Where the blurred picture is bright the diffusion is full; where it is
    // dark it is held back by the highlights bias.
    let bright = smoothstep(0.1, 0.8, luma(b));
    let k = clamp(params.amount, 0.0, 1.0) * mix(1.0, bright, clamp(params.highlights, 0.0, 1.0));
    let o = mix(c, screened, k);
    return vec4f(o * src.a, src.a);
}
