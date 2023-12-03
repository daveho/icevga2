// Character row buffer

// This buffer stores attribute and character code values for one row
// of displayed characters. Each attribute/code pair is 16 bits, so the
// memory is organized as 16 bits wide. In the (initially planned) 100x37
// text mode, the character rows have 100 characters. However, the
// memory is intended to be inferred as one 256x16 block RAM, so
// it could be used for video modes with up to 256 displayed characters
// per row.

// A separate process fetches attribute/code pairs from this buffer and
// renders them as color values to be written to the pixel buffer.

module chrowbuf(input nrst,
                input clk,
                input rd,                  // 0=read data, 1=don't read data
                input [7:0] rd_addr,       // which attr/code pair to read
                output reg [15:0] rd_data, // data of requested attr/code pair
                input wr,                  // 0=write data, 1=don't write data
                input [7:0] wr_addr,       // which attr/code pair to write
                input [15:0] wr_data       // attr/code data to write
               )

  reg [15:0] chrow_data[255:0];

  // Just for testing: put some initial attr/code data in the buffer
  initial
    begin
      `include "init_chrowbuf.vh"
    end

  // read data from buffer
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
              // output requested data
              rd_data <= chrow_data[rd_addr];
            end
        end
    end

  // write data to buffer
  always @(posedge clk)
    begin
      if (nrst == 1'b1)
        begin
          // not in reset
          if (wr == 1'b0)
            begin
              // store data being written
              chrow_data[wr_addr] <= wr_data;
            end
        end
    end

endmodule

// vim:ft=verilog:
