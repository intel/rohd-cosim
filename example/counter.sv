/**
 * This file was generated using the ROHD example:
 * https://github.com/intel/rohd/blob/main/example/example.dart
 */

 module Counter(
    input logic en,
    input logic reset,
    input logic clk,
    output logic [7:0] val
    );
    logic [7:0] nextVal;
    //  sequential
    always_ff @(posedge clk) begin
      if(reset) begin
          val <= 8'h0;
      end else begin
          if(en) begin
              val <= nextVal;
          end 
    
      end 
    
    end
    
    assign nextVal = val + 8'h1;  // add
endmodule : Counter