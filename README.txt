Another attempt at an ICE40-based 800x600 SVGA text mode display.

Log:

11/25/2023: Moved count, sync, and visibility signal generation to a
separate module (timing_gen.v).

11/24/2023: Creation. Initial goal is to display a grid, with the goal of
having the pixels drawn exactly correspond to hcount/vcount values.
This does seem to be working!
