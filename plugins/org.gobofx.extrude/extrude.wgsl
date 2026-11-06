// Extrude — a layer's alpha shape pulled out into a 3D block: the silhouette
// is stamped repeatedly along one direction behind the layer, in a colour
// that darkens with distance from the face so the side reads as shaded.
const MAX_STEPS: i32 = 64;

struct Params {
    depth: f32,   // float — length of the extrusion in pixels; 0 is the source
    angle: f32,   // float — direction the block recedes in, degrees, 0 is right
    color: vec4f, // color — the side colour (premultiplied)
    shading: f32, // float — how much darker the far end is than the face, 0..1
}
@group(1) @binding(0) var<uniform> params: Params;

// Straight colour from a premultiplied sample (0 where fully transparent).
fn unpremultiply(c: vec4f) -> vec3f {
    return select(vec3f(0.0), c.rgb / max(c.a, 1e-6), c.a > 0.0);
}
fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

// Alpha of the source moved by `off` (uv); outside the frame the silhouette
// is empty, not the clamped edge.
fn alpha_shifted(uv: vec2f, off: vec2f) -> f32 {
    let p = uv - off;
    let inside = step(0.0, p.x) * step(p.x, 1.0) * step(0.0, p.y) * step(p.y, 1.0);
    return src_at(p).a * inside;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let depth = clamp(params.depth, 0.0, 100.0);
    if (depth < 0.5) {
        return src;
    }
    let a = radians(params.angle);
    let dir = vec2f(cos(a), sin(a)) * gobofx_globals.texel;
    // One stamp per pixel of depth, up to MAX_STEPS; past that the stamps
    // are spaced wider, which stays solid because alpha is bilinear.
    let steps = min(i32(ceil(depth)), MAX_STEPS);
    let stride = depth / f32(steps);
    var side = 0.0;
    var t_hit = -1.0;
    for (var i = 1; i <= steps; i++) {
        let k = f32(i) * stride;
        let sa = alpha_shifted(uv, dir * k);
        side = max(side, sa);
        // The first stamp that covers this pixel is the nearest slice of the
        // side; its depth sets the shade.
        if (t_hit < 0.0 && sa > 0.02) {
            t_hit = k / depth;
        }
    }
    let shade = 1.0 - clamp(params.shading, 0.0, 1.0) * max(t_hit, 0.0);
    let sa = side * params.color.a;
    let block = vec4f(unpremultiply(params.color) * shade * sa, sa);
    // The face over its own side, both premultiplied.
    return src + block * (1.0 - src.a);
}
