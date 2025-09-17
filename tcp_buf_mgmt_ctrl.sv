module tcp_buf_mgmt_ctrl 
import buf_mgmt_pkg::*;
(
     input clk
    ,input rst

    ,input              src_mgmt_ctrl_cmd_val
    ,input  buf_cmd_e   src_mgmt_ctrl_cmd_type
    ,output logic       mgmt_src_ctrl_cmd_rdy
    
    ,output logic                           mgmt_dst_result_val
    ,input                                  dst_mgmt_result_rdy
    
    ,output logic                           mgmt_monitor_noc_val
    ,input                                  monitor_mgmt_noc_rdy
    
    ,input  logic                           monitor_mgmt_noc_val
    ,output logic                           mgmt_monitor_noc_rdy

    ,output logic   mgmt_dst_flow_base_addr_val
    ,input  logic   dst_mgmt_flow_base_addr_rdy

    ,output logic   ctrl_datap_store_cmd
    ,output logic   ctrl_datap_send_alloc_hdr
    ,output logic   ctrl_datap_store_cap_resp
);

    typedef enum logic[2:0] {
        READY = 3'd0,
        PARSE_CMD = 3'd1,
        ALLOC_CAP_HDR = 3'd2,
        ALLOC_CAP_BODY = 3'd3,
        WAIT_ALLOC_RESP = 3'd4,
        SET_BASE_ADDR = 3'd5,
        REPLY = 3'd6,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;

    buf_cmd_e   cmd_reg;
    buf_cmd_e   cmd_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
        end
        else begin
            state_reg <= state_next;
            cmd_reg <= cmd_next;
        end
    end

    always_comb begin
        mgmt_src_ctrl_cmd_rdy = 1'b0;
        ctrl_datap_send_alloc_hdr = 1'b0;
        ctrl_datap_store_cmd = 1'b0;
        ctrl_datap_store_cap_resp = 1'b0;

        mgmt_monitor_noc_val = 1'b0;
        mgmt_monitor_noc_rdy = 1'b0;

        cmd_next = cmd_reg;
        state_next = state_reg;
        case (state_reg)
            READY: begin
                mgmt_src_ctrl_cmd_rdy = 1'b1;
                cmd_next = src_mgmt_ctrl_cmd_type;
                ctrl_datap_store_cmd = 1'b1;
                if (src_mgmt_ctrl_cmd_val) begin
                    state_next = PARSE_CMD;
                end
            end
            PARSE_CMD: begin
                case (cmd_reg)
                    NEW_FLOW: begin
                        state_next = ALLOC_CAP_HDR;
                    end
                endcase
            end
            ALLOC_CAP_HDR: begin
                ctrl_datap_send_alloc_hdr = 1'b1;
                mgmt_monitor_noc_val = 1'b1;
                if (monitor_mgmt_noc_rdy) begin
                    state_next = ALLOC_CAP_BODY;
                end
            end
            ALLOC_CAP_BODY: begin
                mgmt_monitor_noc_val = 1'b1;
                if (monitor_mgmt_noc_rdy) begin
                    state_next = WAIT_ALLOC_RESP;
                end
            end
            WAIT_ALLOC_RESP: begin
                mgmt_monitor_noc_rdy = 1'b1;
                ctrl_datap_store_cap_resp = 1'b1;
                if (monitor_mgmt_noc_val) begin
                    state_next = SET_BASE_ADDR;
                end
            end
            SET_BASE_ADDR: begin
                mgmt_dst_flow_base_addr_val = monitor_mgmt_noc_val;
                mgmt_monitor_noc_rdy = dst_mgmt_flow_base_addr_rdy;
                if (monitor_mgmt_noc_val & dst_mgmt_flow_base_addr_rdy) begin
                    state_next = REPLY;
                end
            end
            REPLY: begin
                mgmt_dst_result_val = 1'b1;
                if (dst_mgmt_result_rdy) begin
                    state_next = READY;
                end
            end
        endcase
    end
endmodule
