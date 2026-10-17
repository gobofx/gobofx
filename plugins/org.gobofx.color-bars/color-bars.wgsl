// Color Bars — SMPTE / EBU test bars or a grey ramp. A known picture for
// checking a chain: the bars are at `intensity` (75 % by default) in sRGB,
// converted here to the linear working space.
struct Params {
    style: u32,     // choice — 0 smpte, 1 ebu, 2 ramp
    intensity: f32, // float — bar level in sRGB, 0.5..1
    bottom: u32,    // bool — show the lower strip (reverse bars + PLUGE)
}
@group(1) @binding(0) var<uniform> params: Params;

fn srgb_to_linear(c: vec3f) -> vec3f {
    let lo = c / 12.92;
    let hi = pow((c + 0.055) / 1.055, vec3f(2.4));
    return select(hi, lo, c <= vec3f(0.04045));
}

fn bar(i: i32) -> vec3f {
    // White, yellow, cyan, green, magenta, red, blue.
    switch i {
        case 0: { return vec3f(1.0, 1.0, 1.0); }
        case 1: { return vec3f(1.0, 1.0, 0.0); }
        case 2: { return vec3f(0.0, 1.0, 1.0); }
        case 3: { return vec3f(0.0, 1.0, 0.0); }
        case 4: { return vec3f(1.0, 0.0, 1.0); }
        case 5: { return vec3f(1.0, 0.0, 0.0); }
        default: { return vec3f(0.0, 0.0, 1.0); }
    }
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let k = clamp(params.intensity, 0.5, 1.0);
    var c: vec3f;
    if (params.style == 2u) {
        // Grey ramp with 16-step bands above a continuous ramp.
        let steps = floor(uv.x * 16.0) / 15.0;
        c = vec3f(select(uv.x, steps, uv.y < 0.5)) * k;
    } else {
        let i = clamp(i32(uv.x * 7.0), 0, 6);
        let top_h = select(1.0, 0.67, params.bottom == 1u);
        if (uv.y < top_h) {
            c = bar(i) * k;
        } else if (uv.y < top_h + 0.08) {
            // Reverse bars: blue, black, magenta, black, cyan, black, white.
            let rev = select(vec3f(0.0), bar(6 - i), (i & 1) == 0);
            c = rev * k;
        } else {
            // PLUGE-ish strip: -I/white/+Q blocks, then black, sub/super black, black.
            let x = uv.x;
            if (x < 0.125) { c = vec3f(0.0, 0.16, 0.33); }
            else if (x < 0.25) { c = vec3f(1.0); }
            else if (x < 0.375) { c = vec3f(0.2, 0.0, 0.42); }
            else if (x < 0.625) { c = vec3f(0.0); }
            else if (x < 0.6875) { c = vec3f(0.0); }
            else if (x < 0.75) { c = vec3f(0.04); }
            else if (x < 0.8125) { c = vec3f(0.08); }
            else { c = vec3f(0.0); }
            if (params.style == 1u) { c = vec3f(0.0); } // EBU has no PLUGE row
        }
        if (params.style == 1u && uv.y >= top_h) {
            // EBU: a plain black lower strip.
            c = vec3f(0.0);
        }
    }
    return vec4f(srgb_to_linear(clamp(c, vec3f(0.0), vec3f(1.0))), 1.0);
}
