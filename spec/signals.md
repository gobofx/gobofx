# Signals — v0.1 (draft, added 2026-10-13, note ranges, pitch bend and pressure added 2026-10-14)

A signal is a number the host delivers to the plugin every frame from something
outside the picture. The plugin declares which signals it wants and reads them in
the shader; the host decides what feeds them. A colour grade whose saturation
follows the bass, or whose contrast snaps on a drum hit, is the plugin author's
design, written once and portable to every host.

**Signals are MIDI 2.0 controllers.** Every GoboFX plugin has one virtual MIDI
2.0 input. A signal binds a control change number, a note, a range of notes,
the pitch bend wheel or channel pressure on that input. The plugin never sees audio, OSC or hardware; the host owns that
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
  { "id": "warmth", "label": "Warmth", "cc": 74 },
  { "id": "key",   "label": "Key",    "notes": [36, 47], "mode": "pitch" },
  { "id": "held",  "label": "Held",   "notes": [36, 47], "mode": "gate", "release_ms": 200 },
  { "id": "sweep", "label": "Sweep",  "control": "bend" },
  { "id": "press", "label": "Press",  "control": "pressure" }
]
```

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `id` | string | yes | `^[a-z_][a-z0-9_]*$`, unique among signals and params |
| `label` | string | no | Display name |
| `cc` | integer 0..127 | exactly one of `cc` / `note` / `notes` / `control` | Control change number on the plugin's MIDI 2.0 input |
| `note` | integer 0..127 | ″ | One note number |
| `notes` | `[lo, hi]`, integers 0..127, `lo < hi` | ″ | An inclusive range of note numbers, treated as one key zone |
| `control` | `bend` \| `pressure` | ″ | The pitch bend wheel, or channel pressure (aftertouch) |
| `mode` | `gate` \| `velocity` \| `pitch` \| `pressure` | with `note` / `notes` | What the note binding delivers (below). Default `gate`. `pitch` needs `notes` |
| `channel` | integer 1..16 | no | MIDI channel; absent means any channel |
| `hint` | string | no | What the author expects to feed this signal, shown by the host as the suggested routing |
| `default` | number 0..1 | no | Value used until the first event arrives, and by hosts with no MIDI input. Default 0, except 0.5 for `control: "bend"` |
| `attack_ms`, `release_ms` | number | no | One-pole envelope the host applies before upload, in milliseconds. Default 0 (none) |

Note modes, for `note` and `notes`:

| `mode` | Value |
| --- | --- |
| `gate` | 1 while any bound note is held, else 0 |
| `velocity` | Note-on velocity of the most recently pressed bound note while it is held, else 0 |
| `pitch` | Position of the most recently pressed bound note inside the range: `(n − lo) / (hi − lo)`. Latched: it keeps its value after release, so a plugin can read "which key" separately from "is a key down" |
| `pressure` | Per-note pressure of the held bound notes (the loudest), else 0 |

A manifest may not bind the same `cc` twice, or the same `control` twice, on
the same channel. Note bindings may overlap: binding one zone twice with
different modes (`pitch` plus `gate`) is the normal way to read a keyboard.
Two note bindings that are identical in notes, mode and channel are an error.

## Values

Every signal reaches the shader as one `f32` in the closed range 0..1:

- A control change carries MIDI 2.0's 32-bit controller value, divided by
  `2^32 − 1`. A MIDI 1.0 source is upscaled by the host before it reaches the
  plugin; the plugin never sees 7-bit steps.
- A note in `velocity` mode carries MIDI 2.0's 16-bit velocity divided by
  `65535` while the note is held.
- A note in `gate` mode carries 1 while held.
- A note binding in `pitch` mode carries the note's position inside its range.
- A note binding in `pressure` mode carries MIDI 2.0's 32-bit per-note pressure
  divided by `2^32 − 1`. A host whose source only sends channel pressure MAY
  substitute it while a bound note is held.
- `control: "bend"` carries MIDI 2.0's 32-bit pitch bend divided by `2^32 − 1`,
  so the wheel at rest reads 0.5, fully down 0, fully up 1. A MIDI 1.0 14-bit
  bend is upscaled by the host.
- `control: "pressure"` carries MIDI 2.0's 32-bit channel pressure divided by
  `2^32 − 1`.

The plugin reads values, never events. One value per rendered frame; signals are
not audio-rate.

## Shader

The plugin declares the struct, one `f32` per signal in manifest order, at
`@group(1) @binding(1)`:

```wgsl
struct Signals { bass: f32, hit: f32, warmth: f32 }
@group(1) @binding(1) var<uniform> gobofx_signals: Signals;
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
  set, events on other channels are ignored. Merging means: notes from every
  channel count, a `cc` or `pressure` takes the highest channel's value, and
  `bend` takes the channel that moved last.

## What signals are not

Signals drive a look. They do not carry waveforms or spectra for drawing. A
visualiser that draws the sound needs an audio texture input, which is a
separate proposal. MIDI 2.0 per-note controllers other than pressure, and
per-note pitch bend, are not addressed in 0.1.
