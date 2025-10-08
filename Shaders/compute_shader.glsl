#version 430
layout(local_size_x = 8, local_size_y = 8) in;

struct Agent { vec4 pos; vec4 vel; };

layout(std430, binding=0) buffer agents_in  { Agent agents[]; } In;
layout(std430, binding=1) buffer agents_out { Agent agents[]; } Out;
layout(rgba8, binding=0) uniform image2D img_output;

void main() {
    uint i = gl_GlobalInvocationID.x;
    vec4 pixel = imageLoad(img_output, ivec2(gl_GlobalInvocationID.xy));
    vec4 fadedPixel = pixel - vec4(0.01);

    imageStore(img_output, ivec2(gl_GlobalInvocationID.xy), fadedPixel);
    if (i >= 200u) return;

    Agent a = In.agents[i];
    vec4 p = a.pos;
    vec4 v = a.vel;

    ivec2 size = imageSize(img_output);
    if (p.x < 0 || p.x > size.x) v.x = -v.x;
    if (p.y < 0 || p.y > size.y) v.y = -v.y;
    p.xy += v.xy;

    imageStore(img_output, ivec2(clamp(p.xy, vec2(0), vec2(size) - 1)), vec4(1));

    a.pos = p;
    a.vel = v;
    Out.agents[i] = a;
}
