// Spotlight — a soft pool of light over a transparent background. The pool
// is an ellipse around `center`; `softness` is how much of the radius is
// the fade, `intensity` scales the whole pool and saturates the core.
struct Params {
    center: vec2f,  // point
    radius: f32,    // float — pool radius in frame heights
    aspect: f32,    // float — width / height of the pool
    softness: f32,  // float — 0 hard rim, 1 the fade starts at the centre
    color: vec4f,   // color — premultiplied light colour
    intensity: f32, // float — 0 off, 1 full at the centre, above pushes the plateau out
}
@group(1) @binding(0) var<uniform> params: Params;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let d = (uv - params.center) * vec2f(aspect, 1.0);
    let radius = max(params.radius, 0.02);
    let ar = clamp(params.aspect, 0.25, 4.0);
    let r = length(d / vec2f(ar, 1.0)) / radius; // 1 at the rim
    let soft = clamp(params.softness, 0.0, 1.0);
    // At least ~1.5 px of fade so a hard rim still antialiases.
    let w = max(soft, 1.5 * gobofx_globals.texel.y / radius);
    let fall = 1.0 - smoothstep(1.0 - w, 1.0, r);
    // Light-like falloff: squared inside the fade, so the pool has a bright
    // core that rolls off instead of a linear ramp.
    let k = clamp(fall * fall * max(params.intensity, 0.0), 0.0, 1.0);
    return params.color * k;
}
