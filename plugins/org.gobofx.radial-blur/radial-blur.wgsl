// Radial Blur — a spin blur: the picture is averaged along arcs around a
// centre point, as if the frame turned during the exposure. Amount 0 passes
// through.
const SAMPLES: i32 = 32;

struct Params {
    amount: f32,   // float — total arc in degrees, centred on the current frame
    center: vec2f, // point — the pivot
}
@group(1) @binding(0) var<uniform> params: Params;

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
    let arc = radians(clamp(params.amount, 0.0, 90.0));
    if (arc < 1e-4) { return src_at(uv); }
    // Rotate in a square space so the arcs are circles, not ellipses.
    let aspect = vec2f(gobofx_globals.resolution.x / gobofx_globals.resolution.y, 1.0);
    let d = (uv - params.center) * aspect;
    let j = hash21(uv * gobofx_globals.resolution); // per-pixel jitter hides the steps
    var acc = vec4f(0.0);
    for (var i = 0; i < SAMPLES; i++) {
        let a = ((f32(i) + j) / f32(SAMPLES) - 0.5) * arc;
        let c = cos(a);
        let s = sin(a);
        let p = vec2f(d.x * c - d.y * s, d.x * s + d.y * c) / aspect + params.center;
        acc += src_at(p);
    }
    return acc / f32(SAMPLES);
}
