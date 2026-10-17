// Reactive Grade — saturation, contrast and temperature, driven by signals.
// `bass` (a controller the host feeds from an audio follower) adds saturation.
// Three notes play the picture like an instrument: C1 (`sat`) saturates,
// D1 (`flash`) flashes, E1 (`punch`) zooms in. By default the host feeds the
// kick drum into `flash` and `punch`. Everything arrives as 0..1 floats; the
// plugin never sees MIDI events or audio.

struct Params {
    saturation: f32,
    contrast: f32,
    temperature: f32,          // -1 cool … +1 warm
    bass_to_saturation: f32,   // how much `bass` adds to saturation
    note_to_saturation: f32,   // how much `sat` (C1 velocity) adds to saturation
    flash_amount: f32,         // how bright `flash` (D1) flashes
    punch_amount: f32,         // how far `punch` (E1) zooms in (fraction of the frame)
}
@group(1) @binding(0) var<uniform> params: Params;

struct Signals {
    bass: f32,
    sat: f32,
    flash: f32,
    punch: f32,
}
@group(1) @binding(1) var<uniform> gobofx_signals: Signals;

const LUMA = vec3f(0.2126, 0.7152, 0.0722); // Rec. 709, linear

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    // Punch: zoom into the centre while E1 is on.
    let zoom = 1.0 - gobofx_signals.punch * params.punch_amount;
    let puv = (uv - 0.5) * zoom + 0.5;
    let p = textureSampleLevel(gobofx_input0, gobofx_sampler, puv, 0.0);
    let a = p.a;
    // Grade straight (unpremultiplied) colour, then premultiply again.
    var c = select(vec3f(0.0), p.rgb / max(a, 1e-6), a > 0.0);

    let sat = max(
        params.saturation
            + gobofx_signals.bass * params.bass_to_saturation
            + gobofx_signals.sat * params.note_to_saturation,
        0.0
    );
    let y = dot(c, LUMA);
    c = mix(vec3f(y), c, sat);

    c = (c - 0.18) * params.contrast + 0.18;          // contrast around middle grey

    let t = params.temperature;
    c *= vec3f(1.0 + 0.25 * t, 1.0, 1.0 - 0.25 * t);  // warm / cool tint

    c += vec3f(gobofx_signals.flash * params.flash_amount);  // flash on D1

    c = max(c, vec3f(0.0));
    return vec4f(c * a, a);
}
