// Twirl — swirl the picture around a point, strongest at the centre.
struct Params {
    center: vec2f, // point
    radius: f32,   // float — in frame heights
    angle: f32,    // float — degrees at the centre
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
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let d = (uv - params.center) * vec2f(aspect, 1.0);
    let r = length(d);
    let fall = 1.0 - smoothstep(0.0, max(params.radius, 0.05), r);
    let a = radians(params.angle) * fall * fall;
    let rot = vec2f(d.x * cos(a) - d.y * sin(a), d.x * sin(a) + d.y * cos(a));
    return src_at(params.center + rot / vec2f(aspect, 1.0));
}
