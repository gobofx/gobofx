// Outer Glow — a glow outside the alpha shape only. The silhouette is
// tinted and blurred, then the source is composited over it, so the glow
// shows where the shape is transparent and the fill is untouched. Four
// passes; intensity 0 passes through.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_RADIUS: f32 = 64.0;

struct Params {
    radius: f32,    // float — spread in pixels
    intensity: f32, // float — strength; the glow's coverage saturates at 1
    color: vec4f,   // color — the glow's colour
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
    let a = src_at(uv).a * params.color.a;
    return vec4f(unpremultiply(params.color) * a, a);
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
fn fs_compose(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let halo = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    let k = clamp(params.intensity, 0.0, 3.0);
    // Intensity scales the glow's coverage, capped at opaque, so a hot
    // setting gives a solid rim rather than an HDR one.
    let ga = min(halo.a * k, 1.0);
    let gc = unpremultiply(halo) * ga;
    // Source over glow: the glow only shows through where the shape is not.
    let outside = 1.0 - src.a;
    return vec4f(src.rgb + gc * outside, src.a + ga * outside);
}
