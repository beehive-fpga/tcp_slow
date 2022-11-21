module tcp_tx_ctrl 
import tcp_pkg::*;
(
     input clk
    ,input rst

    ,input  logic           sched_tx_req_val
    ,output logic           sched_tx_req_rdy

    ,output logic           sched_tx_update_val
    ,input  logic           sched_tx_update_rdy

    ,output logic           tx_pipe_tx_tail_ptr_rd_req_val
    ,input  logic           tx_tail_ptr_tx_pipe_rd_req_rdy
    
    ,input  logic           tx_tail_ptr_tx_pipe_rd_resp_val
    ,output logic           tx_pipe_tx_tail_ptr_rd_resp_rdy

    ,output logic           proto_calc_curr_tx_state_rd_req_val
    ,input  logic           proto_calc_curr_tx_state_rd_req_rdy
    
    ,input  logic           proto_calc_curr_tx_state_rd_resp_val
    ,output logic           proto_calc_curr_tx_state_rd_resp_rdy

    ,output logic           proto_calc_next_tx_state_wr_req_val
    ,input  logic           proto_calc_next_tx_state_wr_req_rdy
    
    ,output logic           proto_calc_rx_state_rd_req_val
    ,input  logic           rx_state_proto_calc_rd_req_rdy

    ,input  logic           rx_state_proto_calc_rd_resp_val
    ,output logic           proto_calc_rx_state_rd_resp_rdy
    
    ,output logic           proto_calc_tuple_rd_req_val
    ,input  logic           tuple_proto_calc_rd_req_rdy

    ,input  logic           tuple_proto_calc_rd_resp_val
    ,output logic           proto_calc_tuple_rd_resp_rdy

    ,output logic           ctrl_datap_store_flowid
    ,output logic           ctrl_datap_store_state
    ,output logic           ctrl_datap_store_calc
    ,output logic           ctrl_datap_store_tuple

    ,output logic           proto_calc_tx_pkt_val
    ,input  logic           proto_calc_tx_pkt_rdy
);

    typedef enum logic[2:0] {
        READ_SCHED = 3'd0,
        RD_STATE = 3'd1,
        RD_TUPLE = 3'd2,
        WAIT_TUPLE_RESP = 3'd3,
        CALC = 3'd4,
        WRITEBACK = 3'd5,
        PKT_OUT = 3'd6,
        SCHED_UPDATE = 3'd7,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READ_SCHED;
        end
        else begin
            state_reg <= state_next;
        end
    end

    always_comb begin
        sched_tx_req_rdy = 1'b0;
        ctrl_datap_store_flowid = 1'b0;
        ctrl_datap_store_state = 1'b0;
        ctrl_datap_save_calcs = 1'b0;

        tx_pipe_tx_tail_ptr_rd_req_val = 1'b0;
        tx_pipe_tx_tail_ptr_rd_resp_rdy = 1'b0;

        proto_calc_curr_tx_state_rd_req_val = 1'b0;
        proto_calc_curr_tx_state_rd_resp_rdy = 1'b0;

        proto_calc_rx_state_rd_req_val = 1'b0;
        proto_calc_rx_state_rd_resp_rdy = 1'b0;

        proto_calc_tx_pkt_val = 1'b0;

        state_next = state_reg;
        case (state_reg)
            READ_SCHED: begin
                sched_tx_req_rdy = 1'b1;
                ctrl_datap_store_flowid = 1'b1;

                if (sched_tx_req_val) begin
                    state_next = RD_STATE;
                end
            end
            RD_STATE: begin
                proto_calc_curr_tx_state_rd_req_val = 1'b1;
                proto_calc_rx_state_rd_req_val = 1'b1;
                tx_pipe_tx_tail_ptr_rd_req_val = 1'b1;

                proto_calc_curr_tx_state_rd_resp_val = 1'b1;
                proto_calc_rx_state_rd_resp_rdy = 1'b1;
                tx_pipe_tx_tail_ptr_rd_resp_rdy = 1'b1;

                if (proto_calc_curr_tx_state_rd_req_rdy & rx_state_proto_calc_rd_req_rdy
                    & tx_tail_ptr_tx_pipe_rd_req_rdy) begin
                    state_next = RD_TUPLE;
                end
            end
            RD_TUPLE: begin
                ctrl_datap_store_state = 1'b1;

                proto_calc_tuple_rd_req_val = 1'b1;

                proto_calc_tuple_rd_resp_rdy = 1'b1;
                if (proto_calc_curr_tx_state_rd_resp_val & tx_tail_ptr_tx_pipe_rd_resp_val
                    & rx_state_proto_calc_rd_resp_val & tuple_proto_calc_rd_req_rdy) begin
                    proto_calc_curr_tx_state_rd_resp_rdy = 1'b1;
                    tx_pipe_tx_tail_ptr_rd_resp_rdy = 1'b1;
                    proto_calc_rx_state_rd_resp_rdy = 1'b1;
                    state_next = CALC;
                end
            end
            CALC: begin
                ctrl_datap_save_calcs = 1'b1;
                ctrl_datap_store_tuple = 1'b1;

                if (tuple_proto_calc_rd_resp_val) begin
                    state_next = WRITEBACK;
                end
            end
            PKT_OUT: begin
                proto_calc_tx_pkt_val = 1'b1;
                if (proto_calc_tx_pkt_rdy) begin
                    state_next = WRITEBACK;
                end
            end
            WRITEBACK: begin
                proto_calc_next_tx_state_wr_req_val = 1'b1;

                if (proto_calc_next_tx_state_wr_req_rdy) begin
                    state_next = SCHED_UPDATE;
                end
            end
            SCHED_UPDATE: begin
                sched_tx_req_val = 1'b1;
                if (sched_tx_update_rdy) begin
                    state_next = READ_SCHED;
                end
            end
        endcase
    end
endmodule

