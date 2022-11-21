`include "packet_defs.vh"
module seg_size_calc #(
    parameter ptr_w = -1
)(
     input  [ptr_w:0]  trail_ptr
    ,input  [ptr_w:0]  lead_ptr

    ,output [ptr_w:0]  seg_size
);
    logic   [ptr_w:0]  buf_size_calc;
    logic   [ptr_w:0]  buf_size;

    assign buf_size_calc = lead_ptr - trail_ptr;

    assign buf_size = buf_size_calc;


    // try to only send segments that are a multiple of 32 bytes
    assign seg_size = buf_size > `MAX_SEG_SIZE
                    ? `MAX_SEG_SIZE
                    : buf_size < 32
                      ? buf_size
                      : {buf_size[ptr_w:5], 5'b0};
 endmodule                 
