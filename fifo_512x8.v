// Synchronous 8-bit FIFO

// This should use one block RAM unit. These are 256 x 16 bits,
// but they can be accessed as 512 x 8bits. In theory ICEStorm
// will infer that we want a block RAM. Note that the FIFO is
// full when 511 bytes have been added.

// This code is very much based on the synchronous FIFO example
// from
//
//     https://vlsiverify.com/verilog/verilog-codes/synchronous-fifo

module fifo_512x8(input wire nrst,               // 0 means reset is asserted
                  input wire clk,                // clock signal
                  output wire not_empty,         // 1 if not empty, 0 if empty
                  input wire rd,                 // 0 to indicate consumer wants to read
                  output reg [7:0] rd_data,      // data read from FIFO
                  output wire not_full,          // 1 if not full, 0 if full
                  input wire wr,                 // 0 to indicate producer wants to write
                  input wire [7:0] wr_data       // data written to FIFO
                 );

  reg [8:0] rd_ptr;
  reg [8:0] wr_ptr;

  reg [7:0] fifo_data[511:0];

  // full and empty conditions
  // I'm sort of suspicious that these conditions can be relied on
  // given that they are computed by combinational logic, but I've
  // seen multiple examples that work this way. (It's on the internet,
  // so it must be trustworthy.)
  wire full, empty;
  assign full = (rd_ptr + 9'd1 == wr_ptr);
  assign empty = (rd_ptr == wr_ptr);
  assign not_empty = !empty;
  assign not_full = !full;

  // reading data from FIFO
  always @(posedge clk)
    begin
      if (nrst == 1'b0)
        begin
          // reset asserted
          rd_ptr <= 9'd0;
          rd_data <= 8'd0;
        end
      else if (rd == 1'b0 & not_empty)
        begin
          rd_data <= fifo_data[rd_ptr]; // read data at current read pointer
          rd_ptr <= rd_ptr + 1; // advance read pointer
        end
    end

  // writing data to the FIFO
  always @(posedge clk)
    begin
      if (nrst == 1'b0)
        begin
          // reset asserted
          wr_ptr <= 9'd0;
        end
      if (wr == 1'b0 & not_full)
        begin
          fifo_data[wr_ptr] <= wr_data; // write data at current write pointer
          wr_ptr <= wr_ptr + 1; // advance write pointer
        end
    end

endmodule

// vim:ft=verilog:
