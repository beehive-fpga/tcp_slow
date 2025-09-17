module tcp_rx_new_flow_ctrl 
import packet_struct_pkg::*;
import buf_mgmt_pkg::*;
(
     input clk
    ,input rst

    ,input                              slow_path_val
    ,input          tcp_pkt_hdr         slow_path_pkt
    ,output logic                       slow_path_rdy
    
    ,output logic                       new_flow_mgmt_ctrl_cmd_val
    ,input                              mgmt_new_flow_ctrl_cmd_rdy
    
    ,input  logic                       mgmt_new_flow_result_val
    ,output logic                       new_flow_mgmt_result_rdy
    
    ,output logic                       new_flow_tx_buf_mgmt_cmd_val
    ,input                              tx_buf_mgmt_new_flow_cmd_rdy
    
    ,input  logic                       tx_buf_mgmt_new_flow_result_val
    ,output logic                       new_flow_tx_buf_mgmt_result_rdy

    ,output logic                       slow_path_done_val
    ,output logic                       drop_pkt
    ,input  logic                       slow_path_done_rdy

    ,output logic                       flowid_manager_req
    ,input  logic                       flowid_avail
    
    ,output logic                       slow_path_send_pkt_enqueue_val
    ,input                              slow_path_send_pkt_enqueue_rdy

    ,output logic                       init_state_val
    ,input                              init_state_rdy

    ,output logic                       app_flow_notif_val
    ,input  logic                       app_flow_notif_rdy

    ,output logic                       slow_path_store_flowid
    ,output logic                       ctrl_datap_save_cap
    ,output logic                       ctrl_datap_save_tx_cap
);

    typedef enum logic [3:0] {
        STATE_DEC = 4'd0,
        NEW_FLOWID = 4'd1,
        INIT_STATE = 4'd2,
        SETUP_MEM_RX = 4'd6,
        GET_RESP_RX = 4'd7,
        SETUP_MEM_TX = 4'd8,
        GET_RESP_TX = 4'd9,
        SEND_SYN_ACK = 4'd3,
        NOTIF_APP = 4'd4,
        FIN = 4'd5,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;

    logic   drop_pkt_reg;
    logic   drop_pkt_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= STATE_DEC;
            drop_pkt_reg <= 1'b0;
        end
        else begin
            state_reg <= state_next;
            drop_pkt_reg <= drop_pkt_next;
        end
    end


    always_comb begin
        slow_path_rdy = 1'b0;
        init_state_val = 1'b0;
        slow_path_send_pkt_enqueue_val = 1'b0;
        app_flow_notif_val = 1'b0;
        slow_path_done_val = 1'b0;
        slow_path_store_flowid = 1'b0;
        flowid_manager_req = 1'b0;

        new_flow_mgmt_ctrl_cmd_val = 1'b0; 
        new_flow_mgmt_result_rdy = 1'b0;

        ctrl_datap_save_cap = 1'b0;
        ctrl_datap_save_tx_cap = 1'b0;

        drop_pkt_next = drop_pkt_reg;
        state_next = state_reg;
        case (state_reg)
            STATE_DEC: begin
                slow_path_rdy = 1'b1;
                drop_pkt_next = 1'b0;
                if (slow_path_val) begin
                    if (slow_path_pkt.flags == `TCP_SYN) begin
                        state_next = NEW_FLOWID;
                    end
                    else begin
                        drop_pkt_next = 1'b1;
                        state_next = FIN;
                    end
                end
            end
            NEW_FLOWID: begin
                if (flowid_avail) begin
                    flowid_manager_req = 1'b1;
                    slow_path_store_flowid = 1'b1;
                    state_next = INIT_STATE;
                end
                else begin
                    drop_pkt_next = 1'b1;
                    state_next = FIN;
                end
            end
            INIT_STATE: begin
                init_state_val = 1'b1;
                if (init_state_rdy) begin
                    state_next = SETUP_MEM_RX;
                end
            end
            SETUP_MEM_RX: begin
                new_flow_mgmt_ctrl_cmd_val = 1'b1;
                if (mgmt_new_flow_ctrl_cmd_rdy) begin
                    state_next = GET_RESP_RX;
                end
            end
            GET_RESP_RX: begin
                new_flow_mgmt_result_rdy = 1'b1;
                ctrl_datap_save_cap = 1'b1;
                if (mgmt_new_flow_result_val) begin
                    state_next = SEND_SYN_ACK;
                end
            end
            SETUP_MEM_TX: begin
                new_flow_tx_buf_mgmt_cmd_val = 1'b1;
                if (tx_buf_mgmt_new_flow_cmd_rdy) begin
                    state_next = GET_RESP_TX;
                end
            end
            GET_RESP_TX: begin
                ctrl_datap_save_tx_cap = 1'b1;
                new_flow_tx_buf_mgmt_result_rdy = 1'b1;
                if (tx_buf_mgmt_new_flow_result_val) begin
                    state_next = SEND_SYN_ACK;
                end
            end
            SEND_SYN_ACK: begin
                slow_path_send_pkt_enqueue_val = 1'b1;
                if (slow_path_send_pkt_enqueue_rdy) begin
                    state_next = NOTIF_APP;
                end
            end
            NOTIF_APP: begin
                app_flow_notif_val = 1'b1;
                if (app_flow_notif_rdy) begin
                    state_next = FIN;
                end
            end
            FIN: begin
                slow_path_done_val = 1'b1;
                if (slow_path_done_rdy) begin
                    state_next = STATE_DEC;
                end
            end
        endcase
    end
endmodule
