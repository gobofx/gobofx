// Album — the frame is an open photo album with its spine down the middle;
// one page turns over, `from` on its face and `to` on its back, revealing
// `to` beneath. A soft shadow falls ahead of the turning page.
struct Params {
    direction: u32,   // choice — 0 the right page turns left, 1 the left page turns right
    perspective: f32, // float — how much the lifted page edge comes toward the viewer
    shadow: f32,      // float — strength of the page shadow and the gutter shade
    ease: f32,        // float
}
@group(1) @binding(0) var<uniform> params: Params;

fn eased(ease: f32) -> f32 {
    let p = clamp(gobofx_globals.progress, 0.0, 1.0);
    return mix(p, smoothstep(0.0, 1.0, p), clamp(ease, 0.0, 1.0));
}
// The page logic works in a space where the turning page is always on the
// right; `mirror` maps back to the frame when the left page turns instead.
fn from_m(p: vec2f, mirror: bool) -> vec4f {
    let q = select(p, vec2f(1.0 - p.x, p.y), mirror);
    return textureSampleLevel(gobofx_input0, gobofx_sampler, q, 0.0);
}
fn to_m(p: vec2f, mirror: bool) -> vec4f {
    let q = select(p, vec2f(1.0 - p.x, p.y), mirror);
    return textureSampleLevel(gobofx_input1, gobofx_sampler, q, 0.0);
}
// Distance along the page from the spine for a pixel `px` from the spine,
// with the page foreshortened by |cos| and its near edge enlarged by the
// perspective term `ks`: px = u * ac * (1 + ks * u).
fn page_u(px: f32, ac: f32, ks: f32) -> f32 {
    if (ks * ac < 1e-5) { return px / ac; }
    let disc = ac * ac + 4.0 * ks * ac * px;
    return (-ac + sqrt(max(disc, 0.0))) / (2.0 * ks * ac);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let t = eased(params.ease);
    let mirror = params.direction == 1u;
    let x = select(uv.x, 1.0 - uv.x, mirror);
    let y = uv.y;
    // A page lifts slowly and falls fast, so it is past vertical only late in the turn.
    let theta = pow(t, 1.3) * 3.14159265;
    let c = cos(theta);
    let s = sin(theta);
    let ks = clamp(params.perspective, 0.0, 1.0) * 0.8 * s;
    let sh = clamp(params.shadow, 0.0, 1.0);
    // The pages lying flat: `from` still on the left, `to` already under the turning page.
    var under = select(from_m(vec2f(x, y), mirror), to_m(vec2f(x, y), mirror), x >= 0.5);
    // Shadow ahead of the page's projected free edge, and a gutter shade along the spine.
    let edge = 0.5 + 0.5 * c * (1.0 + 0.5 * ks);
    let ahead = select(edge - x, x - edge, c > 0.0);
    let width = 0.06 + 0.1 * s;
    let shade = sh * s * (1.0 - smoothstep(0.0, width, max(ahead, 0.0)));
    let gutter = sh * s * (1.0 - smoothstep(0.0, 0.06, abs(x - 0.5)));
    under = vec4f(under.rgb * (1.0 - 0.55 * shade) * (1.0 - 0.3 * gutter), under.a);
    // The turning page, hinged at the spine: `u` runs from the spine to the free
    // edge, and the free edge comes toward the viewer as the page lifts.
    if (c > 1e-4 && x >= 0.5) {
        let u = page_u(x - 0.5, c, ks);
        let v = (y - 0.5) / (1.0 + ks * u);
        if (u <= 0.5 && abs(v) <= 0.5) {
            let page = from_m(vec2f(0.5 + u, v + 0.5), mirror);
            let bend = 1.0 - 0.25 * sh * s * (1.0 - 2.0 * u);
            return vec4f(page.rgb * bend, page.a);
        }
    } else if (c < -1e-4 && x < 0.5) {
        let u = page_u(0.5 - x, -c, ks);
        let v = (y - 0.5) / (1.0 + ks * u);
        if (u <= 0.5 && abs(v) <= 0.5) {
            let page = to_m(vec2f(0.5 - u, v + 0.5), mirror);
            let bend = 1.0 - 0.25 * sh * s * (1.0 - 2.0 * u);
            return vec4f(page.rgb * bend, page.a);
        }
    }
    return under;
}
