// Module to generate the hcount/vcount, hvis/vvis, and hsync/vsync signals

// The current hcount and vcount values indicate the coordinates of the pixel
// to be output on the next clock. Note that non-zero color values should
// not be output unless hvis and vvis are both 1 (meaning that the pixel
// is actually in the visible region.)

// The hcount_ahead1 output is (as the name suggests) one count ahead
// of hcount. The intention is that this can be used to get data from
// the pixel buffer one cycle ahead of when the pixel color will need
// to be output by the pixel output process.

module timing_gen(input wire nrst,
                  input wire clk,
                  output wire [15:0] hcount,
                  output wire [15:0] vcount,
                  output wire [15:0] hcount_ahead1,
                  output wire hvis,
                  output wire vvis,
                  output wire hsync,
                  output wire vsync);

  `include "timing.vh"

  // Pixel coordinates

  reg [15:0] hcount_reg; // horizontal count; if in range 0..799, pixel can be generated
  reg [15:0] vcount_reg; // vertical count; in in range 0..599, pixel can be generated
  reg [15:0] hcount_ahead1_reg;

  assign hcount = hcount_reg;
  assign vcount = vcount_reg;
  assign hcount_ahead1 = hcount_ahead1_reg;

  // hvis and vvis

  reg hvis_reg;
  reg vvis_reg;

  assign hvis = hvis_reg;
  assign vvis = vvis_reg;

  // hsync and vsync

  reg hsync_reg;
  reg vsync_reg;

  assign vsync = vsync_reg;
  assign hsync = hsync_reg;

  always @(posedge clk)
    begin

      if (nrst == 1'b0)
        begin
          // reset asserted
          hcount_reg <= 16'd0;
          vcount_reg <= 16'd0;
          hcount_ahead1_reg <= 16'd1;
          hsync_reg <= 1'b0;
          vsync_reg <= 1'b0;
          hvis_reg <= 1'b1;
          vvis_reg <= 1'b1;
        end

      else // (nrst == 1'b0)
        begin
          // not in reset, so update hcount_reg/vcount_reg, generate sync signals

          if (hcount_reg == H_VISIBLE_END)
            begin
              hcount_reg <= hcount_reg + 1;
              hcount_ahead1_reg <= hcount_ahead1 + 1;
              hvis_reg <= 1'b0; // end of visible horizontal area reached
            end
          else if (hcount_reg == H_FRONT_PORCH_END)
            begin
              hcount_reg <= hcount_reg + 1;
              hcount_ahead1_reg <= hcount_ahead1 + 1;
              hsync_reg <= 1'b1; // hsync pulse begins
            end
          else if (hcount_reg == H_SYNC_PULSE_END)
            begin
              hcount_reg <= hcount_reg + 1;
              hcount_ahead1_reg <= hcount_ahead1 + 1;
              hsync_reg <= 1'b0; // hsync pulse ends
            end
          else if (hcount_reg == H_BACK_PORCH_END-1)
            begin
              // Special case: this is the second-to-last pixel, so
              // hcount_ahead1_reg should be set to 0 here.
              // hcount just advances by 1 as usual.
              hcount_reg <= hcount_reg + 1;
              hcount_ahead1_reg <= 16'd0;
            end
          else if (hcount_reg == H_BACK_PORCH_END)
            begin
              // line ends, start next line
              hcount_reg <= 16'd0;
              hcount_ahead1_reg <= 16'd1;
              hvis_reg <= 1'b1; // next pixel is in visible horizontal area

              if (vcount_reg == V_VISIBLE_END)
                begin
                  vcount_reg <= vcount_reg + 1;
                  vvis_reg <= 1'b0; // end of visible vertical area reached
                end
              else if (vcount_reg == V_FRONT_PORCH_END)
                begin
                  vcount_reg <= vcount_reg + 1;
                  vsync_reg <= 1'b1; // vsync pulse begins
                end
              else if (vcount_reg == V_SYNC_PULSE_END)
                begin
                  vcount_reg <= vcount_reg + 1;
                  vsync_reg <= 1'b0; // vsync pulse ends
                end
              else if (vcount_reg == V_BACK_PORCH_END)
                begin
                  vcount_reg <= 16'd0; // end of frame, begin next frame
                  vvis_reg <= 1'b1; // next pixel is in visible vertical area
                end
              else
                begin
                  // start next line
                  vcount_reg <= vcount_reg + 1;
                end
            end
          else
            begin
              // start next pixel in line
              hcount_reg <= hcount_reg + 1;
              hcount_ahead1_reg <= hcount_ahead1 + 1;
            end

        end // (nrst == 1'b0)

    end // always @(posedge clk)
endmodule

// vim:ft=verilog:
