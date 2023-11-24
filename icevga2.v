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

  reg [15:0] hcount; // horizontal count; if in range 0..799, pixel can be generated
  reg [15:0] vcount; // vertical count; in in range 0..599, pixel can be generated
  reg hsync_reg;
  reg vsync_reg;

  assign vsync = vsync_reg;
  assign hsync = hsync_reg;

  always @(posedge clk)
    begin

      if (nrst == 1'b0)
        begin
          // reset asserted
          hcount <= 16'b0;
          vcount <= 16'b0;
          hsync_reg <= 1'b0;
          vsync_reg <= 1'b0;
        end

      else // (nrst == 1'b0)
        begin
          // not in reset, so update hcount/vcount, generate sync signals

          if (hcount == H_VISIBLE_END)
            begin
              hcount <= hcount + 1;
            end
          else if (hcount == H_FRONT_PORCH_END)
            begin
              hcount <= hcount + 1;
              hsync_reg <= 1'b1; // hsync pulse begins
            end
          else if (hcount == H_SYNC_PULSE_END)
            begin
              hcount <= hcount + 1;
              hsync_reg <= 1'b0; // hsync pulse ends
            end
          else if (hcount == H_BACK_PORCH_END)
            begin
              // line ends, start next line
              hcount <= 16'b0;

              if (vcount == V_VISIBLE_END)
                begin
                  vcount <= vcount + 1;
                end
              else if (vcount == V_FRONT_PORCH_END)
                begin
                  vcount <= vcount + 1;
                  vsync_reg <= 1'b1; // vsync pulse begins
                end
              else if (vcount == V_SYNC_PULSE_END)
                begin
                  vcount <= vcount + 1;
                  vsync_reg <= 1'b0; // vsync pulse ends
                end
              else if (vcount == V_BACK_PORCH_END)
                begin
                  vcount <= 16'b0; // end of frame, begin next frame
                end
              else
                begin
                  // start next line
                  vcount <= vcount + 1;
                end
            end
          else
            begin
              // start next pixel in line
              hcount <= hcount + 1;
            end

        end // (nrst == 1'b0)

    end // always @(posedge clk)

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

  reg hvis; // in visible part of line horizontally?
  reg vvis; // in visible part of frame vertically?

  always @(posedge clk)
    begin

      if (nrst == 1'b0)
        begin
          // reset asserted
          red_reg <= 4'b0;
          green_reg <= 4'b0;
          blue_reg <= 4'b0;
          hvis <= 1'b1;
          vvis <= 1'b1;
        end

      else
        begin
          // update horizontal visibility
          if (hcount == H_VISIBLE_END)
            begin
              hvis <= 1'b0; // end of horizontal visible area
            end
          else if (hcount == H_BACK_PORCH_END)
            begin
              hvis <= 1'b1; // end of horizontal back porch, will start new line

              // update vertical visibility
              if (vcount == V_VISIBLE_END)
                begin
                  vvis <= 1'b0; // end of vertical visible area
                end
              else if (vcount == V_BACK_PORCH_END)
                begin
                  vvis <= 1'b1; // end of frame, will start new frame
                end
            end

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
