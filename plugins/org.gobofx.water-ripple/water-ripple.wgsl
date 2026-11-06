// Ripple — concentric water ripples across the whole frame, travelling
// outward from a point with time.
const TAU: f32 = 6.28318530718;

struct Params {
    center: vec2f,  // point
    frequency: f32, // float — rings per frame height
    amplitude: f32, // float — displacement in frame heights; 0 is a no-op
    speed: f32,     // float — rings per second outward; negative runs inward
}
@group(1) @binding(0) var<uniform> params: Params;

// Clamp-to-edge: a pixel pulled from outside the frame repeats the edge.
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let d = (uv - params.center) * vec2f(aspect, 1.0);
    let r = length(d);
    let wave = sin((r * max(params.frequency, 1.0) - gobofx_globals.time * params.speed) * TAU);
    let dir = select(vec2f(0.0), d / max(r, 1e-6), r > 1e-5);
    let off = dir * wave * params.amplitude;
    return src_at(uv + off / vec2f(aspect, 1.0));
}
