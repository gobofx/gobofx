// Droplet — water-drop rings spreading from a point. Local: the rings fade
// out at the radius and the rest of the frame is untouched. Nothing moves
// with time by itself; keyframe `phase` to make the drop spread.
const TAU: f32 = 6.28318530718;

struct Params {
    center: vec2f,  // point
    radius: f32,    // float — in frame heights
    rings: f32,     // float — rings within the radius
    amplitude: f32, // float — in frame heights
    decay: f32,     // float — 0 the rings reach the radius, 1 they die near the centre
    phase: f32,     // float — in ring spacings; +1 moves every ring out by one
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
    let n = r / max(params.radius, 0.05);
    // Envelope: 1 at the centre, 0 at the radius; decay sharpens the fall so
    // the outer rings die first, as a real drop's do.
    let fall = 1.0 - smoothstep(0.0, 1.0, n);
    let env = pow(fall, 1.0 + 5.0 * clamp(params.decay, 0.0, 1.0));
    let wave = sin((n * max(params.rings, 1.0) - params.phase) * TAU);
    let dir = select(vec2f(0.0), d / max(r, 1e-6), r > 1e-5);
    let off = dir * wave * params.amplitude * env;
    let c = src_at(uv + off / vec2f(aspect, 1.0));
    // Shade the troughs a little so the rings read on flat colour, as light
    // through real ripples does. Scales with amplitude: exactly 1 at 0, and
    // never above 1, so premultiplied colour stays within alpha.
    let k = clamp(params.amplitude / 0.05, 0.0, 1.0);
    let shade = 1.0 - 0.4 * env * k * (0.5 - 0.5 * wave);
    return vec4f(c.rgb * shade, c.a);
}
