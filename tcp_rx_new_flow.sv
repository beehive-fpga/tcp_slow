module tcp_rx_new_flow_ctrl 
import packet_struct_pkg::*;
(
     input clk
    ,input rst

    ,input                              slow_path_val
    ,input          tcp_pkt_hdr         slow_path_pkt
    ,output logic                       slow_path_rdy

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
);

    typedef enum logic [2:0] {
        STATE_DEC = 3'd0,
        NEW_FLOWID = 3'd1,
        INIT_STATE = 3'd2,
        SEND_SYN_ACK = 3'd3,
        NOTIF_APP = 3'd4,
        FIN = 3'd5,
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
