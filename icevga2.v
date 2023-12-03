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

  // The character renderer starts generating pixels into the
  // pixel buffer 32 cycles ahead of the time when the pixel
  // output process will starting outputting them to the display.

  reg render_active; // 1=active, 0=not active

  // Which display pixel row will be generated
  reg [15:0] render_display_pixel_row;

  // Data for block of 8 pixels currently being rendered
  reg [255:0] render_cur_pattern; // current 8-pixel pattern being generated
  reg [15:0] render_cur_bg_color; // background color of current pattern
  reg [15:0] render_cur_fg_color; // foreground color of current pattern

  // Data to set up for next block of 8 pixels
  reg [3:0] render_next_fg_attr; // fg attribute value
  reg [7:0] render_next_pattern; // next 8-pixel pattern to generate
  reg [15:0] render_next_bg_color; // background color of next pattern
  reg [15:0] render_next_fg_color; // foreground color of next pattern

  reg [7:0] render_tick; // ticks counting progress in outputting the current 8-pixel pattern

  always @(posedge clk)
    begin
      if (nrst == 1'b0)
        begin
          // in reset

          chrowbuf_rd <= 1'b1;
          chrowbuf_rd_addr <= 8'd0;
          palette_rd <= 1'b1;
          palette_rd_addr <= 8'd0;
          fontmem_rd <= 1'b1;
          fontmem_rd_addr <= 12'd0;

          pixbuf_wr <= 1'b1;
          pixbuf_wr_addr <= 16'd0;

          render_active = 1'b0; // wait until second pixel row to start rendering
          render_display_pixel_row <= 16'd0;
        end
      else // (nrst == 1'b0)
        begin
          // not in reset

          if (render_active == 1'b0 && hcount == H_BACK_PORCH_END - 16'd48)
            begin
              // Wake up and start rendering
              render_active <= 1'b1;

              // while active, write to pixbuf on every cycle
              pixbuf_wr <= 1'b0;

              // The first 8 pixels generated are meaningless, since we won't
              // have accurate attribute/color/character/pattern data yet.
              // So, put them at the end of the pixel buffer (where they won't be
              // visible.)
              pixbuf_wr_addr <= 10'd1016;
              pixbuf_wr_data <= 16'd0;

              // Which row of pixels is being generated:
              // note that this wakeup happens during the line preceding
              // the one we want to render
              render_display_pixel_row <= vcount + 16'd1;

              // Initial (invalid) pattern of bg/fg pixels
              render_cur_pattern <= 8'd0;
              render_cur_bg_color <= 16'd0;
              render_cur_fg_color <= 16'd0;

              // Start at beginning of pattern
              render_tick <= 3'd0;
            end

          else if (render_active == 1'b1)
            begin

              // Generate the next pixel
              if ((render_cur_pattern & 8'h80) == 8'h80)
                begin
                  // next pixel is foreground color
                  pixbuf_wr_data <= render_cur_fg_color;
                end
              else
                begin
                  // next pixel is background color
                  pixbuf_wr_data <= render_cur_bg_color;
                end

              // Advance the write address in the pixel buffer
              pixbuf_wr_addr <= pixbuf_wr_addr + 10'd1;

              // Shift current pattern or load next pattern
              if (render_tick == 3'd7)
                begin
                  // load next pattern
                  render_cur_pattern <= render_next_pattern;
                end
              else
                begin
                  // shift to next bit in current pattern
                  render_cur_pattern <= (render_cur_pattern << 1);

                  // next fg and bg colors should be good by now
                  render_cur_bg_color <= render_next_bg_color;
                  render_cur_fg_color <= render_next_fg_color;
                end

              // The tick count generates an 8-cycle cadence, with the following
              // actions being taken on specific ticks:
              //
              //   0: assert read from character row buf, assert read from palette,
              //      assert read from font data
              //
              //   1: assert bg attr as read address to palette,
              //      store fg attr (temporarily),
              //      assert character code as read address to font mem,
              //      de-assert read from character row buf,
              //      increment character row read address
              //
              //   2: store background color (read from palette) to next bg color,
              //      store pattern to next_pattern,
              //      assert fg attr as palette read address
              //
              //   3: store foreground color (read from palette) to next fg color,
              //      de-assert palette read signal, advance character row read
              //      address
              case (render_tick)
/*
                3'd0:
                  begin
                    chrowbuf_rd <= 1'b0;
                    palette_rd <= 1'b0;
                    fontmem_rd <= 1'b0;
                  end

                3'd1:
                  begin
                    // attribute/character code data is available now

                    // read color for background attribute from palette
                    palette_rd_addr <= {4'd0, chrowbuf_rd_data[15:12]};

                    // temporarily store foreground attribute
                    render_next_fg_attr <= chrowbuf_rd_data[11:8];

                    // assert character code and pattern row as read address
                    // from font data
                    fontmem_rd_addr <= {chrowbuf_rd_data[7:0], render_display_pixel_row[3:0]};

                    // we can deassert read from the character row buf now
                    chrowbuf_rd <= 1'b1;

                    // advance to next location in character row buf
                    chrowbuf_rd_addr <= chrowbuf_rd_addr + 8'd1;
                  end

                3'd2:
                  begin
                    // character pattern and background color information are available now

                    // store pattern data
                    render_next_pattern <= fontmem_rd_data;

                    // store background color
                    render_next_bg_color <= palette_rd_data;

                    // we can deassert read from the font memory now
                    fontmem_rd <= 1'b1;

                    // assert foreground attribute as address to read from palette
                    palette_rd_addr <= {4'd0, render_next_fg_attr};
                  end

                3'd3:
                  begin
                    // foreground color is available now
                    render_next_fg_color <= palette_rd_data;

                    // we can deassert read from the palette now
                    palette_rd <= 1'b1;
                  end
*/
                3'd0:
                  begin
                    render_next_pattern = 8'b10001010;
                    render_next_bg_color = 16'd0;
                    render_next_fg_color = 16'b0000100010001000;
                  end
              endcase

              if (pixbuf_wr_addr == 10'd799)
                begin
                  // Reached end of visible line, so deactivate the renderer
                  render_active <= 1'b0;
                  chrowbuf_rd <= 1'b1;
                  palette_rd <= 1'b1;
                  pixbuf_wr <= 1'b1;
                end

              // advance tick counter
              render_tick <= render_tick + 3'd1;

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
