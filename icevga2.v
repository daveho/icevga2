// Second attempt at ICE40 VGA text output device

module icevga2(input wire nrst,
               input wire ext_osc,
               output wire vsync,
               output wire hsync,
               output wire [3:0] red,
               output wire [3:0] green,
               output wire [3:0] blue);

  `include "timing.vh"

  ////////////////////////////////////////////////////////////////////////
  // PLL and global clock buffer
  ////////////////////////////////////////////////////////////////////////

  wire pll_out;
  wire pll_locked;
  wire clk;

  // The PLL converts the 10 MHz external oscillator signal
  // to the 40 MHz clock used to drive the 800x600 SVGA signals
  pll the_pll(.clock_in(ext_osc),
              .clock_out(pll_out),
              .locked(pll_locked));

  // Use the global clock buffer to distribute the 40 MHz clock
  SB_GB clk_buffer(.USER_SIGNAL_TO_GLOBAL_BUFFER(pll_out),
                   .GLOBAL_BUFFER_OUTPUT(clk));

  ////////////////////////////////////////////////////////////////////////
  // Timing, sync generation
  ////////////////////////////////////////////////////////////////////////

  // hcount and vcount are the coordinates of the pixel to be generated
  // on the next clock
  wire [15:0] hcount;
  wire [15:0] vcount;

  // visible pixels are generated when hvis and vvis are both 1;
  // non-zero color values should only be generated for visible pixels
  wire hvis;
  wire vvis;

  timing_gen the_timing_gen(.nrst(nrst),
                            .clk(clk),
                            .hcount(hcount),
                            .vcount(vcount),
                            .hvis(hvis),
                            .vvis(vvis),
                            .hsync(hsync),
                            .vsync(vsync));

  ////////////////////////////////////////////////////////////////////////
  // Pixel output
  ////////////////////////////////////////////////////////////////////////

  // RGB color output registers;
  // color data will be output to the DAC on the next clock.
  // Note: don't output non-zero values other than in visible region.
  // That would, for example, confuse monitors that support sync on green.
  reg [3:0] red_reg;
  reg [3:0] green_reg;
  reg [3:0] blue_reg;

  assign red = red_reg;
  assign green = green_reg;
  assign blue = blue_reg;

  always @(posedge clk)
    begin

      if (nrst == 1'b0)
        begin
          // reset asserted
          red_reg <= 4'b0;
          green_reg <= 4'b0;
          blue_reg <= 4'b0;
        end

      else
        begin
          if ((hvis & vvis) == 1'b1)
            begin
              // GET NEXT PIXEL COLOR!!!
              // In the future, this should come from another process.
              // For now, just draw a grid.
              if ((hcount[3:0] == 4'b0) | (vcount[3:0] == 4'b0))
                begin
                  red_reg <= 4'hC;
                  green_reg <= 4'hC;
                  blue_reg <= 4'h0;
                end
              else
                begin
                  red_reg <= 4'h0;
                  green_reg <= 4'h0;
                  blue_reg <= 4'h5;
                end
            end
          else
            begin
              // Next pixel is not in the visible area
              red_reg <= 4'b0;
              green_reg <= 4'b0;
              blue_reg <= 4'b0;
            end

        end

    end

endmodule

// vim:ft=verilog:
