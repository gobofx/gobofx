// Fall — `from` tips over backwards around its bottom edge and falls away
// from the camera, revealing `to` behind it.
struct Params {
    perspective: f32, // float — 0 flat, 1 strong foreshortening
    shade: f32,       // float — how dark `from` goes as it turns away
    ease: f32,        // float
}
@group(1) @binding(0) var<uniform> params: Params;

fn from_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0), inside);
}
fn to_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0), inside);
}
fn eased(ease: f32) -> f32 {
    let p = clamp(gobofx_globals.progress, 0.0, 1.0);
    return mix(p, smoothstep(0.0, 1.0, p), clamp(ease, 0.0, 1.0));
}
// Premultiplied `over`.
fn over(top: vec4f, bottom: vec4f) -> vec4f {
    return top + bottom * (1.0 - top.a);
}
fn hash21(p: vec2f) -> f32 {
    var q = fract(p * vec2f(123.34, 456.21));
    q = q + dot(q, q + 45.32);
    return fract(q.x * q.y);
}
// Direction 0..3 → the axis coordinate that grows along the wipe.
fn axis(uv: vec2f, direction: u32) -> f32 {
    switch direction {
        case 1u: { return 1.0 - uv.x; }
        case 2u: { return uv.y; }
        case 3u: { return 1.0 - uv.y; }
        default: { return uv.x; }
    }
}
fn dir_vec(direction: u32) -> vec2f {
    switch direction {
        case 1u: { return vec2f(-1.0, 0.0); }
        case 2u: { return vec2f(0.0, 1.0); }
        case 3u: { return vec2f(0.0, -1.0); }
        default: { return vec2f(1.0, 0.0); }
    }
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = eased(params.ease);
    let b = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    if (t >= 1.0) { return b; }
    // A fall accelerates: the angle grows faster than linearly.
    let theta = pow(t, 1.5) * 1.57079633;
    let c = cos(theta);
    let s = sin(theta);
    // Pinhole camera in front of the frame, `d` frame-heights away.
    let d = mix(6.0, 1.5, clamp(params.perspective, 0.0, 1.0));
    let sy = 1.0 - uv.y;  // screen height above the hinge
    let sx = uv.x - 0.5;
    var a = vec4f(0.0);
    // A page point h above the hinge sits at (h c) up and (h s) back; invert the projection.
    let den = d * c - sy * s;
    if (den > 1e-5) {
        let h = sy * d / den;
        let scale = d / (d + h * s);
        let x = sx / scale;
        if (h >= 0.0 && h <= 1.0 && abs(x) <= 0.5) {
            a = from_at(vec2f(x + 0.5, 1.0 - h));
            let dark = 1.0 - clamp(params.shade, 0.0, 1.0) * s;
            a = vec4f(a.rgb * dark, a.a);
        }
    }
    return over(a, b);
}
