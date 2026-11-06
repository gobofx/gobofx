// Glass Block — the frame seen through a wall of glass bricks. Each block is
// flat in the middle and curves at its rim, where it refracts the picture
// back towards the block's own centre, so the image repeats a little at
// every joint; the joints themselves are shaded. Pixels pulled from outside
// the frame repeat the edge. Amount 0 is a no-op.
struct Params {
    size: f32,     // float — block size, in frame heights
    amount: f32,   // float — refraction, 0 is a no-op
    softness: f32, // float — how much of each block is curved rim, 0.05 .. 1
}
@group(1) @binding(0) var<uniform> params: Params;

// Clamp-to-edge: a pixel pulled from outside the frame repeats the edge.
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let aspect = gobofx_globals.resolution.x / gobofx_globals.resolution.y;
    let size = max(params.size, 0.03);
    let a = clamp(params.amount, 0.0, 1.0);
    let s = clamp(params.softness, 0.05, 1.0);
    let p = uv * vec2f(aspect, 1.0) / size;
    let cell = floor(p);
    let l = (p - cell) * 2.0 - 1.0; // -1..1 inside the block
    // Rim profile per axis: 0 across the flat middle, 1 at the joint. The
    // softness is how far into the block the curve reaches.
    let rim = smoothstep(vec2f(1.0 - s), vec2f(1.0), abs(l));
    // Refract towards the block's centre: the rim shows a magnified copy of
    // the interior, as the thick edge of a real brick does.
    let ls = l - sign(l) * rim * a;
    let col = src_at((cell + (ls + 1.0) * 0.5) * size / vec2f(aspect, 1.0));
    // Shading: the rim darkens a little, the joint line more. Exactly 1 at
    // amount 0 and never above 1, so premultiplied colour stays within alpha.
    let edge = max(rim.x, rim.y);
    let joint = max(smoothstep(0.92, 1.0, abs(l.x)), smoothstep(0.92, 1.0, abs(l.y)));
    let shade = 1.0 - a * (0.12 * edge + 0.3 * joint);
    return vec4f(col.rgb * shade, col.a);
}
