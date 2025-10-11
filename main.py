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

WINDOW_WIDTH = 720
WINDOW_HEIGHT = 480

NUM_AGENTS: int = 64000

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

        self.pheromone = self.ctx.texture((WINDOW_WIDTH, WINDOW_HEIGHT), components=4)
        self.pheromone.filter = (arcade.gl.NEAREST, arcade.gl.NEAREST)
        data = np.zeros((WINDOW_WIDTH, WINDOW_HEIGHT, 4), dtype=np.uint8)
        data[..., 3] = 255
        self.pheromone.write(data.tobytes())

        vertices = array("f", [
            -1.0, -1.0,
            1.0,  -1.0,
            -1.0,  1.0,
            -1.0, 1.0,
            1.0, -1.0,
            1.0, 1.0
        ])

        vbo = self.ctx.buffer(data=vertices)

        self.quad = self.ctx.geometry([BufferDescription(vbo, "2f", ["in_vert"])])

        vertex_shader_source = Path(Path(__file__).resolve().parent/"Shaders/vertex_shader.glsl").read_text()
        fragment_shader_source = Path(Path(__file__).resolve().parent/"Shaders/fragment_shader.glsl").read_text()

        self.program = self.ctx.program(
            vertex_shader=vertex_shader_source,
            fragment_shader=fragment_shader_source,
        )

        compute_shader_source = Path(Path(__file__).resolve().parent/"Shaders/compute_shader.glsl").read_text()

        self.group_x = (WINDOW_WIDTH + 7)//8
        self.group_y = (WINDOW_HEIGHT + 7)//8

        self.compute_shader_defines = {
            "NUM_AGENTS":NUM_AGENTS
        }

        # Preprocess the source by replacing each define with its value as a string
        for templating_token, value in self.compute_shader_defines.items():
            compute_shader_source = compute_shader_source.replace(templating_token, str(value))

        self.compute_shader = self.ctx.compute_shader(source=compute_shader_source)


    def on_draw(self):

        self.clear()

        self.ctx.enable(self.ctx.BLEND)

        self.ssbo_previous.bind_to_storage_buffer(binding=0)
        self.ssbo_current.bind_to_storage_buffer(binding=1)
        self.pheromone.bind_to_image(0, read=False, write=True)

        self.compute_shader.run(group_x=self.group_x, group_y=self.group_y)

        self.pheromone.use(0)
        self.quad.render(self.program)

        self.ssbo_previous, self.ssbo_current = self.ssbo_current, self.ssbo_previous




if __name__ == "__main__":
    app = SlimeMouldSimulationWindow()
    arcade.run()
        
