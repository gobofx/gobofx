// Solid — one colour, the whole frame. Alpha below 1 makes it a tint layer.
struct Params {
    color: vec4f, // color — premultiplied
}
@group(1) @binding(0) var<uniform> params: Params;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
    return params.color;
}
