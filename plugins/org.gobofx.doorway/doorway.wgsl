// Doorway — `from` opens like a pair of doors hinged at the frame edges,
// revealing `to`, which settles in from a slight zoom.
struct Params {
    perspective: f32, // float — foreshortening of the swinging doors
    zoom: f32,        // float — how far `to` starts zoomed in
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
    let theta = t * 1.57079633;
    let c = cos(theta);
    let s = sin(theta);
    let k = clamp(params.perspective, 0.0, 1.0) * 0.8;
    // `to` behind, zoomed in a little at the start, settling to 1:1.
    let z = 1.0 + clamp(params.zoom, 0.0, 0.5) * (1.0 - t);
    let b = textureSampleLevel(gobofx_input1, gobofx_sampler, 0.5 + (uv - 0.5) / z, 0.0);
    // Door space: x measured from the hinge (0 at the frame edge, 0.5 at the centre seam).
    let left = uv.x < 0.5;
    let xs = select(1.0 - uv.x, uv.x, left);
    var a = vec4f(0.0);
    if (c > 1e-4) {
        let xd = xs / c;
        let yd = 0.5 + (uv.y - 0.5) / (1.0 + k * xd * s);
        if (xd <= 0.5 && yd >= 0.0 && yd <= 1.0) {
            let src = vec2f(select(1.0 - xd, xd, left), yd);
            a = textureSampleLevel(gobofx_input0, gobofx_sampler, src, 0.0);
        }
    }
    return over(a, b);
}
