// Pixel buffer

// This is a vector of 1024 16-bit values which determine the colors
// of the pixels displayed for the current visible row. The elements
// need to contain the correct values "soon enough" that the
// pixel color output process gets correct values. In theory, this
// should be synthesized using 4 256x16 block RAMs.
//
// Pixel color data is represented as (from MSB to LSB)
//
//   xxxxRRRRGGGGBBBB

module pixbuf(input nrst,                // 0=in reset, 1=not in reset
              input clk,                 // clock signal
              input rd,                  // 0=read data, 1=don't read data
              input [9:0] rd_addr,       // which value to read
              output reg [15:0] rd_data, // pixel data being read
              input wr,                  // 0=write data, 1=don't write data
              input [9:0] wr_addr,       // which value to write
              input [15:0] wr_data       // pixel data to write
             );

  reg [15:0] pixel_data[1023:0];

  // For testing: initialize the pixel buffer with some
  // color values (in theory these will create vertical bars of
  // different colors)
  initial
    begin
      `include "init_pixbuf.vh"
    end

  // read data from pixbuf
  always @(posedge clk)
    begin
      if (nrst == 1'b0)
        begin
          // in reset
          rd_data <= 16'd0; // necessary? at least defines a default state
        end

      else // (nrst == 1'b0)
        // not in reset
        begin
          if (rd == 1'b0)
            begin
              // output requested data to rd_data
              rd_data <= pixel_data[rd_addr];
            end
        end
    end

  // write data to pixbuf
  always @(posedge clk)
    begin
      if (nrst == 1'b1)
        begin
          // not in reset
          if (wr == 1'b0)
            begin
              // write data to requested location
              pixel_data[wr_addr] <= wr_data;
            end
        end
    end

endmodule

// vim:ft=verilog:
