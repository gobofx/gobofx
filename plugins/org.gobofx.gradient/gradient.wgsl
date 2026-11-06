// Gradient — linear, radial or diamond ramp between two colours.
// All styles pass through `center`; `span` is the ramp length in units of
// the frame height, `angle` turns the linear ramp, `midpoint` biases it.
struct Params {
    style: u32,     // choice — 0 linear, 1 radial, 2 diamond
    color_a: vec4f, // color — at t = 0
    color_b: vec4f, // color — at t = 1
    center: vec2f,  // point — where t = 0.5 (linear) or t = 0 (radial, diamond)
    angle: f32,     // float — degrees, linear direction
    span: f32,      // float — ramp length in frame heights
    midpoint: f32,  // float — where the 50 % mix sits (0..1 along the ramp)
    repeat: u32,    // bool — 0 clamp, 1 mirror-repeat the ramp
}
@group(1) @binding(0) var<uniform> params: Params;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let d = (uv - params.center) * vec2f(aspect, 1.0);
    let span = max(params.span, 0.05);
    var t: f32;
    switch params.style {
        case 1u: { t = length(d) / span; }
        case 2u: { t = (abs(d.x) + abs(d.y)) / span; }
        default: {
            let a = radians(params.angle);
            let dir = vec2f(cos(a), sin(a));
            t = dot(d, dir) / span + 0.5;
        }
    }
    if (params.repeat == 1u) {
        t = 1.0 - abs(1.0 - fract(t * 0.5) * 2.0); // triangle wave, 0..1..0
    } else {
        t = clamp(t, 0.0, 1.0);
    }
    // Bias: a midpoint of 0.5 is linear; below pulls colour B in earlier.
    let m = clamp(params.midpoint, 0.05, 0.95);
    let k = log(0.5) / log(m);
    t = pow(t, k);
    return mix(params.color_a, params.color_b, t); // premultiplied mix
}
