// Page Curl (effect) — the picture peels off from a corner like a page,
// rolling around a cylinder whose axis sweeps towards the opposite corner.
// The back of the page lies over the unpeeled part; what the page has left
// is transparent. `amount` is how far the curl has come: 0 is a no-op, 1
// the page gone.
const PI: f32 = 3.14159265;

struct Params {
    corner: u32,          // choice — the corner that lifts first
    amount: f32,          // float — 0 flat (a no-op), 1 peeled off the frame
    radius: f32,          // float — roll radius as a fraction of the frame height
    back_brightness: f32, // float — the paper's back face, 0 black, 1 white
}
@group(1) @binding(0) var<uniform> params: Params;

// Transparent outside the frame.
fn src_at(uv: vec2f) -> vec4f {
    let inside = all(uv >= vec2f(0.0)) && all(uv <= vec2f(1.0));
    return select(vec4f(0.0), textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0), inside);
}
// The back of the page: paper with a faint ghost of the picture.
fn backside(c: vec4f) -> vec4f {
    let straight = select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
    let paper = vec3f(clamp(params.back_brightness, 0.0, 1.0));
    return vec4f(mix(paper, straight, 0.25) * c.a, c.a);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = clamp(params.amount, 0.0, 1.0);
    if (t <= 0.0) { return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0); }
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let size = vec2f(aspect, 1.0);
    // Work in frame-height units so the roll is round.
    var c: vec2f;
    switch params.corner {
        case 1u: { c = vec2f(0.0, 1.0); }
        case 2u: { c = vec2f(aspect, 0.0); }
        case 3u: { c = vec2f(0.0, 0.0); }
        default: { c = vec2f(aspect, 1.0); }
    }
    let diag = (size - c) - c;        // corner → opposite corner
    let len = length(diag);
    let n = diag / len;               // into the page
    let m = vec2f(-n.y, n.x);         // along the roll's axis
    let r = clamp(params.radius, 0.05, 0.5);
    let s = t * (len + 2.0 * r);      // where the page leaves the surface
    let rel = uv * size - c;
    let d = dot(rel, n);
    let mm = dot(rel, m);
    let e = s - d;                    // > 0: inside the peeled region
    let grown = smoothstep(0.0, r, s); // the fold's shadow fades in as the roll forms

    var top = vec4f(0.0);
    if (e <= 0.0) {
        // Unpeeled page — unless the rolled-over sheet lies on top of it.
        let dp = 2.0 * s - d - PI * r;
        let p = (c + n * dp + m * mm) / size;
        if (dp >= 0.0 && all(p >= vec2f(0.0)) && all(p <= vec2f(1.0))) {
            top = backside(src_at(p));
        } else {
            top = textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
            let sh = 0.35 * grown * (1.0 - smoothstep(0.0, 0.6 * r, -e));
            top = vec4f(top.rgb * (1.0 - sh), top.a);
        }
    } else if (e < r) {
        // On the roll: the back face on top, else the front face, else nothing.
        let th = asin(min(e / r, 1.0));
        let dp_back = s - r * (PI - th);
        let dp_front = s - r * th;
        let pb = (c + n * dp_back + m * mm) / size;
        let pf = (c + n * dp_front + m * mm) / size;
        if (dp_back >= 0.0 && all(pb >= vec2f(0.0)) && all(pb <= vec2f(1.0))) {
            top = backside(src_at(pb));
            top = vec4f(top.rgb * (1.0 - 0.4 * sin(th)), top.a);
        } else if (dp_front >= 0.0 && all(pf >= vec2f(0.0)) && all(pf <= vec2f(1.0))) {
            top = src_at(pf);
            top = vec4f(top.rgb * (1.0 - 0.35 * sin(th)), top.a);
        }
    }
    return top;
}
