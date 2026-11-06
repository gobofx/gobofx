// Drop Shadow — the layer's alpha, offset and blurred, in a colour behind
// the layer. Four passes: shift the silhouette, blur it horizontally and
// vertically, composite the source over it.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_BLUR: f32 = 64.0;

struct Params {
    offset_x: f32, // float — px, positive is right
    offset_y: f32, // float — px, positive is down
    blur: f32,     // float — px, 0 is a hard-edged shadow
    color: vec4f,  // color — shadow colour (premultiplied; its alpha scales opacity)
    opacity: f32,  // float — 0 is no shadow at all
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

// The source's alpha, moved by the offset. Only alpha matters from here on;
// outside the frame the silhouette is empty, not the clamped edge.
@fragment
fn fs_offset(@location(0) uv: vec2f) -> @location(0) vec4f {
    let p = uv - vec2f(params.offset_x, params.offset_y) * gobofx_globals.texel;
    let inside = step(0.0, p.x) * step(p.x, 1.0) * step(0.0, p.y) * step(p.y, 1.0);
    let a = src_at(p).a * inside;
    return vec4f(0.0, 0.0, 0.0, a);
}

@fragment
fn fs_blur(@location(0) uv: vec2f) -> @location(0) vec4f {
    let r = clamp(params.blur, 0.0, MAX_BLUR);
    if (r < 0.5) {
        return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    }
    let sigma = r / 3.0;
    let inv = 1.0 / (2.0 * sigma * sigma);
    let dir = vec2f(DIR_X, DIR_Y) * gobofx_globals.texel;
    let n = i32(ceil(r));
    var acc = 0.0;
    var wsum = 0.0;
    for (var i = -n; i <= n; i++) {
        let x = f32(i);
        let w = exp(-x * x * inv);
        acc += textureSampleLevel(gobofx_input0, gobofx_sampler, uv + dir * x, 0.0).a * w;
        wsum += w;
    }
    return vec4f(0.0, 0.0, 0.0, acc / wsum);
}

@fragment
fn fs_composite(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let sh = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0).a;
    let a = clamp(sh * clamp(params.opacity, 0.0, 1.0) * params.color.a, 0.0, 1.0);
    let shadow = vec4f(unpremultiply(params.color) * a, a);
    // Source over shadow, both premultiplied.
    return src + shadow * (1.0 - src.a);
}
