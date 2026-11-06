// Scale — `from` shrinks away to a point, or `to` grows out of one, or both.
struct Params {
    mode: u32,     // choice — 0 shrink `from` over `to`, 1 grow `to` over `from`, 2 both
    center: vec2f, // point — the vanishing point
    ease: f32,     // float
}
@group(1) @binding(0) var<uniform> params: Params;

fn from_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0), inside);
}
fn to_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0), inside);
}
fn eased(ease: f32) -> f32 {
    let p = clamp(gobofx_globals.progress, 0.0, 1.0);
    return mix(p, smoothstep(0.0, 1.0, p), clamp(ease, 0.0, 1.0));
}
// Premultiplied `over`.
fn over(top: vec4f, bottom: vec4f) -> vec4f {
    return top + bottom * (1.0 - top.a);
}
fn hash21(p: vec2f) -> f32 {
    var q = fract(p * vec2f(123.34, 456.21));
    q = q + dot(q, q + 45.32);
    return fract(q.x * q.y);
}
// Direction 0..3 → the axis coordinate that grows along the wipe.
fn axis(uv: vec2f, direction: u32) -> f32 {
    switch direction {
        case 1u: { return 1.0 - uv.x; }
        case 2u: { return uv.y; }
        case 3u: { return 1.0 - uv.y; }
        default: { return uv.x; }
    }
}
fn dir_vec(direction: u32) -> vec2f {
    switch direction {
        case 1u: { return vec2f(-1.0, 0.0); }
        case 2u: { return vec2f(0.0, 1.0); }
        case 3u: { return vec2f(0.0, -1.0); }
        default: { return vec2f(1.0, 0.0); }
    }
}

fn scaled(uv: vec2f, s: f32) -> vec2f {
    return params.center + (uv - params.center) / max(s, 1e-4);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = eased(params.ease);
    let a = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
    let b = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    switch params.mode {
        case 1u: {
            let grown = to_at(scaled(uv, t)) * step(1e-4, t);
            let keep = 1.0 - smoothstep(0.9, 1.0, t);
            return over(grown, a * keep);
        }
        case 2u: {
            let shrunk = from_at(scaled(uv, 1.0 - t)) * step(1e-4, 1.0 - t);
            let grown = to_at(scaled(uv, t)) * step(1e-4, t);
            return mix(shrunk, grown, t);
        }
        default: {
            let shrunk = from_at(scaled(uv, 1.0 - t)) * step(1e-4, 1.0 - t);
            return over(shrunk, b);
        }
    }
}
