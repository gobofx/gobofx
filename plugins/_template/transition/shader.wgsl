// Template — transition. Reads `from` (gobofx_input0) and `to` (gobofx_input1),
// writes `out`. `gobofx_globals.progress` runs 0..1 across the transition:
// at 0 the output must equal `from`, at 1 it must equal `to`.
//
// The host prepends spec/prelude.wgsl (sampler, globals, the two inputs);
// never redeclare those. See the effect template for the full list.

struct Params {
    direction: u32, // choice — 0 L→R, 1 R→L, 2 T→B, 3 B→T
    softness: f32,  // float  — edge width in uv units
    ease: f32,      // float  — 0 linear … 1 smoothstep timing
}
@group(1) @binding(0) var<uniform> params: Params;

struct Signals {
    wobble: f32,    // 0..1, cc 1 — bends the wipe edge
}
@group(1) @binding(1) var<uniform> gobofx_signals: Signals;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let a = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    let b = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);

    var x: f32;
    switch params.direction {
        case 1u: { x = 1.0 - uv.x; }
        case 2u: { x = uv.y; }
        case 3u: { x = 1.0 - uv.y; }
        default: { x = uv.x; }
    }

    let p = clamp(gobofx_globals.progress, 0.0, 1.0);
    let t = mix(p, smoothstep(0.0, 1.0, p), params.ease);
    let s = params.softness;
    let wobble = 0.05 * gobofx_signals.wobble * sin(uv.y * 40.0 + gobofx_globals.time * 6.0);

    // Edge travels from -s (all `from`) to 1+s (all `to`) so the soft band clears both ends.
    let edge = t * (1.0 + 2.0 * s) - s + wobble;
    // `from` stays where the edge has not passed yet: keep_a is 1 at p=0
    // (edge sits at -s, left of every pixel) and 0 at p=1 (edge at 1+s).
    let keep_a = smoothstep(edge - s, edge + s, x);
    return mix(b, a, keep_a); // premultiplied: a plain mix is correct
}
