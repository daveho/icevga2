# icevga2: Another attempt at an ICE40-based 800x600 SVGA text mode display

This is a new effort to use an ICE40 device to implement a 100x37 text mode
display (using 800x600 SVGA video with 8x16 characters) for an 8 bit microcomputer.

I learned a lot in my previous effort to do this, and I think I know the
main things I did wrong in the previous effort. I also have an architecture
in mind that (I think!) should be feasible to implement.

I make no guarantees regarding if or when this project might be complete
enough to use. What I have now does output a correct video signal, and I'm
happy with the way sync and timing are handled.

## Hardware details

I'm using an Upduino 3.0 FGPA dev board with a resistor DAC which supports
4 bits of color signal for red/green/blue, so 4096 colors are possible.
I'm using an external 10 MHz oscillator, which feeds a PLL generating a
40 MHz clock internally. (This is the exact dot clock we need for
800x600 SVGA.)

## Programming

The Verilog code is built using [Icestorm](https://clifford.at/icestorm)
via the [APIO](https://github.com/FPGAwars/apio) front end.

To build and upload the design:

```
apio verify
apio build
apio upload
```

## Photos

The circuit (note that the pushbutton is for generating a debounced
reset signal):

![the circuit on a breadboard](img/circuit.jpg)

Test display showing a grid (which demonstrates that the signal is putting
the correct pixels in the correct rows and columns):

![video signal output test on an LCD monitor](img/output_test.jpg)

## Progress Log

12/5/2023: Working on character rendering process. The eventual goal
is to add pixel colors to the pixel buffer based (1) the row of
attribute/character pairs for the current row of characters, (2)
the font memory containing the pixel patterns for each row of the
different character glyphs, and (3) the palette containing the
colors (for lookup of background and foreground colors for the
character attribute.) Current progress is a fixed pattern of
background and foreground colors is display somewhat correctly,
although the pixels are offset one column to the right of where
they should be.

12/2/2023: Implemented a pixel buffer ([pixbuf.v](pixbuf.v)). This is a
1024x16 dual ported RAM (inferred as 4 256x16 block RAMs) from which
pixel color values are read by the main pixel color output process.
So, any pixel color values we put in here will be output to the display
(assuming that they are put in at the appropriate time.) This seems to
work! The pixel buffer is initialized with some 6x6x6 RGB color cube
values, just so we have something to display, since no process is actually
storing data to the pixel buffer yet.

11/28/2023: Made the github project public and added more information
to the readme.

11/25/2023: Moved count, sync, and visibility signal generation to a
separate module ([timing\_gen.v](timing_gen.v)).

11/24/2023: Creation. Initial goal is to display a grid, with the goal of
having the pixels drawn exactly correspond to hcount/vcount values.
This does seem to be working!
