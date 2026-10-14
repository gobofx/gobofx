# Signals — v0.1 (draft, added 2026-10-13)

A signal is a number the host delivers to the plugin every frame from something
outside the picture. The plugin declares which signals it wants and reads them in
the shader; the host decides what feeds them. A colour grade whose saturation
follows the bass, or whose contrast snaps on a drum hit, is the plugin author's
design, written once and portable to every host.

**Signals are MIDI 2.0 controllers.** Every GoboFX plugin has one virtual MIDI
2.0 input. A signal binds either a control change number or a note on that
input. The plugin never sees audio, OSC or hardware; the host owns that
translation. An audio envelope follower, an OSC address, a hardware fader and a
keyframe lane all end up as the same thing: a controller value on the plugin's
input. This is the same addressing WCLAP audio plugins use, so a host routes
sound and picture with one mechanism.

Signals are distinct from params. A param is a value the user sets or keyframes.
A signal is a value that arrives on the MIDI input. A plugin may have either,
both or neither.

## Manifest

```jsonc
"signals": [
  { "id": "bass", "label": "Bass",  "cc": 1,
    "hint": "audio follower, 40–160 Hz", "attack_ms": 10, "release_ms": 250 },
  { "id": "hit",  "label": "Hit",   "note": 36, "mode": "gate", "release_ms": 120 },
  { "id": "warmth", "label": "Warmth", "cc": 74 }
]
```

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `id` | string | yes | `^[a-z_][a-z0-9_]*$`, unique among signals and params |
| `label` | string | no | Display name |
| `cc` | integer 0..127 | one of `cc` / `note` | Control change number on the plugin's MIDI 2.0 input |
| `note` | integer 0..127 | one of `cc` / `note` | Note number on the plugin's MIDI 2.0 input |
| `mode` | `gate` \| `velocity` | with `note` | `gate`: 1 while the note is held, else 0. `velocity`: note-on velocity while held, else 0. Default `gate` |
| `channel` | integer 1..16 | no | MIDI channel; absent means any channel |
| `hint` | string | no | What the author expects to feed this signal, shown by the host as the suggested routing |
| `default` | number 0..1 | no | Value used until the first event arrives, and by hosts with no MIDI input. Default 0 |
| `attack_ms`, `release_ms` | number | no | One-pole envelope the host applies before upload, in milliseconds. Default 0 (none) |

A manifest may not bind the same `cc` or the same `note` twice on the same
channel.

## Values

Every signal reaches the shader as one `f32` in the closed range 0..1:

- A control change carries MIDI 2.0's 32-bit controller value, divided by
  `2^32 − 1`. A MIDI 1.0 source is upscaled by the host before it reaches the
  plugin; the plugin never sees 7-bit steps.
- A note in `velocity` mode carries MIDI 2.0's 16-bit velocity divided by
  `65535` while the note is held.
- A note in `gate` mode carries 1 while held.

The plugin reads values, never events. One value per rendered frame; signals are
not audio-rate.

## Shader

The plugin declares the struct, one `f32` per signal in manifest order, at
`@group(1) @binding(1)`:

```wgsl
struct Signals { bass: f32, hit: f32, warmth: f32 }
@group(1) @binding(1) var<uniform> wisp_signals: Signals;
```

Layout follows WGSL uniform rules (every field 4 bytes, struct padded to a
multiple of 16). A plugin with no signals declares no binding 1. A plugin that
declares the binding must declare every manifest signal, in order; a host
validates this the same way it validates `Params`.

## Host behaviour

- **Routing.** The host decides what sends controllers to the plugin's input:
  a MIDI track, a hardware device, an audio follower on another track, an OSC
  bridge, an automation lane. The manifest `hint` is the author's suggestion
  for the default. The plugin is unchanged whichever the host picks.
- **Absent input.** A host with no MIDI uploads `default` for every signal.
  The plugin must render sensibly at its defaults.
- **Smoothing.** `attack_ms` and `release_ms` describe a one-pole envelope the
  host applies to the controller value before upload, so a kick drum reads as
  a clean curve and the same plugin behaves the same everywhere.
- **Determinism.** In an offline render the host evaluates the MIDI recorded
  on the timeline at each frame, so a render matches the live preview frame
  for frame.
- **Channels.** With `channel` absent the host merges all channels; with it
  set, events on other channels are ignored.

## What signals are not

Signals drive a look. They do not carry waveforms or spectra for drawing. A
visualiser that draws the sound needs an audio texture input, which is a
separate proposal. Per-note controllers and other MIDI 2.0 per-note data are
not addressed in 0.1.
