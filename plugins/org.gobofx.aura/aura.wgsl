// Aura — a soft halo in one colour around the alpha shape, on both sides
// of its edge. The coverage is blurred; outside the shape the halo is the
// blurred coverage, inside it is the blurred *gap* masked to the shape, so
// the light peaks on the edge and dies away both outward and inward, and
// the shape's own fill is untouched. Four passes; intensity 0 passes
// through.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_RADIUS: f32 = 64.0;

struct Params {
    radius: f32,    // float — spread in pixels
    intensity: f32, // float — strength; above 1 the rim saturates
    color: vec4f,   // color — the halo's colour
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_silhouette(@location(0) uv: vec2f) -> @location(0) vec4f {
    // Only the coverage is blurred; the colour comes in at the end.
    return vec4f(0.0, 0.0, 0.0, src_at(uv).a);
}

@fragment
fn fs_blur(@location(0) uv: vec2f) -> @location(0) vec4f {
    let r = clamp(params.radius, 1.0, MAX_RADIUS);
    let sigma = r / 2.5;
    let inv = 1.0 / (2.0 * sigma * sigma);
    let dir = vec2f(DIR_X, DIR_Y) * gobofx_globals.texel;
    let n = i32(ceil(r));
    var acc = vec4f(0.0);
    var wsum = 0.0;
    for (var i = -n; i <= n; i++) {
        let x = f32(i);
        let w = exp(-x * x * inv);
        acc += src_at(uv + dir * x) * w;
        wsum += w;
    }
    return acc / wsum;
}

@fragment
fn fs_add(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let b = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0).a;
    let k = clamp(params.intensity, 0.0, 3.0);
    // Outer part: blurred coverage where the shape is not. Inner part: the
    // blurred gap (1 - b) where the shape is. Both are 0.5 on the edge, so
    // the sum is doubled to peak at full strength there.
    let rim = 2.0 * (b * (1.0 - src.a) + (1.0 - b) * src.a);
    let cov = min(rim * k * params.color.a, 1.0);
    let a = clamp(src.a + cov, 0.0, 1.0);
    return vec4f(src.rgb + unpremultiply(params.color) * cov, a);
}
