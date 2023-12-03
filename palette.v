// Palette

// This is a 256x16 memory, with each entry representing a 12-bit
// RRRRGGGGBBBB color value. (The values of the 4 most significant bits
// are not used.) In theory, it will be inferred as a single
// 256x16 block RAM.

module palette(input nrst,
               input clk,
               input rd,                   // 0=read data, 1=don't read data
               input [7:0] rd_addr,        // palette entry being requested
               output reg [15:0] rd_data,  // color data output
               input wr,                   // 0=write data, 1=don't write data
               input [7:0] wr_addr,        // which palette entry to write
               input [15:0] wr_data        // color value to write
              )

  reg [15:0] color_data[7:0];

  // Initialize with an approximation of the 256-color xterm palette
  initial
    begin
      `include "init_palette.vh"
    end

  // read color data
  always @(posedge clk)
    begin
      if (nrst == 1'b0)
        begin
          // in reset
          rd_data <= 16'd0;
        end
      else
        begin
          // not in reset
          if (rd == 1'b0)
            begin
              // read color value
              rd_data <= color_data[rd_addr];
            end
        end
    end

  // write color data
  always @(posedge clk)
    begin
      if (nrst == 1'b1)
        begin
          // not in reset
          if (wr == 1'b0)
            begin
              // write color value
              color_data[wr_addr] <= wr_data;
            end
        end
    end

endmodule

// vim:ft=verilog:
