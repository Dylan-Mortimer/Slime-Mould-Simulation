#version 430
layout(local_size_x = 8, local_size_y = 8) in;
float agentScanAngle = radians(10);
float agentTurnAngle = radians(5);
float agentTurnThreshold = 0.5;
float decay = 0.0025;

struct Agent { vec4 pos; vec4 vel; };

layout(std430, binding=0) buffer agents_in  { Agent agents[]; } In;
layout(std430, binding=1) buffer agents_out { Agent agents[]; } Out;
layout(rgba8, binding=0) uniform image2D img_output;

float hash(vec2 p) {
    p = fract(p * vec2(5.3983, 5.4427));
    p += dot(p, p.yx);
    return fract(p.x * p.y * 93.758);
}

void main() {
    uint i = gl_GlobalInvocationID.x;
    vec4 diffusePixel = vec4(0);
    for (int k =-1; k < 2; ++k) {
        for (int j = -1; j < 2; ++j) {
            diffusePixel += 0.111 * imageLoad(img_output, ivec2(gl_GlobalInvocationID.xy + vec2(k, j)));
        }
    }

    imageStore(img_output, ivec2(gl_GlobalInvocationID.xy), diffusePixel - vec4(decay));
    if (i >= NUM_AGENTSu) return;

    Agent a = In.agents[i];
    vec4 p = a.pos;
    vec4 v = a.vel;

    ivec2 size = imageSize(img_output);

    if (p.x < 0) {
        float randAngle = mod(hash(gl_GlobalInvocationID.xy * p.xy * v.xy), (radians(180)-radians(90)));
        p.x = 0;
        v.x = randAngle;
        v.y = randAngle;
    }
    else if (p.x > size.x) {
        float randAngle = mod(hash(gl_GlobalInvocationID.xy * p.xy * v.xy), (radians(180)+radians(90)));
        p.x = size.x;
        v.x = randAngle;
        v.y = randAngle;
    }
    else if (p.y < 0) {
        float randAngle = mod(hash(gl_GlobalInvocationID.xy * p.xy * v.xy), (radians(180)));
        p.y = 0;
        v.x = randAngle;
        v.y = randAngle;
    }
    else if (p.y > size.y) {
        float randAngle = mod(hash(gl_GlobalInvocationID.xy * p.xy * v.xy), (radians(180)+radians(180)));
        p.y = size.y;
        v.x = randAngle;
        v.y = randAngle;
    }

    p.xy += v.xy;

    float angle = atan(v.y, v.x);

    // Check pheromone trail front-left
    vec4 simV = v;
    simV.x = cos(angle - agentScanAngle);
    simV.y = sin(angle) - agentScanAngle;
    vec4 leftPix = imageLoad(img_output, ivec2(p.xy + (simV.xy * 30)));

    // Check pheromone trail front-right
    simV = v;
    simV.x = cos(angle + agentScanAngle);
    simV.y = sin(angle + agentScanAngle);
    vec4 rightPix = imageLoad(img_output, ivec2(p.xy + (simV.xy * 30)));

    v.x = cos(angle + (rightPix.x - leftPix.x) * agentTurnAngle);
    v.y = sin(angle + (rightPix.x - leftPix.x) * agentTurnAngle);

    // if (float(leftPix.x) >= agentTurnThreshold && float(rightPix.x) < agentTurnThreshold) {
    //     v.x = cos(angle - agentTurnAngle);
    //     v.y = sin(angle - agentTurnAngle);
    // }
    // else if (float(leftPix.x) < agentTurnThreshold && float(rightPix.x) >= agentTurnThreshold) {
    //     v.x = cos(angle + agentTurnAngle);
    //     v.y = sin(angle + agentTurnAngle);
    // }

    imageStore(img_output, ivec2(clamp(p.xy, vec2(0), vec2(size) - 1)), vec4(1));

    a.pos = p;
    a.vel = v;
    Out.agents[i] = a;
}
