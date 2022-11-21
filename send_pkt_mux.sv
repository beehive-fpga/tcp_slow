module send_pkt_mux (
     input                  src0_mux_val
    ,input  send_pkt_struct src0_mux_data
    ,output logic           mux_src0_rdy
     
    ,input                  src1_mux_val
    ,input  send_pkt_struct src1_mux_data
    ,output logic           mux_src1_rdy

    ,output                 mux_dst_val
    ,output send_pkt_struct mux_dst_data
    ,input                  dst_mux_rdy
);

    localparam NUM_SRCS = 2;
    logic advance_arb;
    logic   [NUM_SRCS-1:0]  arb_grants;

    assign advance_arb = dst_mux_rdy & mux_dst_val;

    demux_one_hot #(
         .NUM_OUTPUTS   (NUM_SRCS   )
        ,.INPUT_WIDTH   (1  )
    ) rdy_demux (
         .input_sel     (arb_grants     )
        ,.data_input    (dst_mux_rdy    )
        ,.data_outputs  ({mux_src1_rdy, mux_src0_rdy})
    );

    bsg_mux_one_hot #(
         .width_p   (SEND_PKT_STRUCT_W )
        ,.els_p     (NUM_SRCS)
    ) data_mux (
         .data_i        ({src1_mux_data, src0_mux_data} )
        ,.sel_one_hot_i (arb_grants     )
        ,.data_o        (mux_dst_data   )
    );
    
    bsg_mux_one_hot #(
         .width_p   (1)
        ,.els_p     (NUM_SRCS)
    ) data_mux (
         .data_i        ({src1_mux_val, src0_mux_val}   )
        ,.sel_one_hot_i (arb_grants     )
        ,.data_o        (mux_dst_val    )
    );

    bsg_arb_round_robin #(
        .width_p    (NUM_SRCS   )
    ) src_arbiter (
         .clk_i     (clk    )
        ,.reset_i   (rst    )

        ,.reqs_i    ({src1_mux_val, src0_mux_val}   )
        ,.grants_o  (arb_grants     )
        ,.yumi_i    (advance_arb    )
    );
endmodule
