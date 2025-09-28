module seg_size_calc_w_window #(
     parameter ptr_w = -1
    ,parameter WIN_SIZE_W = 16
    ,parameter MAX_SEG_SIZE = -1
)(
     input  [ptr_w:0]           trail_ptr
    ,input  [ptr_w:0]           lead_ptr
    ,input  [ptr_w:0]           next_send_ptr
    ,input  [WIN_SIZE_W-1:0]    curr_win

    ,output [ptr_w:0]   seg_size
    ,output [ptr_w:0]   new_unsent_size
);
    logic   [ptr_w:0]           buf_size_calc;
    logic   [ptr_w:0]           buf_size;
    logic   [WIN_SIZE_W-1:0]    avail_win;
    logic   [ptr_w:0]           unsent_data;
    logic   [ptr_w:0]           unacked_data;
    logic   [ptr_w:0]           max_send_size;

    logic   [ptr_w:0]          data_mask;

    assign data_mask = {1'b0, {(ptr_w){1'b1}}};

    space_used_calc #(
        .PTR_W  (ptr_w)
    ) unsent_data_calc (
         .lead_ptr  (lead_ptr)
        ,.trail_ptr (next_send_ptr)
        ,.space_used_calc   (unsent_data    )
    );
    assign unacked_data = (next_send_ptr - trail_ptr) & data_mask;
    // if we somehow end up with a smaller window than we have unacked data...i
    // feel like ideally this shouldn't happen but I guess the other side
    // could close the window on us
    assign avail_win = curr_win < unacked_data
                    ? '0
                    : curr_win - unacked_data;


    // figure out the maximum packet size we can currently send
    assign max_send_size = avail_win < MAX_SEG_SIZE
                        ? avail_win
                           : MAX_SEG_SIZE;

    assign new_unsent_size = unsent_data - seg_size;
                    
    // try to only send segments that are a multiple of 32 bytes
    assign seg_size = unsent_data > max_send_size
                    ? max_send_size
                    : unsent_data;
 endmodule                 
