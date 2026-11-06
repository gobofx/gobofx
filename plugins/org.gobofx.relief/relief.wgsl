// Relief — the classic grey emboss. Luma is a height map; a light from one
// side makes the slopes facing it bright and the others dark, over a flat
// mid grey. The colour is gone; only the shape of the tones remains.
struct Params {
    angle: f32,  // float — degrees; where the light comes from, 0 is from the right, 90 from above
    height: f32, // float — px; relief height (tap offset and shading strength)
    amount: f32, // float — 0 is the source, 1 is the full grey relief
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

// Gamma-encoded luma of the premultiplied sample: the height map.
fn height_at(uv: vec2f) -> f32 {
    return pow(max(luma(src_at(uv).rgb), 0.0), 1.0 / 2.2);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let src = src_at(uv);
    let c = unpremultiply(src);
    let h = clamp(params.height, 0.0, 8.0);
    let a = radians(params.angle);
    let light = vec2f(cos(a), -sin(a)); // y up, so 90 is from above
    let d = light * max(h, 1.0) * gobofx_globals.texel;
    // Classic emboss kernel: the difference between the point towards the
    // light and the point away from it, on 50 % grey.
    let diff = height_at(uv - d) - height_at(uv + d);
    let g = clamp(0.5 + diff * h * 0.75, 0.0, 1.0);
    let grey = vec3f(pow(g, 2.2));
    let o = mix(c, grey, clamp(params.amount, 0.0, 1.0));
    return vec4f(o * src.a, src.a);
}
