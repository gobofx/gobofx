// Fill — replace what is inside a layer's alpha shape with a solid colour or
// a linear gradient; the shape and its soft edges are kept exactly.
struct Params {
    mode: u32,     // choice — 0 solid, 1 linear gradient
    color: vec4f,  // color — the fill, or the gradient's start (premultiplied)
    color2: vec4f, // color — the gradient's end (premultiplied)
    angle: f32,    // float — gradient direction in degrees; 0 runs left to right, 90 top to bottom
    amount: f32,   // float — 0 is the source, 1 the full fill
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
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    var c = unpremultiply(params.color);
    var a = params.color.a;
    if (params.mode == 1u) {
        // The gradient spans the whole frame along its direction, so it is
        // the same on every layer it is applied to and stays put as the
        // shape moves. Measured in pixels so the aspect does not skew it.
        let res = gobofx_globals.resolution;
        let r = radians(params.angle);
        let dir = vec2f(cos(r), sin(r));
        let extent = abs(dir.x) * res.x + abs(dir.y) * res.y;
        let t = clamp(0.5 + dot(uv * res - 0.5 * res, dir) / max(extent, 1.0), 0.0, 1.0);
        c = mix(c, unpremultiply(params.color2), t);
        a = mix(a, params.color2.a, t);
    }
    let fa = a * src.a;
    let filled = vec4f(c * fa, fa);
    return mix(src, filled, clamp(params.amount, 0.0, 1.0));
}
