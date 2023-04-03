module tb_seg_size_calc_w_window #(
     parameter PTR_W = 11
    ,parameter WIN_SIZE_W = 16
    ,parameter MAX_SEG_SIZE = 1024
)(
     input  [PTR_W:0]           trail_ptr
    ,input  [PTR_W:0]           lead_ptr
    ,input  [PTR_W:0]           next_send_ptr
    ,input  [WIN_SIZE_W-1:0]    curr_win

    ,output [PTR_W:0]           seg_size

    ,input clk
);

    seg_size_calc_w_window #(
         .ptr_w         (PTR_W          )
        ,.WIN_SIZE_W    (WIN_SIZE_W     )
        ,.MAX_SEG_SIZE  (MAX_SEG_SIZE   )
    ) dut (
         .trail_ptr     (trail_ptr      )
        ,.lead_ptr      (lead_ptr       )
        ,.next_send_ptr (next_send_ptr  )
        ,.curr_win      (curr_win       )
                                        
        ,.seg_size      (seg_size       )
    );
endmodule
