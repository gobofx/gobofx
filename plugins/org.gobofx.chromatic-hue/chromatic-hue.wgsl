// Chromatic Hue — a keyboard where every key is a hue.
// `key` (notes C1–B1, mode pitch) picks the hue: 0 for C, up to 11 semitones
// times `degrees_per_key`. It latches, so the hue stays after the key is
// released. `held` (same keys, mode velocity) sets how much of the rotation is
// applied; with `hold` on, the last hue stays even with nothing held. `bend`
// adds a fine rotation around the key's hue; `pressure` boosts saturation.

struct Params {
    degrees_per_key: f32,
    bend_range: f32,
    pressure_to_saturation: f32,
    hold: u32,
}
@group(1) @binding(0) var<uniform> params: Params;

struct Signals {
    key: f32,       // 0..1 across C1–B1, latched
    held: f32,      // velocity while a key is down, with release
    bend: f32,      // 0.5 at rest
    pressure: f32,  // 0..1
}
@group(1) @binding(1) var<uniform> gobofx_signals: Signals;

const LUMA = vec3f(0.2126, 0.7152, 0.0722); // Rec. 709, linear

// Rotate hue in linear RGB around the grey axis (Rodrigues' formula on (1,1,1)/√3).
fn rotate_hue(c: vec3f, angle: f32) -> vec3f {
    let k = vec3f(0.57735026919);
    let cs = cos(angle);
    let sn = sin(angle);
    return c * cs + cross(k, c) * sn + k * dot(k, c) * (1.0 - cs);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let p = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    let a = p.a;
    var c = select(vec3f(0.0), p.rgb / max(a, 1e-6), a > 0.0);

    let semitones = gobofx_signals.key * 11.0;
    let bend = (gobofx_signals.bend - 0.5) * 2.0 * params.bend_range;
    let degrees = semitones * params.degrees_per_key + bend;
    let amount = select(gobofx_signals.held, 1.0, params.hold == 1u);
    c = rotate_hue(c, radians(degrees) * amount);

    // Aftertouch pushes saturation; nothing held, nothing changes.
    let sat = 1.0 + gobofx_signals.pressure * params.pressure_to_saturation;
    let y = dot(c, LUMA);
    c = mix(vec3f(y), c, sat);

    c = max(c, vec3f(0.0));
    return vec4f(c * a, a);
}
