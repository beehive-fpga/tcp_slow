`include "packet_defs.vh"
module tcp_tx_datap
import tcp_pkg::*;
import tcp_misc_pkg::*;
import packet_struct_pkg::*;
(
     input clk
    ,input rst

    ,input  sched_data_struct               sched_tx_req_data
    
    ,output sched_cmd_struct                tx_sched_update_cmd

    ,output logic   [FLOWID_W-1:0]          tx_pipe_tx_tail_ptr_rd_req_addr
    
    ,input  logic   [TX_PAYLOAD_PTR_W:0]    tx_tail_ptr_tx_pipe_rd_resp_data

    ,output logic   [FLOWID_W-1:0]          proto_calc_curr_tx_state_rd_req_addr

    ,input  smol_tx_state_struct            proto_calc_curr_tx_state_rd_resp_data

    ,output logic   [FLOWID_W-1:0]          proto_calc_next_tx_state_wr_req_addr
    ,output smol_tx_state_struct            proto_calc_next_tx_state_wr_req_data

    ,output logic   [FLOWID_W-1:0]          proto_calc_rx_state_rd_req_addr
    
    ,input  smol_rx_state_struct            rx_state_proto_calc_rd_resp_data

    ,output logic   [FLOWID_W-1:0]          proto_calc_tuple_rd_req_addr

    ,input  four_tuple_struct               tuple_proto_calc_rd_resp_data

    ,input  logic                           ctrl_datap_store_flowid
    ,input  logic                           ctrl_datap_store_state
    ,input  logic                           ctrl_datap_store_calc
    ,input  logic                           ctrl_datap_store_tuple
    ,input  logic                           ctrl_datap_store_sched

    ,output logic                           datap_ctrl_produce_pkt

    ,output tcp_pkt_hdr                     proto_calc_tx_pkt_hdr
    ,output logic   [FLOWID_W-1:0]          proto_calc_tx_flowid
    ,output logic   [`IP_ADDR_W-1:0]        proto_calc_tx_src_ip_addr
    ,output logic   [`IP_ADDR_W-1:0]        proto_calc_tx_dst_ip_addr
    ,output payload_buf_struct              proto_calc_tx_payload
);

    sched_data_struct   sched_data_reg;
    sched_data_struct   sched_data_next;

    logic   [TX_PAYLOAD_PTR_W:0]        curr_tx_tail_ptr_reg;
    logic   [TX_PAYLOAD_PTR_W:0]        curr_tx_tail_ptr_next;
    
    logic   [`WIN_SIZE_W-1:0]           their_rx_win;

    smol_tx_state_struct                curr_tx_state_reg;
    smol_tx_state_struct                curr_tx_state_next;
    
    smol_tx_state_struct                next_tx_state_reg;
    smol_tx_state_struct                next_tx_state_next;

    smol_rx_state_struct                curr_rx_state_reg;
    smol_rx_state_struct                curr_rx_state_next;

    four_tuple_struct                   flow_tuple_reg;
    four_tuple_struct                   flow_tuple_next;

    payload_buf_struct                  payload_desc_reg;
    payload_buf_struct                  payload_desc_next;

    tcp_pkt_hdr                         hdr_out_reg;
    tcp_pkt_hdr                         hdr_out_next;
    tcp_pkt_hdr                         assembled_hdr;

    logic   [TX_PAYLOAD_PTR_W:0]        rt_seg_size;
    logic   [TX_PAYLOAD_PTR_W:0]        new_seg_size;
    
    logic   [TX_PAYLOAD_PTR_W:0]        rt_unsent;
    logic   [TX_PAYLOAD_PTR_W:0]        new_unsent;
    
    logic   [TX_PAYLOAD_PTR_W:0]        rt_unsent_next;
    logic   [TX_PAYLOAD_PTR_W:0]        new_unsent_next;
    
    logic   [TX_PAYLOAD_PTR_W:0]        rt_unsent_reg;
    logic   [TX_PAYLOAD_PTR_W:0]        new_unsent_reg;
    
    
    logic   [`SEQ_NUM_W-1:0]    pkt_seq_num;
    logic   [`SEQ_NUM_W-1:0]    our_next_seq_num;
    payload_buf_struct          payload_desc;

    sched_cmd_struct            update_cmd_reg;
    sched_cmd_struct            update_cmd_next;
    sched_cmd_struct            update_cmd;


    assign tx_pipe_tx_tail_ptr_rd_req_addr = sched_data_reg.flowid;
    assign proto_calc_curr_tx_state_rd_req_addr = sched_data_reg.flowid;
    assign proto_calc_next_tx_state_wr_req_addr = sched_data_reg.flowid;
    assign proto_calc_rx_state_rd_req_addr = sched_data_reg.flowid;
    assign proto_calc_tuple_rd_req_addr = sched_data_reg.flowid;

    assign proto_calc_next_tx_state_wr_req_data = next_tx_state_reg;

    assign proto_calc_tx_src_ip_addr = flow_tuple_reg.host_ip;
    assign proto_calc_tx_dst_ip_addr = flow_tuple_reg.dest_ip;
    assign proto_calc_tx_pkt_hdr = hdr_out_reg;
    assign proto_calc_tx_payload = payload_desc_reg;
    assign proto_calc_tx_flowid = sched_data_reg.flowid;

    assign tx_sched_update_cmd = update_cmd_reg;


    always_ff @(posedge clk) begin
        sched_data_reg <= sched_data_next;
        curr_tx_tail_ptr_reg <= curr_tx_tail_ptr_next;
        curr_tx_state_reg <= curr_tx_state_next;
        curr_rx_state_reg <= curr_rx_state_next;
        flow_tuple_reg <= flow_tuple_next;
        update_cmd_reg <= update_cmd_next;
        hdr_out_reg <= hdr_out_next;
        payload_desc_reg <= payload_desc_next;
        next_tx_state_reg <= next_tx_state_next;

        new_unsent_reg <= new_unsent_next;
        rt_unsent_reg <= rt_unsent_next;
    end

    always_comb begin
        sched_data_next = sched_data_reg;
        if (ctrl_datap_store_flowid) begin
            sched_data_next = sched_tx_req_data;
        end
        else begin
            sched_data_next = sched_data_reg;
        end
    end

    always_comb begin
            curr_tx_tail_ptr_next = curr_tx_tail_ptr_reg;
            curr_tx_state_next = curr_tx_state_reg;
            curr_rx_state_next = curr_rx_state_reg;
        if (ctrl_datap_store_state) begin
            curr_tx_tail_ptr_next = tx_tail_ptr_tx_pipe_rd_resp_data;
            curr_tx_state_next = proto_calc_curr_tx_state_rd_resp_data;
            curr_rx_state_next = rx_state_proto_calc_rd_resp_data;
        end
        else begin
            curr_tx_tail_ptr_next = curr_tx_tail_ptr_reg;
            curr_tx_state_next = curr_tx_state_reg;
            curr_rx_state_next = curr_rx_state_reg;
        end
    end

    assign new_unsent_next = ctrl_datap_store_calc
                            ? new_unsent
                            : new_unsent_reg;

    assign rt_unsent_next = ctrl_datap_store_calc
                            ? rt_unsent
                            : rt_unsent_reg;

    always_comb begin
        flow_tuple_next = flow_tuple_reg;
        if (ctrl_datap_store_tuple) begin
            flow_tuple_next = tuple_proto_calc_rd_resp_data;
        end
        else begin
            flow_tuple_next = flow_tuple_reg;
        end
    end

   
    // calculate both possible segment sizes and then decide between them
    
    // never completely close the window as a hack instead of proper zero-window probing...
    // it's kind of proper, but we don't have a back-off timer basically

    assign their_rx_win = curr_rx_state_reg.their_win_size == 0
                                        ? 1 
                                        : curr_rx_state_reg.their_win_size;

    // for the retransmit segment, calculate from the last ack'ed byte
    seg_size_calc_w_window #(
         .ptr_w         (TX_PAYLOAD_PTR_W   )
        ,.MAX_SEG_SIZE  (`MAX_SEG_SIZE      )
    ) rt_segment (
         .trail_ptr         (curr_rx_state_reg.our_ack_state.ack_num[TX_PAYLOAD_PTR_W:0]    )
        ,.lead_ptr          (curr_tx_tail_ptr_reg                                           )
        ,.next_send_ptr     (curr_rx_state_reg.our_ack_state.ack_num[TX_PAYLOAD_PTR_W:0]    )
        ,.curr_win          (their_rx_win                                                   )
        ,.seg_size          (rt_seg_size                                                    )
        ,.new_unsent_size   (rt_unsent                                                      )
    );

    // for the new segment, calculate from the sequence number
    seg_size_calc_w_window #(
         .ptr_w         (TX_PAYLOAD_PTR_W   )
        ,.MAX_SEG_SIZE  (`MAX_SEG_SIZE      )
    ) new_segment (
         .trail_ptr         (curr_rx_state_reg.our_ack_state.ack_num[TX_PAYLOAD_PTR_W:0]    )
        ,.lead_ptr          (curr_tx_tail_ptr_reg                                           )
        ,.next_send_ptr     (curr_tx_state_reg.our_seq_num[TX_PAYLOAD_PTR_W:0]              )
        ,.curr_win          (their_rx_win                                                   )
        ,.seg_size          (new_seg_size                                                   )
        ,.new_unsent_size   (new_unsent                                                     )
    );

    logic   [TX_PAYLOAD_PTR_W:0]    next_unsent_size;

    logic   [`SEQ_NUM_W-1:0]    seq_num_test;

    assign seq_num_test = curr_tx_state_reg.our_seq_num + new_seg_size;

    always_comb begin
        our_next_seq_num = '0;
        pkt_seq_num = '0;
        payload_desc = '0;
        if (sched_data_reg.rt_flag.flag == 1'b1) begin
            pkt_seq_num = curr_rx_state_reg.our_ack_state.ack_num;
            our_next_seq_num = curr_rx_state_reg.our_ack_state.ack_num + rt_seg_size;
            payload_desc.payload_addr = curr_rx_state_reg.our_ack_state.ack_num;
            payload_desc.payload_len = rt_seg_size;
        end
        else begin
            pkt_seq_num = curr_tx_state_reg.our_seq_num;
            our_next_seq_num = curr_tx_state_reg.our_seq_num + new_seg_size;
            payload_desc.payload_addr = curr_tx_state_reg.our_seq_num[TX_PAYLOAD_PTR_W-1:0];
            payload_desc.payload_len = new_seg_size;
        end
    end

    assign next_unsent_size = (sched_data_reg.rt_flag == 1'b1)
                            ? rt_unsent_reg
                            : new_unsent_reg;

    always_comb begin
        next_tx_state_next = next_tx_state_reg;
        payload_desc_next = payload_desc_reg;
        hdr_out_next = hdr_out_reg;

        if (ctrl_datap_store_calc) begin
            next_tx_state_next.our_seq_num = our_next_seq_num;
            payload_desc_next = payload_desc;
            hdr_out_next = assembled_hdr;
        end
        else begin
            next_tx_state_next = next_tx_state_reg;
            payload_desc_next = payload_desc_reg;
            hdr_out_next = hdr_out_reg;
        end
    end

    assign update_cmd_next = ctrl_datap_store_sched
                            ? update_cmd
                            : update_cmd_reg;

    always_comb begin
        update_cmd = '0;
        update_cmd.flowid = sched_data_reg.flowid;
        update_cmd.rt_pend_set_clear.timestamp = sched_data_reg.rt_flag.timestamp;
        update_cmd.rt_pend_set_clear.cmd = CLEAR;

        update_cmd.ack_pend_set_clear.timestamp = sched_data_reg.ack_pend_flag.timestamp;
        update_cmd.ack_pend_set_clear.cmd = CLEAR;

        update_cmd.data_pend_set_clear.timestamp = sched_data_reg.data_pend_flag.timestamp;
        if (next_unsent_size == 0) begin
            update_cmd.data_pend_set_clear.cmd = CLEAR;
        end
        else begin
            update_cmd.data_pend_set_clear.cmd = NOP;
        end
    end

    // since we can't count on the data pending flag, we need to check if the payload actually has length.
    assign datap_ctrl_produce_pkt = sched_data_reg.rt_flag.flag | sched_data_reg.ack_pend_flag.flag | 
                                    (payload_desc_reg.payload_len != 0);

    logic [`FLAGS_W-1:0]    assembler_flags;
    logic [`FLAGS_W-1:0]    ack_flag_bit;
    logic [`FLAGS_W-1:0]    psh_flag_bit;

    assign ack_flag_bit = sched_data_reg.ack_pend_flag.flag << `TCP_ACK_INDEX;
    assign psh_flag_bit = (payload_desc_reg.payload_len != 0) << `TCP_PSH_INDEX;
    assign assembler_flags = ack_flag_bit | psh_flag_bit;

    tcp_hdr_assembler hdr_assembler (
         .tcp_hdr_req_val       (1'b1   )
        ,.host_port             (flow_tuple_next.host_port          )
        ,.dest_port             (flow_tuple_next.dest_port          )
        ,.seq_num               (pkt_seq_num                        )
        ,.ack_num               (curr_rx_state_reg.their_ack_num    )
        ,.flags                 (`TCP_ACK | `TCP_PSH                )
        ,.window                (curr_rx_state_reg.our_win_size     )
        ,.tcp_hdr_req_rdy       ()
    
        ,.outbound_tcp_hdr_val  ()
        ,.outbound_tcp_hdr_rdy  (1'b1)
        ,.outbound_tcp_hdr      (assembled_hdr                      )
    );
endmodule
