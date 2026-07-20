#version 430
layout(local_size_x = 8, local_size_y = 8) in;
float agentScanAngle = radians(5);
float agentTurnAngle = radians(5);
float agentTurnThreshold = 0.5;
float decay = 0.0025;

struct Agent { vec4 posVel; };

layout(std430, binding=0) buffer agents_in  { Agent agents[]; } In;
layout(std430, binding=1) buffer agents_out { Agent agents[]; } Out;
layout(rgba8, binding=0) uniform image2D img_output;

float PHI = 1.61803398874989484820459;  // Φ = Golden Ratio   

float hash(in vec2 xy, in float seed){
       return fract(tan(distance(xy*PHI, xy)*seed)*xy.x);
}

bool checkWithinCircle(vec2 p) {

    float dx = abs((p.x-1080.0/2.0));
    float dy = abs((p.y-720.0/2.0));
    float radius = 720.0/2.0;
    bool withinCircle = false;

    if (dx*dx + dy*dy >= radius*radius) {
        return true;
    }
    else {
        return false;
    }
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
    vec2 p = a.posVel.xy;
    vec2 v = a.posVel.zw;

    vec2 size = imageSize(img_output);

    if (checkWithinCircle(p.xy) == true) {
        v.x *= -1;
        v.y *= -1;
    }


    p.xy += v.xy;

    float angle = atan(v.y, v.x);

    // Check pheromone trail front-left
    vec2 simV = v;
    simV.x = cos(angle - agentScanAngle);
    simV.y = sin(angle) - agentScanAngle;
    vec4 leftPix = imageLoad(img_output, ivec2(p.xy + (simV.xy * 30)));

    // Check pheromone trail front-right
    simV = v;
    simV.x = cos(angle + agentScanAngle);
    simV.y = sin(angle + agentScanAngle);
    vec4 rightPix = imageLoad(img_output, ivec2(p.xy + (simV.xy * 30)));

    float rand = hash(v.xy * p.xy, gl_GlobalInvocationID.x * gl_GlobalInvocationID.y);

    float newAngle = (angle + (rightPix.x - leftPix.x) * agentTurnAngle + (rand) * 0.1);
    v.x = cos(newAngle);
    v.y = sin(newAngle);

    imageStore(img_output, ivec2(clamp(p.xy, vec2(0), vec2(size) - 1)), vec4(1));

    a.posVel.xy = p;
    a.posVel.zw = v;
    Out.agents[i] = a;
}
