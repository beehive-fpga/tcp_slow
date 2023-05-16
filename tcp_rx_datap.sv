module tcp_rx_datap 
import tcp_pkg::*;
import tcp_misc_pkg::*;
import packet_struct_pkg::*;
(
     input clk
    ,input rst
    
    ,input  logic   [`IP_ADDR_W-1:0]        rx_src_ip
    ,input  logic   [`IP_ADDR_W-1:0]        rx_dst_ip
    ,input  tcp_pkt_hdr                     rx_tcp_hdr
    ,input  payload_buf_struct              rx_payload_entry
    
    ,output logic   [FLOWID_W-1:0]          tcp_rx_dst_flowid
    ,output logic                           tcp_rx_dst_pkt_accept
    ,output payload_buf_struct              tcp_rx_dst_payload_entry

    ,output four_tuple_struct               read_flow_cam_tag 
    ,input          [FLOWID_W-1:0]          read_flow_cam_flowid

    ,input          [FLOWID_W-1:0]          flowid_manager_flowid

    ,output logic   [FLOWID_W-1:0]          curr_rx_state_rd_req_addr
    
    ,input  smol_rx_state_struct            curr_rx_state_rd_resp_data

    ,output logic   [FLOWID_W-1:0]          next_rx_state_wr_req_addr
    ,output smol_rx_state_struct            next_rx_state_wr_req_data

    ,output logic   [FLOWID_W-1:0]          curr_tx_state_rd_req_addr

    ,input  smol_tx_state_struct            curr_tx_state_rd_resp_data
    
    ,output logic   [FLOWID_W-1:0]          rx_pipe_rx_head_ptr_rd_req_addr

    ,input  logic   [RX_PAYLOAD_PTR_W:0]    rx_head_ptr_rx_pipe_rd_resp_data
    
    ,output logic   [FLOWID_W-1:0]          rx_pipe_rx_tail_ptr_wr_req_addr
    ,output logic   [RX_PAYLOAD_PTR_W:0]    rx_pipe_rx_tail_ptr_wr_req_data

    ,output logic   [FLOWID_W-1:0]          rx_pipe_rx_tail_ptr_rd_req_addr

    ,input  logic   [RX_PAYLOAD_PTR_W:0]    rx_tail_ptr_rx_pipe_rd_resp_data
    
    ,output         [FLOWID_W-1:0]          rx_pipe_tx_head_ptr_wr_req_addr
    ,output         [TX_PAYLOAD_PTR_W:0]    rx_pipe_tx_head_ptr_wr_req_data

    ,output logic   [FLOWID_W-1:0]          new_flow_flowid
    ,output four_tuple_struct               new_flow_lookup_entry
    ,output smol_tx_state_struct            new_flow_tx_state
    ,output smol_rx_state_struct            new_flow_rx_state
    ,output logic   [TX_PAYLOAD_PTR_W:0]    new_tx_head_ptr
    ,output logic   [TX_PAYLOAD_PTR_W:0]    new_tx_tail_ptr
    
    ,output logic   [FLOWID_W-1:0]          app_new_flow_flowid
    ,output four_tuple_struct               app_new_flow_entry

    ,input                                  ctrl_datap_save_input
    ,input                                  ctrl_datap_save_flow_state
    ,input                                  ctrl_datap_save_calcs

    ,output sched_cmd_struct                rx_sched_update_cmd
    
    ,input                                  store_flowid_cam
    ,input                                  store_flowid_manager

    ,output tcp_pkt_hdr                     datap_slow_path_pkt

    ,output tcp_pkt_hdr                     slow_path_send_pkt_enqueue_pkt
    ,output [FLOWID_W-1:0]                  slow_path_send_pkt_enqueue_flowid
    ,output [`IP_ADDR_W-1:0]                slow_path_send_pkt_enqueue_src_ip
    ,output [`IP_ADDR_W-1:0]                slow_path_send_pkt_enqueue_dst_ip
);

    localparam OUR_SEQ_NUM = 32'hff;

    logic   [`IP_ADDR_W-1:0]    src_ip_reg;
    logic   [`IP_ADDR_W-1:0]    dst_ip_reg;
    
    logic   [`IP_ADDR_W-1:0]    src_ip_next;
    logic   [`IP_ADDR_W-1:0]    dst_ip_next;

    logic   [FLOWID_W-1:0]      curr_flowid_reg;
    logic   [FLOWID_W-1:0]      curr_flowid_next;

    tcp_pkt_hdr                 tcp_hdr_reg;
    tcp_pkt_hdr                 tcp_hdr_next;

    payload_buf_struct          payload_entry_reg;
    payload_buf_struct          payload_entry_next;

    smol_rx_state_struct        curr_rx_data_reg;
    smol_tx_state_struct        curr_tx_data_reg;
    smol_rx_state_struct        curr_rx_data_next;
    smol_tx_state_struct        curr_tx_data_next;

    smol_rx_state_struct        next_rx_state_reg;
    smol_rx_state_struct        next_rx_state_next;
    logic   [`ACK_NUM_W-1:0]    their_ack_num;
    ack_state_struct            our_ack_state;

    logic   [RX_PAYLOAD_PTR_W:0]    next_rx_tail_ptr_next;
    logic   [RX_PAYLOAD_PTR_W:0]    next_rx_tail_ptr_reg;
    logic   [RX_PAYLOAD_PTR_W:0]    next_rx_tail_ptr;

    logic   [TX_PAYLOAD_PTR_W:0]    next_tx_head_ptr_next;
    logic   [TX_PAYLOAD_PTR_W:0]    next_tx_head_ptr_reg;
    logic   [TX_PAYLOAD_PTR_W:0]    next_tx_head_ptr;

    logic   [RX_PAYLOAD_PTR_W:0]    curr_rx_head_reg;
    logic   [RX_PAYLOAD_PTR_W:0]    curr_rx_tail_reg;
    logic   [RX_PAYLOAD_PTR_W:0]    curr_rx_head_next;
    logic   [RX_PAYLOAD_PTR_W:0]    curr_rx_tail_next;

    logic   [RX_PAYLOAD_PTR_W:0]    our_win;

    logic                           accept_payload;
    logic                           accept_payload_reg;
    logic                           accept_payload_next;

    logic                           set_rt;
    logic                           set_rt_next;
    logic                           set_rt_reg;

    always_ff @(posedge clk) begin
        src_ip_reg <= src_ip_next;
        dst_ip_reg <= dst_ip_next;
        tcp_hdr_reg <= tcp_hdr_next;
        payload_entry_reg <= payload_entry_next;
        curr_flowid_reg <= curr_flowid_next;
        curr_rx_data_reg <= curr_rx_data_next;
        curr_tx_data_reg <= curr_tx_data_next;
        curr_rx_head_reg <= curr_rx_head_next;
        curr_rx_tail_reg <= curr_rx_tail_next;
        next_rx_state_reg <= next_rx_state_next;
        next_rx_tail_ptr_reg <= next_rx_tail_ptr_next;
        next_tx_head_ptr_reg <= next_tx_head_ptr_next;
        accept_payload_reg <= accept_payload_next;
        set_rt_reg <= set_rt_next;
    end

    assign datap_slow_path_pkt = tcp_hdr_reg;
    assign next_rx_state_wr_req_data = next_rx_state_reg;
    assign rx_pipe_rx_tail_ptr_wr_req_data = next_rx_tail_ptr_reg;
    assign rx_pipe_tx_head_ptr_wr_req_data = next_tx_head_ptr_reg;
    assign datap_ctrl_set_rt = set_rt_reg;

    assign read_flow_cam_tag.host_ip = rx_dst_ip;
    assign read_flow_cam_tag.dest_ip = rx_src_ip;
    assign read_flow_cam_tag.host_port = rx_tcp_hdr.dst_port;
    assign read_flow_cam_tag.dest_port = rx_tcp_hdr.src_port;

    assign curr_flowid_next = store_flowid_cam
                            ? read_flow_cam_flowid
                            : store_flowid_manager
                                ? flowid_manager_flowid
                                : curr_flowid_reg;

    assign rx_pipe_rx_head_ptr_rd_req_addr = curr_flowid_reg;
    assign rx_pipe_rx_tail_ptr_rd_req_addr = curr_flowid_reg;
    assign rx_pipe_rx_tail_ptr_wr_req_addr = curr_flowid_reg;
    assign rx_pipe_tx_head_ptr_wr_req_addr = curr_flowid_reg;

    assign curr_rx_state_rd_req_addr = curr_flowid_reg;
    assign curr_tx_state_rd_req_addr = curr_flowid_reg;
    assign next_rx_state_wr_req_addr = curr_flowid_reg;

    assign tcp_rx_dst_flowid = curr_flowid_reg;
    assign tcp_rx_dst_pkt_accept = accept_payload_reg;
    assign tcp_rx_dst_payload_entry = payload_entry_reg;

    always_comb begin
        next_rx_state_next = '0;
        next_rx_tail_ptr_next = next_rx_tail_ptr_reg;
        next_tx_head_ptr_next = next_tx_head_ptr_reg;
        accept_payload_next = accept_payload_reg;
        set_rt_next = set_rt_reg;

        if (ctrl_datap_save_calcs) begin
            next_rx_state_next.our_ack_state = our_ack_state;
            next_rx_state_next.their_win_size = tcp_hdr_reg.win_size;
            next_rx_state_next.their_ack_num = their_ack_num;
            next_rx_state_next.our_win_size = our_win;
            next_rx_tail_ptr_next = next_rx_tail_ptr;
            next_tx_head_ptr_next = next_tx_head_ptr;
            accept_payload_next = accept_payload;
            set_rt_next = set_rt;
        end
        else begin
            next_rx_state_next = next_rx_state_reg;
            next_rx_tail_ptr_next = next_rx_tail_ptr_reg;
            next_tx_head_ptr_next = next_tx_head_ptr_reg;
            accept_payload_next = accept_payload_reg;
            set_rt_next = set_rt_reg;
        end
    end
                
    always_comb begin
        if (ctrl_datap_save_flow_state) begin
            curr_rx_data_next = curr_rx_state_rd_resp_data;
            curr_tx_data_next = curr_tx_state_rd_resp_data;
            curr_rx_head_next = rx_head_ptr_rx_pipe_rd_resp_data;
            curr_rx_tail_next = rx_tail_ptr_rx_pipe_rd_resp_data;
        end
        else begin
            curr_rx_data_next = curr_rx_data_reg;
            curr_tx_data_next = curr_tx_data_reg;
            curr_rx_head_next = curr_rx_head_reg;
            curr_rx_tail_next = curr_rx_tail_reg;
        end
    end

    always_comb begin
        if (ctrl_datap_save_input) begin
            src_ip_next = rx_src_ip;
            dst_ip_next = rx_dst_ip;
            tcp_hdr_next = rx_tcp_hdr;
            payload_entry_next = rx_payload_entry;
        end
        else begin
            src_ip_next = src_ip_reg;
            dst_ip_next = dst_ip_reg;
            tcp_hdr_next = tcp_hdr_reg;
            payload_entry_next = payload_entry_reg;
        end
    end

/***************************************************************
 * Fastpath logic
 **************************************************************/
    // process the receiving stream to generate the ACKs for their data send
    their_ack_process their_ack_process (
         .their_curr_ack_num    (curr_rx_data_reg.their_ack_num     )
        ,.packet_seq_num        (tcp_hdr_reg.seq_num                )
        ,.packet_payload_len    (payload_entry_reg.payload_len      )
        ,.rx_tail_ptr           (curr_rx_tail_reg                   )
        ,.rx_head_ptr           (curr_rx_head_reg                   )
    
        ,.their_next_ack_num    (their_ack_num                      )
        ,.accept_payload        (accept_payload                     )
        ,.next_rx_tail_ptr      (next_rx_tail_ptr                   )
        ,.our_win               (our_win                            )
    );

    our_ack_process our_ack_process (
         .pkt_ack_num       (tcp_hdr_reg.ack_num                )
        ,.our_curr_seq_num  (curr_tx_data_reg.our_seq_num       )
        ,.our_curr_ack_state(curr_rx_data_reg.our_ack_state     )
    
        ,.set_rt_flag       (set_rt                             )
        ,.our_next_ack_state(our_ack_state                      )
        ,.next_tx_head_ptr  (next_tx_head_ptr                   )
    );

    always_comb begin
        rx_sched_update_cmd = '0;
        rx_sched_update_cmd.flowid = curr_flowid_reg;
        rx_sched_update_cmd.rt_pend_set_clear.timestamp = '0;
        rx_sched_update_cmd.rt_pend_set_clear.cmd = set_rt_reg
                                                ? SET
                                                : NOP;

        rx_sched_update_cmd.ack_pend_set_clear.timestamp = '0;
        rx_sched_update_cmd.data_pend_set_clear.timestamp = '0;
        rx_sched_update_cmd.data_pend_set_clear.cmd = NOP;

        if (accept_payload_reg || (payload_entry_reg != 0)) begin
            rx_sched_update_cmd.ack_pend_set_clear.cmd = SET;
        end
        else begin
            rx_sched_update_cmd.ack_pend_set_clear.cmd = NOP;
        end
    end

/***************************************************************
 * New flow logic
 **************************************************************/
    assign new_flow_flowid = curr_flowid_reg;

    assign new_flow_lookup_entry.host_ip = dst_ip_reg;
    assign new_flow_lookup_entry.dest_ip = src_ip_reg;
    assign new_flow_lookup_entry.host_port = tcp_hdr_reg.dst_port;
    assign new_flow_lookup_entry.dest_port = tcp_hdr_reg.src_port;

    assign app_new_flow_flowid = curr_flowid_reg;
    assign app_new_flow_entry = new_flow_lookup_entry;

    always_comb begin
        new_flow_rx_state = '0;
        new_flow_rx_state.our_ack_state.ack_num = OUR_SEQ_NUM + 1;

        new_flow_rx_state.their_ack_num = tcp_hdr_reg.seq_num + 1'b1;
        new_flow_rx_state.their_win_size = tcp_hdr_reg.win_size;
        new_flow_rx_state.our_win_size = (1 << RX_PAYLOAD_PTR_W);
    end

    always_comb begin
        new_flow_tx_state = '0;
        new_flow_tx_state.our_seq_num = OUR_SEQ_NUM + 1;
    end
    
    assign new_tx_head_ptr = new_flow_rx_state.our_ack_state.ack_num[TX_PAYLOAD_PTR_W:0];
    assign new_tx_tail_ptr = new_flow_rx_state.our_ack_state.ack_num[TX_PAYLOAD_PTR_W:0];

    assign slow_path_send_pkt_enqueue_src_ip = dst_ip_reg;
    assign slow_path_send_pkt_enqueue_dst_ip = src_ip_reg;
    assign slow_path_send_pkt_enqueue_flowid = curr_flowid_reg;

    tcp_hdr_assembler hdr_assemble (
         .tcp_hdr_req_val       (1'b1                              )
        ,.host_port             (tcp_hdr_reg.dst_port              )
        ,.dest_port             (tcp_hdr_reg.src_port              )
        ,.seq_num               (OUR_SEQ_NUM                       )
        ,.ack_num               (tcp_hdr_reg.seq_num + 1           )
        ,.flags                 (`TCP_SYN | `TCP_ACK               )
        ,.window                ((1 << RX_PAYLOAD_PTR_W) - 1       )
        ,.tcp_hdr_req_rdy       ()

        ,.outbound_tcp_hdr_val   ()
        ,.outbound_tcp_hdr_rdy   (1'b1)
        ,.outbound_tcp_hdr       (slow_path_send_pkt_enqueue_pkt    )
    );

    
endmodule
