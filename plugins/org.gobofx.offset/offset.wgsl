// Offset — the picture slides by a fraction of the frame and what leaves
// one edge comes back in at the other, so the frame stays full and the
// seam shows where it wrapped. 0,0 passes through.
struct Params {
    offset_x: f32, // float — shift right, as a fraction of the width
    offset_y: f32, // float — shift down, as a fraction of the height
}
@group(1) @binding(0) var<uniform> params: Params;

fn src_at(uv: vec2f) -> vec4f {
    return textureSampleLevel(gobofx_input0, gobofx_sampler, uv, 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    let o = clamp(vec2f(params.offset_x, params.offset_y), vec2f(-0.5), vec2f(0.5));
    return src_at(fract(uv - o));
}
