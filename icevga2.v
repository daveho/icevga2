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

  // The character renderer writes to the pixel buffer
  reg pixbuf_wr;
  reg [9:0] pixbuf_wr_addr;
  reg [15:0] pixbuf_wr_data;

/*
  // For now, there are no writes to the pixbuf
  assign pixbuf_wr = 1'b1;
  assign pixbuf_wr_addr = 10'd0;
  assign pixbuf_wr_data = 16'd0;
*/

  pixbuf the_pixbuf(.nrst(nrst),
                    .clk(clk),
                    .rd(pixbuf_rd),
                    .rd_addr(pixbuf_rd_addr),
                    .rd_data(pixbuf_rd_data),
                    .wr(pixbuf_wr),
                    .wr_addr(pixbuf_wr_addr),
                    .wr_data(pixbuf_wr_data));

  ////////////////////////////////////////////////////////////////////////
  // Character attribute/code row buffer
  ////////////////////////////////////////////////////////////////////////

  // The character renderer will drive/use these
  reg chrowbuf_rd;
  reg [7:0] chrowbuf_rd_addr;
  wire [15:0] chrowbuf_rd_data;

  // For now, we don't write to the row buffer
  wire chrowbuf_wr;
  wire [7:0] chrowbuf_wr_addr;
  wire [15:0] chrowbuf_wr_data;
  assign chrowbuf_wr = 1'b1;
  assign chrowbuf_wr_addr = 8'd0;
  assign chrowbuf_wr_data = 16'd0;

  chrowbuf the_chrowbuf(.nrst(nrst),
                        .clk(clk),
                        .rd(chrowbuf_rd),
                        .rd_addr(chrowbuf_rd_addr),
                        .rd_data(chrowbuf_rd_data),
                        .wr(chrowbuf_wr),
                        .wr_addr(chrowbuf_wr_addr),
                        .wr_data(chrowbuf_wr_data));

  ////////////////////////////////////////////////////////////////////////
  // Palette
  ////////////////////////////////////////////////////////////////////////

  // The character renderer will drive/use these
  reg palette_rd;
  reg [7:0] palette_rd_addr;
  wire [15:0] palette_rd_data;

  // For now, we don't write to the palette
  wire palette_wr;
  wire [7:0] palette_wr_addr;
  wire [15:0] palette_wr_data;
  assign palette_wr = 1'b1;
  assign palette_wr_addr = 8'd0;
  assign palette_wr_data = 16'd0;

  palette the_palette(.nrst(nrst),
                      .clk(clk),
                      .rd(palette_rd),
                      .rd_addr(palette_rd_addr),
                      .rd_data(palette_rd_data),
                      .wr(palette_wr),
                      .wr_addr(palette_wr_addr),
                      .wr_data(palette_wr_data));

  ////////////////////////////////////////////////////////////////////////
  // Font memory
  ////////////////////////////////////////////////////////////////////////

  // The character renderer will drive/use these
  reg fontmem_rd;
  reg [11:0] fontmem_rd_addr;
  wire [7:0] fontmem_rd_data;

  // For now, we don't write to the font memory
  wire fontmem_wr;
  wire [11:0] fontmem_wr_addr;
  wire [7:0] fontmem_wr_data;
  assign fontmem_wr = 1'b1;
  assign fontmem_wr_addr = 12'd0;
  assign fontmem_wr_data = 8'd0;

  fontmem the_fontmem(.nrst(nrst),
                      .clk(clk),
                      .rd(fontmem_rd),
                      .rd_addr(fontmem_rd_addr),
                      .rd_data(fontmem_rd_data),
                      .wr(fontmem_wr),
                      .wr_addr(fontmem_wr_addr),
                      .wr_data(fontmem_wr_data));

  ////////////////////////////////////////////////////////////////////////
  // Character renderer
  ////////////////////////////////////////////////////////////////////////

  reg render_active;

  reg[7:0] render_cur_pattern;   // current pattern of 8 pixels
  reg[15:0] render_cur_bg_color; // current background color
  reg[15:0] render_cur_fg_color; // current foreground color

  always @(posedge clk)
    begin
      if (nrst == 1'b0)
        begin
          // in reset

          // for now, don't read from the character row buffer,
          // the font memory, or the palette
          chrowbuf_rd <= 1'b1;
          chrowbuf_rd_addr <= 8'd0;
          fontmem_rd <= 1'b1;
          fontmem_rd_addr <= 12'd0;
          palette_rd <= 1'b1;
          palette_rd_addr <= 8'd0;

          // writes to pixbuf happen only after we're out of reset
          pixbuf_wr <= 1'b1;
          pixbuf_wr_addr <= 10'd0;
          pixbuf_wr_data <= 16'd0;

          // state information for rendering logic
          render_active <= 1'b0; // start rendering on second row of pixels
          render_cur_pattern <= 8'd0;
          render_cur_bg_color <= 16'd0;
          render_cur_fg_color <= 16'd0;
        end
     else
       begin
         // not in reset

         if (render_active == 1'b0 && hcount == H_BACK_PORCH_END - 16'd16)
           begin
             // wake up and start rendering current row of pixels
             // to the pixel buffer
             render_active <= 1'b1;
             render_cur_pattern <= 8'b10000000;
             render_cur_bg_color <= 16'h0006;
             render_cur_fg_color <= 16'h0ff0;

             // The first computed write to the pixel buffer is 8 positions
             // from the end, because the first 8 pixel colors added
             // to the pixel buffer won't be valid.
             pixbuf_wr_addr <= 10'd1016;
           end
         else if (render_active == 1'b1)
           begin
             // rendering is active

             // Output the current pixel color to the pixel buffer
             if ((render_cur_pattern & 8'h80) == 8'h80)
               begin
                 pixbuf_wr_data <= render_cur_fg_color;
               end
             else
               begin
                 pixbuf_wr_data <= render_cur_bg_color;
               end

             // Update pattern and bg/fg colors for next pixel
             if (pixbuf_wr_addr[2:0] == 3'b111)
               begin
                 // reached end of current pattern, activate next pattern
                 // and fg/bg colors (hard-coded for now, eventually should
                 // be pattern loaded from font memory and bg/fg colors
                 // loaded from palette)
                 render_cur_pattern <= 8'b10000000;
                 //render_cur_bg_color <= {4'd0, pixbuf_wr_addr[3:0], 8'd0};
                 render_cur_bg_color <= 16'h0006;
                 render_cur_fg_color <= 16'h0ff0;
               end
             else
               begin
                 render_cur_pattern <= (render_cur_pattern << 1);
               end

             // Advance to next pixel
             pixbuf_wr_addr <= pixbuf_wr_addr + 10'd1;

             // done rendering this row of pixels?
             if (pixbuf_wr_addr == 12'd799) // FIXME: shouldn't hard code
               begin
                 // done rendering
                 render_active <= 1'b0;
                 pixbuf_wr <= 1'b1; // deassert write to pixbuf
               end
             else
               begin
                 // continue rendering
                 pixbuf_wr <= 1'b0;
               end
           end
       end
    end

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
