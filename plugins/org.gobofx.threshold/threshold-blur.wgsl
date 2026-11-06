// Threshold, passes 2 and 3 — a separable box blur of the hard mask, so the
// edge becomes a straight ramp exactly `softness` pixels wide (the box
// radius is half the softness; the outermost taps are weighted by the
// fraction they cover, so the width moves smoothly). Softness 0 is one tap:
// the mask passes through untouched. The direction comes from the override
// constants set per pass in the manifest.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_TAPS: i32 = 10; // softness is clamped to 20 px, so the radius is at most 10

struct Params {
    level: f32,    // float — unused here, see threshold-mask.wgsl
    softness: f32, // float — edge width in pixels
    invert: u32,   // bool — unused here, see threshold.wgsl
    amount: f32,   // float — unused here, see threshold.wgsl
}
@group(1) @binding(0) var<uniform> params: Params;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let r = 0.5 * clamp(params.softness, 0.0, 20.0);
    let dir = vec2f(DIR_X, DIR_Y) * gobofx_globals.texel;
    var acc = vec4f(0.0);
    var wsum = 0.0;
    for (var i = -MAX_TAPS; i <= MAX_TAPS; i++) {
        let x = f32(i);
        let w = clamp(r + 0.5 - abs(x), 0.0, 1.0);
        if (w > 0.0) {
            acc += textureSampleLevel(gobofx_input0, gobofx_sampler, uv + dir * x, 0.0) * w;
            wsum += w;
        }
    }
    return acc / max(wsum, 1e-6);
}
