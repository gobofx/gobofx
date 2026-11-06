// Bevel — the alpha shape gets a lit edge: a soft slope rising from the
// outline inward, lit from one angle, so the side facing the light goes
// bright and the far side goes dark. The slope is the shape's alpha blurred
// to the bevel width (two separable passes); its gradient is the surface
// normal, and the shading is applied to the source colour in a third pass.
// Width 0 passes through.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_WIDTH: f32 = 64.0;

struct Params {
    width: f32,     // float — bevel width in pixels
    angle: f32,     // float — where the light comes from, degrees, 0 right, 90 up
    highlight: f32, // float — strength of the lit side; 0 none
    shadow: f32,    // float — strength of the dark side; 0 none
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}
fn height_at(uv: vec2f) -> f32 {
    return textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0).a;
}

// Gaussian over the alpha alone; sigma is half the width so the slope spans
// about the bevel width inside the edge.
@fragment
fn fs_blur(@location(0) uv: vec2f) -> @location(0) vec4f {
    let w = clamp(params.width, 0.0, MAX_WIDTH);
    if (w < 0.5) {
        return vec4f(0.0, 0.0, 0.0, textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0).a);
    }
    let sigma = w * 0.5;
    let inv_two_sigma2 = 1.0 / (2.0 * sigma * sigma);
    let dir = vec2f(DIR_X, DIR_Y) * gobofx_globals.texel;
    let n = i32(ceil(w));
    var acc = 0.0;
    var wsum = 0.0;
    for (var i = -n; i <= n; i++) {
        let x = f32(i);
        let k = exp(-x * x * inv_two_sigma2);
        acc += textureSampleLevel(gobofx_input0, gobofx_sampler, uv + dir * x, 0.0).a * k;
        wsum += k;
    }
    return vec4f(0.0, 0.0, 0.0, acc / wsum);
}

@fragment
fn fs_shade(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let w = clamp(params.width, 0.0, MAX_WIDTH);
    if (w < 0.5 || src.a <= 0.0) {
        return src;
    }
    // Slope of the height field by central differences, in height per pixel.
    let t = gobofx_globals.texel;
    let g = vec2f(
        height_at(uv + vec2f(t.x, 0.0)) - height_at(uv - vec2f(t.x, 0.0)),
        height_at(uv + vec2f(0.0, t.y)) - height_at(uv - vec2f(0.0, t.y))
    ) * 0.5;
    // The slope rises inward, so its surface faces outward: the edge is lit
    // where -gradient points at the light. The steepest the blurred step
    // gets is about 0.8 / width per pixel, which the scale brings to 1.
    let a = radians(params.angle);
    let light = vec2f(cos(a), -sin(a));
    let facing = clamp(dot(-g, light) * w * 1.25, -1.0, 1.0);
    let lit = max(facing, 0.0) * clamp(params.highlight, 0.0, 2.0);
    let dark = max(-facing, 0.0) * clamp(params.shadow, 0.0, 2.0);
    var c = unpremultiply(src);
    c = mix(c, vec3f(1.0), clamp(lit * 0.8, 0.0, 1.0));
    c *= 1.0 - clamp(dark * 0.85, 0.0, 1.0);
    return vec4f(c * src.a, src.a);
}
