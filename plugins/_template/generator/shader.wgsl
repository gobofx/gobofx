// Template — generator. No input image: the first pass has `inputs: []` and
// both gobofx_input0 / gobofx_input1 are bound to a 1×1 transparent texture.
// Everything comes from params, signals and gobofx_globals (resolution,
// texel, time, progress). Output is linear, premultiplied RGBA; a transparent
// background is `vec4f(0.0)` so the host can stack the generator over clips.
//
// The host prepends spec/prelude.wgsl; never redeclare what it declares.

struct Params {
    fill: vec4f,       // color — premultiplied
    background: vec4f, // color — premultiplied, transparent by default
    shape: u32,        // choice — 0 circle, 1 square
    center: vec2f,     // point — uv, (0,0) top-left
    radius: f32,       // float — in units of the frame height
}
@group(1) @binding(0) var<uniform> params: Params;

struct Signals {
    beat: f32,         // 0..1, note 36 gate — pumps the radius
}
@group(1) @binding(1) var<uniform> gobofx_signals: Signals;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    // Work in a frame where 1.0 = the frame height so circles stay round.
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let d = (uv - params.center) * vec2f(aspect, 1.0);

    var dist: f32;
    switch params.shape {
        case 1u: { dist = max(abs(d.x), abs(d.y)); }
        default: { dist = length(d); }
    }

    let r = params.radius * (1.0 + 0.3 * gobofx_signals.beat);
    let aa = 1.5 * gobofx_globals.texel.y; // ~1.5 px anti-aliased edge
    let inside = 1.0 - smoothstep(r - aa, r + aa, dist);
    return mix(params.background, params.fill, inside); // both premultiplied
}
