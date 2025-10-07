# # # # # # # # # # # # # # # #
#   A SLIME MOULD SIMULATION  #
# INSPIRED BY Sebastian Lague #
#        Dylan Mortimer       #
# # # # # # # # # # # # # # # #

import random
import math
import numpy as np
from array import array
from pathlib import Path
from typing import Generator, Tuple

import arcade
from arcade.gl import BufferDescription

WINDOW_WIDTH = 1080
WINDOW_HEIGHT = 720

# Size of performance graphs in pixels
GRAPH_WIDTH = 200
GRAPH_HEIGHT = 120
GRAPH_MARGIN = 5

NUM_AGENTS: int = 1000

def gen_initial_data(
    screen_size: Tuple[int, int],
    num_agents: int = NUM_AGENTS,
) -> array:
    width, height = screen_size

    def _data_generator() -> Generator[float, None, None]:

        for i in range(num_agents):
            #Position
            yield random.randrange(0,width)
            yield random.randrange(0,height)
            yield 0.0
            yield 6.0

            #Velocity
            angle = random.random()*2*math.pi
            yield math.cos(angle)
            yield math.sin(angle)
            yield 0.0
            yield 0.0

            #Colour
            yield 1.0
            yield 1.0
            yield 1.0
            yield 1.0

    return array('f', _data_generator())

class SlimeMouldSimulationWindow(arcade.Window):

    def __init__(self):
        super().__init__(
            WINDOW_WIDTH, WINDOW_HEIGHT,
            "Slime Mould Simulation",
            gl_version=(4,3),
            resizable=False
        )
        
        self.center_window()

        initial_data = gen_initial_data(self.get_size())
        self.ssbo_previous = self.ctx.buffer(data=initial_data)
        self.ssbo_current = self.ctx.buffer(data=initial_data)
        self.ssbo_pheromone_previous = self.ctx.buffer(data=np.zeros((self.get_size()), dtype=float))
        self.ssbo_pheromone_current = self.ctx.buffer(data=np.zeros((self.get_size()), dtype=float))

        buffer_format = '4f 4x4 4f'

        attributes = ['in_vertex', 'in_color']

        self.vao_previous = self.ctx.geometry(
            [BufferDescription(self.ssbo_previous, buffer_format, attributes)],
            mode=self.ctx.POINTS,
        )

        self.vao_current = self.ctx.geometry(
            [BufferDescription(self.ssbo_current, buffer_format, attributes)],
            mode=self.ctx.POINTS,
        )

        vertex_shader_source = Path(r"C:\Users\mortd\VS Code\Python\Slime Mould Simulation\Shaders\vertex_shader.glsl").read_text()
        fragment_shader_source = Path(r"C:\Users\mortd\VS Code\Python\Slime Mould Simulation\Shaders\fragment_shader.glsl").read_text()
        geometry_shader_source = Path(r"C:\Users\mortd\VS Code\Python\Slime Mould Simulation\Shaders\geometry_shader.glsl").read_text()


        self.program = self.ctx.program(
            vertex_shader=vertex_shader_source,
            fragment_shader=fragment_shader_source,
            geometry_shader=geometry_shader_source
        )

        compute_shader_source = Path(r'C:\Users\mortd\VS Code\Python\Slime Mould Simulation\Shaders\compute_shader.glsl').read_text()

        self.group_x = 256
        self.group_y = 1

        self.compute_shader_defines = {
            'COMPUTE_SIZE_X': self.group_x,
            'COMPUTE_SIZE_Y': self.group_y
        }

        for templating_token, value in self.compute_shader_defines.items():
            compute_shader_source = compute_shader_source.replace(templating_token, str(value))
        self.compute_shader = self.ctx.compute_shader(source=compute_shader_source)

        # --- Create the FPS graph

        # Enable timings for the performance graph
        arcade.enable_timings()

        # Create a sprite list to put the performance graph into
        self.perf_graph_list = arcade.SpriteList()

        # Create the FPS performance graph
        graph = arcade.PerfGraph(GRAPH_WIDTH, GRAPH_HEIGHT, graph_data="FPS")
        graph.position = GRAPH_WIDTH / 2, self.height - GRAPH_HEIGHT / 2
        self.perf_graph_list.append(graph)

    def on_draw(self):
        # Clear the screen
        self.clear()
        # Enable blending so our alpha channel works
        self.ctx.enable(self.ctx.BLEND)

        # Bind buffers
        self.ssbo_previous.bind_to_storage_buffer(binding=0)
        self.ssbo_current.bind_to_storage_buffer(binding=1)
        self.ssbo_pheromone_previous.bind_to_storage_buffer(binding=2)
        self.ssbo_pheromone_current.bind_to_storage_buffer(binding=3)


        # If you wanted, you could set input variables for compute shader
        # as in the lines commented out below. You would have to add or
        # uncomment corresponding lines in compute_shader.glsl
        # self.compute_shader["screen_size"] = self.get_size()
        # self.compute_shader["frame_time"] = self.frame_time

        # Run compute shader to calculate new positions for this frame
        self.compute_shader.run(group_x=self.group_x, group_y=self.group_y)

        # Draw the current star positions
        self.vao_current.render(self.program)

        # Swap the buffer pairs.
        # The buffers for the current state become the initial state,
        # and the data of this frame's initial state will be overwritten.
        self.ssbo_previous, self.ssbo_current = self.ssbo_current, self.ssbo_previous
        self.ssbo_pheromone_previous, self.ssbo_pheromone_current = self.ssbo_pheromone_current, self.ssbo_pheromone_previous
        self.vao_previous, self.vao_current = self.vao_current, self.vao_previous

        # Draw the graphs
        self.perf_graph_list.draw()



if __name__ == "__main__":
    app = SlimeMouldSimulationWindow()
    arcade.run()
        
