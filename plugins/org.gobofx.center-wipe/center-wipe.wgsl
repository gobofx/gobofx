// Center — `to` opens outward from a point: a horizontal or vertical slit,
// a box, or a circle, growing until it fills the frame.
struct Params {
    shape: u32,    // choice — 0 horizontal slit, 1 vertical slit, 2 box, 3 circle
    center: vec2f, // point — where the opening starts
    softness: f32, // float — feather of the edge, in uv units
    ease: f32,     // float
}
@group(1) @binding(0) var<uniform> params: Params;

fn eased(ease: f32) -> f32 {
    let p = clamp(gobofx_globals.progress, 0.0, 1.0);
    return mix(p, smoothstep(0.0, 1.0, p), clamp(ease, 0.0, 1.0));
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let a = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    let b = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let c = clamp(params.center, vec2f(0.0), vec2f(1.0));
    // Distances are normalised so that 1 reaches the farthest frame edge or corner.
    let ext = vec2f(max(c.x, 1.0 - c.x), max(c.y, 1.0 - c.y));
    let dxy = abs(uv - c) / ext;
    var d: f32;
    switch params.shape {
        case 1u: { d = dxy.x; }
        case 2u: { d = max(dxy.x, dxy.y); }
        case 3u: {
            let scale = vec2f(aspect, 1.0);
            let o = c * scale;
            let far = max(max(length(o), length(o - vec2f(aspect, 0.0))),
                          max(length(o - vec2f(0.0, 1.0)), length(o - scale)));
            d = length((uv - c) * scale) / max(far, 1e-4);
        }
        default: { d = dxy.y; }
    }
    // Never a zero-width feather: smoothstep with equal edges is undefined.
    let s = max(clamp(params.softness, 0.0, 0.5), 0.5 * gobofx_globals.texel.y);
    let edge = -s + eased(params.ease) * (1.0 + 2.0 * s);
    let keep_a = smoothstep(edge - s, edge + s, d);
    return mix(b, a, keep_a);
}
