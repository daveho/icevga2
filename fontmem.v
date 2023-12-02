// Font memory

// This is a 4096x8 dual ported RAM, in theory inferred as 8
// 512x8 block RAMs. Each character cell is 8x16. Glyphs
// are stored as a sequence of 16 bytes representing the rows
// of pixels (0=background, 1=foreground), MSB being the
// left pixel, with the first byte in the sequence being the
// top of the glyph.

module fontmem(input nrst,
               input clk,
               input rd,                 // 0=read data, 1=don't read data
               input [11:0] rd_addr,     // which value to read
               output reg [7:0] rd_data, // font data being read
               input wr,                 // 0=write data, 1=don't write data
               input [11:0] wr_addr,     // which value to write
               input [7:0] wr_data       // font data to write
              );

  reg [7:0] font_data[4095:0];

  // Initialize font data: this will load the PC font
  initial
    begin
      `include "init_fontmem.vh"
    end

  // read font data
  always @(posedge clk)
    begin
      if (nrst == 1'b0)
        begin
          rd_data <= 8'd0;
        end
      else
        begin
          if (rd == 1'b0)
            begin
              rd_data <= font_data[rd_addr];
            end
        end
    end

  // write font data
  always @(posedge clk)
    begin
      if (nrst == 1'b1)
        begin
          // not in reset
          if (wr == 1'b0)
            begin
              font_data[wr_addr] <= wr_data;
            end
        end
    end

endmodule 

// vim:ft=verilog:
