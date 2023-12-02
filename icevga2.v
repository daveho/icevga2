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
  wire [15:0] hcount_ahead1;

  // visible pixels are generated when hvis and vvis are both 1;
  // non-zero color values should only be generated for visible pixels
  wire hvis;
  wire vvis;

  timing_gen the_timing_gen(.nrst(nrst),
                            .clk(clk),
                            .hcount(hcount),
                            .vcount(vcount),
                            .hcount_ahead1(hcount_ahead1),
                            .hvis(hvis),
                            .vvis(vvis),
                            .hsync(hsync),
                            .vsync(vsync));

  ////////////////////////////////////////////////////////////////////////
  // Pixel buffer
  ////////////////////////////////////////////////////////////////////////

  // The pixel output process reads from the pixel buffer
  wire pixbuf_rd;
  wire [9:0] pixbuf_rd_addr;
  wire [15:0] pixbuf_rd_data;

  wire pixbuf_wr;             // eventually this will be a reg
  wire [9:0] pixbuf_wr_addr;  // eventually this will be a reg
  wire [15:0] pixbuf_wr_data; // eventually this will be a reg

  // For now, there are no writes to the pixbuf
  assign pixbuf_wr = 1'b1;
  assign pixbuf_wr_addr = 10'd0;
  assign pixbuf_wr_data = 16'd0;

  pixbuf the_pixbuf(.nrst(nrst),
                    .clk(clk),
                    .rd(pixbuf_rd),
                    .rd_addr(pixbuf_rd_addr),
                    .rd_data(pixbuf_rd_data),
                    .wr(pixbuf_wr),
                    .wr_addr(pixbuf_wr_addr),
                    .wr_data(pixbuf_wr_data));

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

  // Continuously assert the pixbuf_rd signal.
  // This means that we are sometimes reading data
  // values from the pixel buffer that we don't need.
  // But there should be no harm in doing that, and
  // it's much simpler than trying to assert pixbuf_rd
  // conditionally.
  assign pixbuf_rd = 1'b0;

  // hcount_ahead1 should, in theory, always have the
  // correct address in the pixel buffer of the pixel we
  // want to output next.
  assign pixbuf_rd_addr = hcount_ahead1;

  // next_pixel contains the RGB color values of the next pixel
  // to output. It stores the value most recently read from the
  // pixel buffer.
  reg [15:0] next_pixel;

  always @(posedge clk)
    begin

      if (nrst == 1'b0)
        begin
          // reset asserted
          red_reg <= 4'b0;
          green_reg <= 4'b0;
          blue_reg <= 4'b0;
          next_pixel <= 16'd0;
        end

      else
        begin
          // On every clock cycle, fetch the next pixel color value from
          // the pixel buffer
          next_pixel <= pixbuf_rd_data;

          // Output a pixel if it will be in the visible region.
          if ((hvis & vvis) == 1'b1)
            begin
              // GET NEXT PIXEL COLOR!!!
/*
              // Just draw a grid of yellow lines on a blue background.
              // The left column and top row of pixels should be yellow.
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
*/
              // Output the next pixel color from the pixel buffer
              red_reg <= next_pixel[11:8];
              green_reg <= next_pixel[7:4];
              blue_reg <= next_pixel[3:0];
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
