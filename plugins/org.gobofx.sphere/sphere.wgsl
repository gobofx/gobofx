// Sphere — wrap the part of the picture under a disc onto a ball: the centre
// magnifies, the rim compresses, a soft limb darkening sells the curve, and
// the frame outside the ball is transparent. Amount blends from the flat
// picture (0, a no-op) to the full ball (1); the outside fades out with it.
const HALF_PI: f32 = 1.57079632679;

struct Params {
    center: vec2f, // point
    radius: f32,   // float — in frame heights
    amount: f32,   // float — 0 is a no-op, 1 a full ball on transparent
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let d = (uv - params.center) * vec2f(aspect, 1.0);
    let r = max(params.radius, 0.05);
    let n = length(d) / r;
    let a = clamp(params.amount, 0.0, 1.0);
    if (n >= 1.0) {
        // Outside the ball: the picture fades to transparent with Amount.
        return src_at(uv) * (1.0 - a);
    }
    // Arc length on the sphere, normalised so the rim is 1: the source is
    // sampled farther out than the screen point, more so towards the rim.
    let wrapped = asin(n) / HALF_PI;
    let f = mix(n, wrapped, a) / max(n, 1e-6);
    let c = src_at(params.center + d * f / vec2f(aspect, 1.0));
    // Limb darkening from the ball's normal; premultiplied, so scale rgb only.
    let z = sqrt(max(1.0 - n * n, 0.0));
    let shade = mix(1.0, 0.35 + 0.65 * z, a);
    return vec4f(c.rgb * shade, c.a);
}
