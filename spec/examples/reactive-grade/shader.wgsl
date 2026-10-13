// Reactive Grade — saturation, contrast and temperature, driven by signals.
// `bass` (a controller the host feeds from an audio follower) adds saturation;
// `hit` (a note gate) flashes the picture. Both arrive as 0..1 floats; the
// plugin never sees MIDI events or audio.

struct Params {
    saturation: f32,
    contrast: f32,
    temperature: f32,          // -1 cool … +1 warm
    bass_to_saturation: f32,   // how much `bass` adds to saturation
    hit_flash: f32,            // how bright a `hit` flashes
}
@group(1) @binding(0) var<uniform> params: Params;

struct Signals {
    bass: f32,
    hit: f32,
}
@group(1) @binding(1) var<uniform> wisp_signals: Signals;

const LUMA = vec3f(0.2126, 0.7152, 0.0722); // Rec. 709, linear

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let p = textureSampleLevel(wisp_input0, wisp_sampler, uv, 0.0);
    let a = p.a;
    // Grade straight (unpremultiplied) colour, then premultiply again.
    var c = select(vec3f(0.0), p.rgb / max(a, 1e-6), a > 0.0);

    let sat = max(params.saturation + wisp_signals.bass * params.bass_to_saturation, 0.0);
    let y = dot(c, LUMA);
    c = mix(vec3f(y), c, sat);

    c = (c - 0.18) * params.contrast + 0.18;          // contrast around middle grey

    let t = params.temperature;
    c *= vec3f(1.0 + 0.25 * t, 1.0, 1.0 - 0.25 * t);  // warm / cool tint

    c += vec3f(wisp_signals.hit * params.hit_flash);  // flash on a hit

    c = max(c, vec3f(0.0));
    return vec4f(c * a, a);
}
