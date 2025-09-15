module tcp_buf_mgmt 
import apiary_noc_msg::*;
import mem_msg_pkg::*;
import tcp_pkg::*;
#(
     parameter MONITOR_DATA_W = -1
)(
     input clk
    ,input rst

    ,input                                  src_mgmt_ctrl_cmd_val
    ,input  buf_mgmt_cmd                    src_mgmt_ctrl_cmd
    ,output                                 mgmt_src_ctrl_cmd_rdy

    ,output logic                           mgmt_dst_result_val
    ,output app_cap_resp_struct             mgmt_dst_result_cap
    ,input                                  dst_mgmt_result_rdy

    ,output logic                           mgmt_monitor_noc_val
    ,output logic   [MONITOR_DATA_W-1:0]    mgmt_monitor_noc_data
    ,input  logic                           monitor_mgmt_noc_rdy

    ,input  logic                           monitor_mgmt_noc_val
    ,input  logic   [MONITOR_DATA_W-1:0]    monitor_mgmt_noc_data
    ,output logic                           mgmt_monitor_noc_rdy

    ,output logic                           mgmt_dst_flow_base_addr_val
    ,output logic   [FLOWID_W-1:0]          mgmt_dst_flow_base_address_id
    ,output vaddr_t                         mgmt_dst_flow_base_address
    ,input  logic                           dst_mgmt_flow_base_addr_rdy
);
    logic   ctrl_datap_send_alloc_hdr;
    logic   ctrl_datap_store_cmd;
    logic   ctrl_datap_store_cap_resp;

    tcp_buf_mgmt_ctrl ctrl (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.src_mgmt_ctrl_cmd_val         (src_mgmt_ctrl_cmd_val          )
        ,.src_mgmt_ctrl_cmd_type        (src_mgmt_ctrl_cmd.cmd          )
        ,.mgmt_src_ctrl_cmd_rdy         (mgmt_src_ctrl_cmd_rdy          )
    
        ,.mgmt_monitor_noc_val          (mgmt_monitor_noc_val           )
        ,.monitor_mgmt_noc_rdy          (monitor_mgmt_noc_rdy           )
    
        ,.mgmt_dst_result_val           (mgmt_dst_result_val            )
        ,.dst_mgmt_result_rdy           (dst_mgmt_result_rdy            )
                                         
        ,.mgmt_dst_flow_base_addr_val   (mgmt_dst_flow_base_addr_val    )
        ,.dst_mgmt_flow_base_addr_rdy   (dst_mgmt_flow_base_addr_rdy    )
                                         
        ,.ctrl_datap_store_cmd          (ctrl_datap_store_cmd           )
        ,.ctrl_datap_send_alloc_hdr     (ctrl_datap_send_alloc_hdr      )
        ,.ctrl_datap_store_cap_resp     (ctrl_datap_store_cap_resp      )
    );

    tcp_buf_mgmt_datap #(
         .MONITOR_DATA_W (MONITOR_DATA_W)
    ) datap (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.mgmt_monitor_noc_data         (mgmt_monitor_noc_data          )

        ,.monitor_mgmt_noc_data         (monitor_mgmt_noc_data          )

        ,.src_mgmt_ctrl_cmd             (src_mgmt_ctrl_cmd              )

        ,.mgmt_dst_flow_base_address_id (mgmt_dst_flow_base_address_id  )
        ,.mgmt_dst_flow_base_address    (mgmt_dst_flow_base_address     )

        ,.ctrl_datap_send_alloc_hdr     (ctrl_datap_send_alloc_hdr      )
        ,.ctrl_datap_store_cmd          (ctrl_datap_store_cmd           )
        ,.ctrl_datap_store_cap_resp     (ctrl_datap_store_cap_resp      )
    );
endmodule