// Neon — the edges of the picture become glowing tubes in one colour over a
// darkened source. Pass 1 finds the edges (Sobel on premultiplied luma, so
// alpha edges count) and tints them; two passes blur that into a halo;
// pass 4 lays the crisp tube and its halo over the dimmed source. Intensity
// 0 with darken 0 passes through.
override DIR_X: f32 = 1.0;
override DIR_Y: f32 = 0.0;
const MAX_RADIUS: f32 = 64.0;

struct Params {
    color: vec4f,   // color — the tube's colour
    radius: f32,    // float — halo spread in pixels
    intensity: f32, // float — strength of tube and halo
    darken: f32,    // float — how far the source is dimmed underneath
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn luma(c: vec3f) -> f32 {
    return dot(c, vec3f(0.2126, 0.7152, 0.0722));
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}
fn y_at(uv: vec2f) -> f32 {
    return luma(src_at(uv).rgb);
}

// Sobel edge strength, 0..1, from the source's premultiplied luma.
fn edge(uv: vec2f) -> f32 {
    let t = gobofx_globals.texel;
    let tl = y_at(uv + vec2f(-t.x, -t.y));
    let tc = y_at(uv + vec2f(0.0, -t.y));
    let tr = y_at(uv + vec2f(t.x, -t.y));
    let ml = y_at(uv + vec2f(-t.x, 0.0));
    let mr = y_at(uv + vec2f(t.x, 0.0));
    let bl = y_at(uv + vec2f(-t.x, t.y));
    let bc = y_at(uv + vec2f(0.0, t.y));
    let br = y_at(uv + vec2f(t.x, t.y));
    let gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
    let gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);
    // A unit step gives a magnitude of 4; the knee ignores grain and gradients.
    return smoothstep(0.04, 0.25, length(vec2f(gx, gy)) * 0.25);
}

@fragment
fn fs_edges(@location(0) uv: vec2f) -> @location(0) vec4f {
    let e = edge(uv) * params.color.a;
    return vec4f(unpremultiply(params.color) * e, e);
}

@fragment
fn fs_blur(@location(0) uv: vec2f) -> @location(0) vec4f {
    let r = clamp(params.radius, 1.0, MAX_RADIUS);
    let sigma = r / 2.5;
    let inv = 1.0 / (2.0 * sigma * sigma);
    let dir = vec2f(DIR_X, DIR_Y) * gobofx_globals.texel;
    let n = i32(ceil(r));
    var acc = vec4f(0.0);
    var wsum = 0.0;
    for (var i = -n; i <= n; i++) {
        let x = f32(i);
        let w = exp(-x * x * inv);
        acc += src_at(uv + dir * x) * w;
        wsum += w;
    }
    return acc / wsum;
}

@fragment
fn fs_compose(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let halo = textureSampleLevel(gobofx_input1, gobofx_sampler, uv, 0.0);
    let k = clamp(params.intensity, 0.0, 3.0);
    let d = clamp(params.darken, 0.0, 1.0);
    // The crisp tube is the unblurred edge, recomputed here rather than
    // carried through a fifth pass.
    let core = edge(uv) * params.color.a;
    let tube = vec4f(unpremultiply(params.color) * core, core);
    let glow = (tube + halo) * k;
    let a = clamp(src.a + glow.a, 0.0, 1.0);
    return vec4f(src.rgb * (1.0 - d) + glow.rgb, a);
}
