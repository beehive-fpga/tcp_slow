module tcp_rx_ctrl (
     input clk
    ,input rst

    ,input  logic                           rx_tcp_hdr_val
    ,output logic                           rx_hdr_rdy
    
    ,output logic                           tcp_rx_dst_hdr_val
    ,input  logic                           dst_tcp_rx_hdr_rdy

    ,output logic                           read_flow_cam_val
    ,input  logic                           read_flow_cam_hit

    ,output logic                           curr_rx_state_rd_req_val
    ,input  logic                           curr_rx_state_rd_req_rdy
    
    ,input  logic                           curr_rx_state_rd_resp_val
    ,output logic                           curr_rx_state_rd_resp_rdy

    ,output logic                           next_rx_state_wr_req_val
    ,input  logic                           next_rx_state_wr_req_rdy

    ,output logic                           curr_tx_state_rd_req_val
    ,input  logic                           curr_tx_state_rd_req_rdy

    ,input  logic                           curr_tx_state_rd_resp_val
    ,output logic                           curr_tx_state_rd_resp_rdy
    
    ,output logic                           rx_pipe_rx_head_idx_rd_req_val
    ,input  logic                           rx_head_idx_rx_pipe_rd_req_rdy

    ,input  logic                           rx_head_idx_rx_pipe_rd_resp_val
    ,output logic                           rx_pipe_rx_head_idx_rd_resp_rdy
    
    ,output logic                           rx_pipe_rx_tail_idx_wr_req_val
    ,input  logic                           rx_tail_idx_rx_pipe_wr_req_rdy

    ,output logic                           rx_pipe_rx_tail_idx_rd_req_val
    ,input  logic                           rx_tail_idx_rx_pipe_rd_req_rdy

    ,input  logic                           rx_tail_idx_rx_pipe_rd_resp_val
    ,output logic                           rx_pipe_rx_tail_idx_rd_resp_rdy
    
    ,output logic                           rx_pipe_tx_head_ptr_wr_req_val
    ,input                                  tx_head_ptr_rx_pipe_wr_req_rdy

    ,output logic                           ctrl_datap_save_input
    ,output logic                           ctrl_datap_save_flow_state
    ,output logic                           ctrl_datap_save_calcs
    ,output logic                           ctrl_datap_save_malloc_resp
    ,input  logi                            datap_ctrl_payload_accepted

    ,output logic                           rx_sched_update_val
    ,input  logic                           sched_rx_update_rdy

    ,output logic                           store_flowid_cam

    ,output logic                           slow_path_val
    ,input  logic                           slow_path_rdy

    ,input  logic                           slow_path_done_val
    ,output logic                           slow_path_done_rdy

    ,output                                 rx_pipe_rx_malloc_req_val
    ,input                                  rx_malloc_rx_pipe_req_rdy

    ,input                                  rx_malloc_rx_pipe_resp_val
    ,output                                 rx_pipe_rx_malloc_resp_rdy

    ,output                                 rx_pipe_rx_buf_store_wr_req_val   
    ,input                                  rx_buf_store_rx_pipe_wr_req_rdy   
);

    typedef enum logic[3:0] {
        READ_FLOW_TABLE = 4'd0,
        READ_STATE = 4'd1,
        START_NEW_FLOW_SETUP = 4'd2,
        WAIT_NEW_FLOW_SETUP = 4'd3,
        WAIT_STATE_RESP = 4'd4,
        CALCULATE = 4'd5,
        WRITEBACK1 = 4'd6,
        SCHEDULE = 4'd7,
        PKT_OUT = 4'd8,
        WAIT_MALLOC_REQ = 4'd9;
        WAIT_MALLOC_RESP = 4'd10;
        WRITEBACK2 = 4'd11;
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READ_FLOW_TABLE;
        end
        else begin
            state_reg <= state_next;
        end
    end
    

    always_comb begin
        read_flow_cam_val = 1'b0;
        ctrl_datap_save_input = 1'b0;
        ctrl_datap_save_flow_state = 1'b0;
        ctrl_datap_save_calcs = 1'b0;
        ctrl_datap_save_malloc_resp = 1'b0;

        tcp_rx_dst_hdr_val = 1'b0;

        curr_rx_state_rd_req_val = 1'b0;
        curr_tx_state_rd_req_val = 1'b0;
        rx_pipe_rx_head_idx_rd_req_val = 1'b0;
        rx_pipe_rx_tail_idx_rd_req_val = 1'b0;

        rx_pipe_rx_tail_idx_wr_req_val = 1'b0;
        rx_pipe_tx_head_ptr_wr_req_val = 1'b0;
    
        curr_tx_state_rd_resp_rdy = 1'b0;
        curr_rx_state_rd_resp_rdy = 1'b0;
        rx_pipe_rx_head_idx_rd_resp_rdy = 1'b0;
        rx_pipe_rx_tail_idx_rd_resp_rdy = 1'b0;

        next_rx_state_wr_req_val = 1'b0;

        rx_hdr_rdy = 1'b0;

        slow_path_val = 1'b0;
        slow_path_done_rdy = 1'b0;

        store_flowid_cam = 1'b0;

        rx_sched_update_val = 1'b0;

        state_next = state_reg;
        case (state_reg)
            READ_FLOW_TABLE: begin
                rx_hdr_rdy = 1'b1;
                ctrl_datap_save_input = 1'b1;
                read_flow_cam_val = rx_tcp_hdr_val;
                store_flowid_cam = 1'b1;

                if (rx_tcp_hdr_val) begin
                    if (read_flow_cam_hit) begin
                        state_next = READ_STATE;
                    end
                    else begin
                        state_next = START_NEW_FLOW_SETUP;
                    end
                end
            end
            READ_STATE: begin
                curr_rx_state_rd_req_val = 1'b1;
                curr_tx_state_rd_req_val = 1'b1;
                rx_pipe_rx_head_idx_rd_req_val = 1'b1;
                rx_pipe_rx_tail_idx_rd_req_val = 1'b1;

                curr_tx_state_rd_resp_rdy = 1'b1;
                curr_rx_state_rd_resp_rdy = 1'b1;
                rx_pipe_rx_head_idx_rd_resp_rdy = 1'b1;
                rx_pipe_rx_tail_idx_rd_resp_rdy = 1'b1;

                if (curr_rx_state_rd_req_rdy & curr_tx_state_rd_req_rdy & 
                    rx_head_idx_rx_pipe_rd_req_rdy & rx_tail_idx_rx_pipe_rd_req_rdy) begin
                    state_next = WAIT_STATE_RESP;
                end
            end
            START_NEW_FLOW_SETUP: begin
                slow_path_val = 1'b1;
                if (slow_path_rdy) begin
                    state_next = WAIT_NEW_FLOW_SETUP;
                end
            end
            WAIT_NEW_FLOW_SETUP: begin
                slow_path_done_rdy = 1'b1;
                if (slow_path_done_val) begin
                    state_next = READ_FLOW_TABLE;
                end
            end
            WAIT_STATE_RESP: begin
                ctrl_datap_save_flow_state = 1'b1;
                if (curr_rx_state_rd_resp_val & curr_tx_state_rd_resp_val &
                  rx_head_idx_rx_pipe_rd_resp_val & rx_tail_idx_rx_pipe_rd_resp_val) begin
                    curr_rx_state_rd_resp_rdy = 1'b1;
                    curr_tx_state_rd_resp_rdy = 1'b1;
                    rx_pipe_rx_head_idx_rd_resp_rdy = 1'b1;
                    rx_pipe_rx_tail_idx_rd_resp_rdy = 1'b1;
                    state_next = WAIT_MALLOC_REQ;
                end
            end
            // TODO: future optimization to move malloc to READ_STATE, but then need to free if packet not accepted.
            WAIT_MALLOC_REQ: begin
                rx_pipe_rx_malloc_req_val = 1'b1;
                if (rx_pipe_rx_malloc_req_val && rx_malloc_rx_pipe_req_ready) begin
                    state_next = WAIT_MALLOC_RESP;
                end
            end
            WAIT_MALLOC_RESP: begin
                rx_pipe_rx_malloc_resp_rdy = 1'b1;
                ctrl_datap_save_malloc_resp = 1'b1;
                if (rx_malloc_rx_pipe_resp_vld && rx_pipe_rx_malloc_resp_rdy) begin
                    state_next = CALCULATE;
                end
            end
            CALCULATE: begin
                ctrl_datap_save_calcs = 1'b1;
                state_next = WRITEBACK1;
            end
            WRITEBACK1: begin
                next_rx_state_wr_req_val = 1'b1;
                rx_pipe_rx_tail_idx_wr_req_val = 1'b1;
                rx_pipe_tx_head_ptr_wr_req_val = 1'b1;

                if (next_rx_state_wr_req_rdy & rx_tail_idx_rx_pipe_wr_req_rdy &
                    tx_head_ptr_rx_pipe_wr_req_rdy) begin
                    state_next = WRITEBACK2;
                end
            end
            WRITEBACK2: begin
                rx_pipe_rx_buf_store_wr_req_val = datap_ctrl_payload_accepted;
                if (~datap_ctrl_payload_accepted) begin
                    state_next = SCHEDULE;
                end else if (rx_pipe_rx_buf_store_wr_req_val && rx_buf_store_rx_pipe_wr_req_rdy) begin
                    state_next = SCHEDULE;
                end
            end
            SCHEDULE: begin
                rx_sched_update_val = 1'b1;
                if (sched_rx_update_rdy) begin
                    state_next = PKT_OUT;
                end
            end
            PKT_OUT: begin
                tcp_rx_dst_hdr_val = 1'b1;
                if (dst_tcp_rx_hdr_rdy) begin
                    state_next = READ_FLOW_TABLE;
                end
            end
        endcase
    end
endmodule
