#version 430

// Set up our compute groups.
// The COMPUTE_SIZE_X and COMPUTE_SIZE_Y values will be replaced
// by the Python code with actual values. This does not happen
// automatically, and must be called manually.
layout(local_size_x=COMPUTE_SIZE_X, local_size_y=COMPUTE_SIZE_Y) in;

// Input uniforms would go here if you need them.
// The examples below match the ones commented out in main.py
//uniform vec2 screen_size;
//uniform float frame_time;

// Structure of the agent data
struct Agent
{
    vec4 pos;
    vec4 vel;
    vec4 color;
};

// Input buffer
layout(std430, binding=0) buffer agents_in
{
    Agent agents[];
} In;


// Output buffer
layout(std430, binding=1) buffer agents_out
{
    Agent agents[];
} Out;

layout(std430, binding = 2) buffer pheromone
{
    float pheromoneMap[1080][720];
} P;

void main()
{
    int curAgentIndex = int(gl_GlobalInvocationID);

    Agent in_agent = In.agents[curAgentIndex];

    vec4 p = in_agent.pos.xyzw;
    vec4 v = in_agent.vel.xyzw;
    
    P.pheromoneMap[int(round(p.x))][int(round(p.y))] = 1.0;


    if (p.x > 1080)
        v.x = -v.x;
    else if (p.x < 0)
        v.x = -v.x;
    if (p.y > 720)
        v.y = -v.y;
    else if (p.y < 0)
        v.y = -v.y;

    // Move the agent according to the current force
    p.xy += v.xy;


    Agent out_agent;
    out_agent.pos.xyzw = p.xyzw;
    out_agent.vel.xyzw = v.xyzw;

    vec4 c = in_agent.color.xyzw;
    out_agent.color.xyzw = c.xyzw;

    Out.agents[curAgentIndex] = out_agent;
}