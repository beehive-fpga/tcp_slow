module tcp_buf_mgmt_datap 
import mem_msg_pkg::*;
import tcp_pkg::*;
import buf_mgmt_pkg::*;
import apiary_noc_msg::*;
#(
     parameter MONITOR_DATA_W = -1
)
(
     input clk
    ,input rst
    ,output [MONITOR_DATA_W-1:0]            mgmt_monitor_noc_data
    
    ,input  [MONITOR_DATA_W-1:0]            monitor_mgmt_noc_data

    ,input  buf_mgmt_cmd                    src_mgmt_ctrl_cmd

    ,output app_cap_resp_struct             mgmt_dst_result_cap
    
    ,output logic   [FLOWID_W-1:0]  mgmt_dst_flow_base_address_id
    ,output vaddr_t                 mgmt_dst_flow_base_address

    ,input  logic   ctrl_datap_send_alloc_hdr
    ,input  logic   ctrl_datap_store_cmd
    ,input  logic   ctrl_datap_store_cap_resp
);
    localparam APP_CAP_REQ_STRUCT_PADDING = MONITOR_DATA_W - APP_CAP_REQ_STRUCT_W;

    apiary_hdr_flit cap_req_hdr_flit;
    app_cap_req_struct cap_req_body_flit;

    app_cap_resp_struct cap_reg;
    app_cap_resp_struct cap_next;

    buf_mgmt_cmd    cmd_reg;
    buf_mgmt_cmd    cmd_next;

    assign mgmt_dst_flow_base_address = cap_reg.addr;
    assign mgmt_dst_flow_base_address_id = src_mgmt_ctrl_cmd.flowid;

    assign mgmt_dst_result_cap = cap_reg;

    always_ff @(posedge clk) begin
        cmd_reg <= cmd_next;
        cap_reg <= cap_next;
    end

    assign cap_next = ctrl_datap_store_cap_resp
                    ? monitor_mgmt_noc_data[MONITOR_DATA_W-1 -: APP_CAP_RESP_STRUCT_W]
                    : cap_reg;

    assign cmd_next = ctrl_datap_store_cmd
                    ? src_mgmt_ctrl_cmd
                    : cmd_reg;

    assign mgmt_monitor_noc_data = ctrl_datap_send_alloc_hdr
                                ? cap_req_hdr_flit 
                                : {cap_req_body_flit, {APP_CAP_REQ_STRUCT_PADDING{1'b0}}};
    
    
    always_comb begin
        cap_req_hdr_flit = '0;
        cap_req_hdr_flit.core.dst_x_coord = '1;
        cap_req_hdr_flit.core.dst_y_coord = '1;
        cap_req_hdr_flit.core.dst_fbits = MEM_MANAGE_FBITS;
        cap_req_hdr_flit.core.msg_type = ALLOC_MEM;
        cap_req_hdr_flit.core.msg_len = 1;
        cap_req_hdr_flit.core.src_x_coord = '1;
        cap_req_hdr_flit.core.src_y_coord = '1;
        cap_req_hdr_flit.core.src_fbits = PKT_IF_FBITS;
    end

    always_comb begin
        cap_req_body_flit = '0;
        cap_req_body_flit.size = 1 << PAYLOAD_PTR_W;
        cap_req_body_flit.perm_flags = PERM_WRITE | PERM_READ;
    end
endmodule