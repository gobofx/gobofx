// Widescreen — letterbox or pillarbox bars that mask the frame to an aspect ratio.
struct Params {
    aspect: u32,  // choice — 0 custom, 1 2.39, 2 1.85, 3 16:9, 4 4:3, 5 1:1
    custom: f32,  // float — the ratio when `aspect` is custom
    offset: f32,  // float — slide the window: -1 one edge … 1 the other
    color: vec4f, // color — the bars (black by default; alpha 0 crops instead)
    feather: f32, // float — bar edge softness in pixels
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn luma(c: vec3f) -> f32 {
    return dot(c, vec3f(0.2126, 0.7152, 0.0722));
}
fn hash21(p: vec2f) -> f32 {
    var q = fract(p * vec2f(123.34, 456.21));
    q = q + dot(q, q + 45.32);
    return fract(q.x * q.y);
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let res = gobofx_globals.resolution;
    let frame = res.x / res.y;
    var ratio: f32;
    switch params.aspect {
        case 1u: { ratio = 2.39; }
        case 2u: { ratio = 1.85; }
        case 3u: { ratio = 16.0 / 9.0; }
        case 4u: { ratio = 4.0 / 3.0; }
        case 5u: { ratio = 1.0; }
        default: { ratio = clamp(params.custom, 0.5, 4.0); }
    }
    let f = max(params.feather, 0.5);
    var inside: f32;
    if (ratio >= frame) {
        // Letterbox: window height as a fraction of the frame.
        let h = frame / ratio;
        let c = 0.5 + params.offset * (1.0 - h) * 0.5;
        let d = (abs(uv.y - c) - h * 0.5) * res.y; // px outside the window
        inside = 1.0 - smoothstep(-f * 0.5, f * 0.5, d);
    } else {
        let w = ratio / frame;
        let c = 0.5 + params.offset * (1.0 - w) * 0.5;
        let d = (abs(uv.x - c) - w * 0.5) * res.x;
        inside = 1.0 - smoothstep(-f * 0.5, f * 0.5, d);
    }
    return mix(params.color, src, inside);
}
