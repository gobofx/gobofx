// Stars — five-point stars sweep across the cut from left to right. Each one
// swells over its patch of the frame; the patch beneath it becomes `to` while
// it is covered, and the star shrinks away to reveal it.
struct Params {
    count: i32,   // int — stars in the field
    size: f32,    // float — star scale; 1 lets each star cover its own patch
    color: vec4f, // color — premultiplied
    ease: f32,    // float
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
fn rot(p: vec2f, a: f32) -> vec2f {
    let c = cos(a);
    let s = sin(a);
    return vec2f(c * p.x - s * p.y, s * p.x + c * p.y);
}
// Exact signed distance to a five-point star of outer radius `r`; `rf` sets
// how deep the inner vertices sit (0.5 is a classic star).
fn sd_star5(p0: vec2f, r: f32, rf: f32) -> f32 {
    let k1 = vec2f(0.809016994, -0.587785252);
    let k2 = vec2f(-k1.x, k1.y);
    var p = p0;
    p.x = abs(p.x);
    p = p - 2.0 * max(dot(k1, p), 0.0) * k1;
    p = p - 2.0 * max(dot(k2, p), 0.0) * k2;
    p.x = abs(p.x);
    p.y = p.y - r;
    let ba = rf * vec2f(-k1.y, k1.x) - vec2f(0.0, 1.0);
    let h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
    return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let a = from_at(uv);
    let b = to_at(uv);
    let t = eased(params.ease);
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let p = uv * vec2f(aspect, 1.0);
    let n = clamp(params.count, 1, 24);
    let nf = f32(n);
    // A jittered grid keeps the stars spread; the grid follows the frame's aspect.
    let cols = max(1.0, round(sqrt(nf * aspect)));
    let rows = max(1.0, ceil(nf / cols));
    let cell = vec2f(aspect / cols, 1.0 / rows);
    let half_diag = 0.5 * length(cell);
    // At its peak a star's body reaches past its own cell and the jitter around it.
    let peak = clamp(params.size, 0.25, 3.0) * 2.0 * half_diag;
    let aa = 1.5 * gobofx_globals.texel.y;
    let drift = vec2f(0.3 * aspect, 0.0); // the field slides right over the transition
    var cov = 0.0;      // the stars themselves
    var revealed = 0.0; // where a star has already peaked, `to` lies beneath
    for (var i = 0; i < n; i++) {
        let fi = f32(i);
        let g = vec2f(fi - cols * floor(fi / cols), floor(fi / cols));
        let h1 = hash21(g + 0.37);
        let h2 = hash21(g + 7.91);
        let h3 = hash21(g + 3.13);
        let base = (g + 0.5 + (vec2f(h1, h2) - 0.5) * 0.5) * cell;
        // Stars peak in order from left to right, each living for half the transition.
        let pk = 0.25 + 0.5 * clamp(base.x / aspect * 0.8 + h3 * 0.2, 0.0, 1.0);
        let lt = clamp((t - pk) * 2.0 + 0.5, 0.0, 1.0);
        let spin = h2 * 6.2831853 + (h1 - 0.5) * 3.0;
        // The footprint the star had at its peak: once passed, `to` shows through it.
        if (t >= pk) {
            let dp = sd_star5(rot(p - base - drift * (pk - 0.5), spin * pk), peak, 0.4);
            revealed = max(revealed, 1.0 - smoothstep(-aa, aa, dp));
        }
        // A cubed bump keeps the star small for most of its life and swells it late.
        let r = peak * pow(sin(lt * 3.14159265), 3.0);
        if (r <= aa) { continue; } // a star of no size draws nothing, so the endpoints stay exact
        let d = sd_star5(rot(p - base - drift * (t - 0.5), spin * t), r, 0.4);
        cov = max(cov, 1.0 - smoothstep(-aa, aa, d));
    }
    // Whatever no star footprint reached dissolves late, so the end is exact.
    let bg = mix(a, b, max(revealed, smoothstep(0.8, 0.95, t)));
    return over(params.color * cov, bg);
}
