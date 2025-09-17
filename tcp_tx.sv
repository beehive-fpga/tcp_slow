module tcp_tx 
import tcp_pkg::*;
import tcp_misc_pkg::*;
import packet_struct_pkg::*;
import buf_mgmt_pkg::*;
import mem_msg_pkg::*;
#(
    parameter MONITOR_DATA_W = -1
)(
     input clk
    ,input rst
    
    ,output                                 tx_monitor_noc_val
    ,output [MONITOR_DATA_W-1:0]            tx_monitor_noc_data
    ,input                                  monitor_tx_noc_rdy

    ,input                                  monitor_tx_noc_val
    ,input  [MONITOR_DATA_W-1:0]            monitor_tx_noc_data
    ,output                                 tx_monitor_noc_rdy
    
    ,input                                  sched_tx_req_val
    ,input  sched_data_struct               sched_tx_req_data
    ,output                                 tx_sched_req_rdy
    
    ,output                                 tx_sched_update_val
    ,output sched_cmd_struct                tx_sched_update_cmd
    ,input                                  sched_tx_update_rdy

    ,output logic                           tx_pipe_tx_tail_ptr_rd_req_val
    ,output logic   [FLOWID_W-1:0]          tx_pipe_tx_tail_ptr_rd_req_addr
    ,input  logic                           tx_tail_ptr_tx_pipe_rd_req_rdy
    
    ,input  logic                           tx_tail_ptr_tx_pipe_rd_resp_val
    ,input          [TX_PAYLOAD_PTR_W:0]    tx_tail_ptr_tx_pipe_rd_resp_data
    ,output logic                           tx_pipe_tx_tail_ptr_rd_resp_rdy
    
    ,output                                 tx_buf_mgmt_base_addr_wr_req_val
    ,output         [FLOWID_W-1:0]          tx_buf_mgmt_base_addr_wr_req_addr
    ,output vaddr_t                         tx_buf_mgmt_base_addr_wr_req_data
    ,input                                  base_addr_tx_buf_mgmt_wr_req_rdy

    ,output logic                           tx_pipe_tx_base_addr_rd_req_val
    ,output logic   [FLOWID_W-1:0]          tx_pipe_tx_base_addr_rd_req_data
    ,input  logic                           tx_base_addr_tx_pipe_rd_req_rdy

    ,input  logic                           tx_base_addr_tx_pipe_rd_resp_val
    ,input  vaddr_t                         tx_base_addr_tx_pipe_rd_resp_data
    ,output logic                           tx_pipe_tx_base_addr_rd_resp_rdy 
    
    ,output logic                           tx_pipe_rx_state_rd_req_val
    ,output logic   [FLOWID_W-1:0]          tx_pipe_rx_state_rd_req_addr
    ,input  logic                           rx_state_tx_pipe_rd_req_rdy

    ,input  logic                           rx_state_tx_pipe_rd_resp_val
    ,input  smol_rx_state_struct            rx_state_tx_pipe_rd_resp_data
    ,output logic                           tx_pipe_rx_state_rd_resp_rdy
    
    ,output logic                           tx_pipe_tx_state_rd_req_val
    ,output logic   [FLOWID_W-1:0]          tx_pipe_tx_state_rd_req_addr
    ,input  logic                           tx_state_tx_pipe_rd_req_rdy

    ,input  logic                           tx_state_tx_pipe_rd_resp_val
    ,input  smol_tx_state_struct            tx_state_tx_pipe_rd_resp_data
    ,output logic                           tx_pipe_tx_state_rd_resp_rdy

    ,output logic                           tx_pipe_tx_state_wr_req_val
    ,output logic   [FLOWID_W-1:0]          tx_pipe_tx_state_wr_req_addr
    ,output smol_tx_state_struct            tx_pipe_tx_state_wr_req_data
    ,input  logic                           tx_state_tx_pipe_wr_req_rdy

    ,output logic                           tx_pkt_hdr_val
    ,output vaddr_t                         tx_pkt_base_addr
    ,output tcp_pkt_hdr                     tx_pkt_hdr
    ,output logic   [`IP_ADDR_W-1:0]        tx_pkt_src_ip_addr
    ,output logic   [`IP_ADDR_W-1:0]        tx_pkt_dst_ip_addr
    ,output payload_buf_struct              tx_pkt_payload
    ,input  logic                           tx_pkt_hdr_rdy
    
    ,input  logic                           new_flow_val
    ,input  logic   [FLOWID_W-1:0]          new_flow_flow_id
    ,input  four_tuple_struct               new_flow_lookup_entry
    ,input  smol_rx_state_struct            new_flow_rx_state
    ,output                                 tx_new_flow_rdy
    
    ,input  logic                           new_flow_tx_buf_mgmt_cmd_val
    ,input  buf_mgmt_cmd                    new_flow_tx_buf_mgmt_cmd
    ,output                                 tx_buf_mgmt_new_flow_cmd_rdy
    
    ,output logic                           tx_buf_mgmt_new_flow_result_val
    ,output app_cap_resp_struct             tx_buf_mgmt_new_flow_result
    ,input                                  new_flow_tx_buf_mgmt_result_rdy
);
    
    logic           ctrl_datap_store_flowid;
    logic           ctrl_datap_store_state;
    logic           ctrl_datap_store_calc;
    logic           ctrl_datap_store_tuple;
    logic           ctrl_datap_store_sched;
    logic           ctrl_datap_store_base_addr;

    logic           datap_ctrl_produce_pkt;
    
    logic                   proto_calc_tuple_rd_req_val;
    logic   [FLOWID_W-1:0]  proto_calc_tuple_rd_req_addr;
    logic                   tuple_proto_calc_rd_req_rdy;

    logic                   tuple_proto_calc_rd_resp_val;
    four_tuple_struct       tuple_proto_calc_rd_resp_data;
    logic                   proto_calc_tuple_rd_resp_rdy;
    
    logic                           proto_calc_rx_state_rd_req_val;
    logic   [FLOWID_W-1:0]          proto_calc_rx_state_rd_req_addr;
    logic                           rx_state_proto_calc_rd_req_rdy;

    logic                           rx_state_proto_calc_rd_resp_val;
    smol_rx_state_struct            rx_state_proto_calc_rd_resp_data;
    logic                           proto_calc_rx_state_rd_resp_rdy;
    
    logic                           tx_timeout_rx_state_rd_req_val;
    logic   [FLOWID_W-1:0]          tx_timeout_rx_state_rd_req_addr;
    logic                           rx_state_tx_timeout_rd_req_rdy;

    logic                           rx_state_tx_timeout_rd_resp_val;
    smol_rx_state_struct            rx_state_tx_timeout_rd_resp_data;
    logic                           tx_timeout_rx_state_rd_resp_rdy;
    
    logic                           proto_calc_tx_sched_update_val;
    sched_cmd_struct                proto_calc_tx_sched_update_cmd;
    logic                           tx_sched_proto_calc_update_rdy;
    
    logic                           tx_timeout_tx_sched_update_val;
    sched_cmd_struct                tx_timeout_tx_sched_update_cmd;
    logic                           tx_sched_tx_timeout_update_rdy;


    tcp_tx_datap datap (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.sched_tx_req_data                     (sched_tx_req_data                      )
        
        ,.tx_sched_update_cmd                   (proto_calc_tx_sched_update_cmd         )
    
        ,.tx_pipe_tx_tail_ptr_rd_req_addr       (tx_pipe_tx_tail_ptr_rd_req_addr        )
                                                                                 
        ,.tx_tail_ptr_tx_pipe_rd_resp_data      (tx_tail_ptr_tx_pipe_rd_resp_data       )
    
        ,.tx_pipe_tx_base_addr_rd_req_data      (tx_pipe_tx_base_addr_rd_req_data       )
                                                 
        ,.tx_base_addr_tx_pipe_rd_resp_data     (tx_base_addr_tx_pipe_rd_resp_data      )
    
        ,.proto_calc_curr_tx_state_rd_req_addr  (tx_pipe_tx_state_rd_req_addr           )
                                                                                        
        ,.proto_calc_curr_tx_state_rd_resp_data (tx_state_tx_pipe_rd_resp_data          )
    
        ,.proto_calc_next_tx_state_wr_req_addr  (tx_pipe_tx_state_wr_req_addr           )
        ,.proto_calc_next_tx_state_wr_req_data  (tx_pipe_tx_state_wr_req_data           )
    
        ,.proto_calc_rx_state_rd_req_addr       (proto_calc_rx_state_rd_req_addr        )
                                                 
        ,.rx_state_proto_calc_rd_resp_data      (rx_state_proto_calc_rd_resp_data       )
    
        ,.proto_calc_tuple_rd_req_addr          (proto_calc_tuple_rd_req_addr           )
                                                                              
        ,.tuple_proto_calc_rd_resp_data         (tuple_proto_calc_rd_resp_data          )
    
        ,.ctrl_datap_store_flowid               (ctrl_datap_store_flowid                )
        ,.ctrl_datap_store_state                (ctrl_datap_store_state                 )
        ,.ctrl_datap_store_calc                 (ctrl_datap_store_calc                  )
        ,.ctrl_datap_store_tuple                (ctrl_datap_store_tuple                 )
        ,.ctrl_datap_store_sched                (ctrl_datap_store_sched                 )
        ,.ctrl_datap_store_base_addr            (ctrl_datap_store_base_addr             )

        ,.datap_ctrl_produce_pkt                (datap_ctrl_produce_pkt                 )
    
        ,.proto_calc_tx_pkt_hdr                 (tx_pkt_hdr                             )
        ,.proto_calc_tx_base_addr               (tx_pkt_base_addr                       )
        ,.proto_calc_tx_src_ip_addr             (tx_pkt_src_ip_addr                     )
        ,.proto_calc_tx_dst_ip_addr             (tx_pkt_dst_ip_addr                     )
        ,.proto_calc_tx_payload                 (tx_pkt_payload                         )
    );

    tcp_tx_ctrl ctrl (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.sched_tx_req_val                      (sched_tx_req_val                       )
        ,.tx_sched_req_rdy                      (tx_sched_req_rdy                       )
                                                                                        
        ,.sched_tx_update_val                   (proto_calc_tx_sched_update_val         )
        ,.sched_tx_update_rdy                   (tx_sched_proto_calc_update_rdy         )
                                                                                        
        ,.tx_pipe_tx_tail_ptr_rd_req_val        (tx_pipe_tx_tail_ptr_rd_req_val         )
        ,.tx_tail_ptr_tx_pipe_rd_req_rdy        (tx_tail_ptr_tx_pipe_rd_req_rdy         )
                                                                                        
        ,.tx_tail_ptr_tx_pipe_rd_resp_val       (tx_tail_ptr_tx_pipe_rd_resp_val        )
        ,.tx_pipe_tx_tail_ptr_rd_resp_rdy       (tx_pipe_tx_tail_ptr_rd_resp_rdy        )
    
        ,.tx_pipe_tx_base_addr_rd_req_val       (tx_pipe_tx_base_addr_rd_req_val        )
        ,.tx_base_addr_tx_pipe_rd_req_rdy       (tx_base_addr_tx_pipe_rd_req_rdy        )
                                                 
        ,.tx_base_addr_tx_pipe_rd_resp_val      (tx_base_addr_tx_pipe_rd_resp_val       )
        ,.tx_pipe_tx_base_addr_rd_resp_rdy      (tx_pipe_tx_base_addr_rd_resp_rdy       )
                                                                                        
        ,.proto_calc_curr_tx_state_rd_req_val   (tx_pipe_tx_state_rd_req_val            )
        ,.proto_calc_curr_tx_state_rd_req_rdy   (tx_state_tx_pipe_rd_req_rdy            )
                                                                                        
        ,.proto_calc_curr_tx_state_rd_resp_val  (tx_state_tx_pipe_rd_resp_val           )
        ,.proto_calc_curr_tx_state_rd_resp_rdy  (tx_pipe_tx_state_rd_resp_rdy           )
                                                 
        ,.proto_calc_next_tx_state_wr_req_val   (tx_pipe_tx_state_wr_req_val            )
        ,.proto_calc_next_tx_state_wr_req_rdy   (tx_state_tx_pipe_wr_req_rdy            )
                                                                                        
        ,.proto_calc_rx_state_rd_req_val        (proto_calc_rx_state_rd_req_val         )
        ,.rx_state_proto_calc_rd_req_rdy        (rx_state_proto_calc_rd_req_rdy         )
                                                                                     
        ,.rx_state_proto_calc_rd_resp_val       (rx_state_proto_calc_rd_resp_val        )
        ,.proto_calc_rx_state_rd_resp_rdy       (proto_calc_rx_state_rd_resp_rdy        )
                                                                                        
        ,.proto_calc_tuple_rd_req_val           (proto_calc_tuple_rd_req_val            )
        ,.tuple_proto_calc_rd_req_rdy           (tuple_proto_calc_rd_req_rdy            )
                                                                                        
        ,.tuple_proto_calc_rd_resp_val          (tuple_proto_calc_rd_resp_val           )
        ,.proto_calc_tuple_rd_resp_rdy          (proto_calc_tuple_rd_resp_rdy           )
    
        ,.ctrl_datap_store_flowid               (ctrl_datap_store_flowid                )
        ,.ctrl_datap_store_state                (ctrl_datap_store_state                 )
        ,.ctrl_datap_store_calc                 (ctrl_datap_store_calc                  )
        ,.ctrl_datap_store_tuple                (ctrl_datap_store_tuple                 )
        ,.ctrl_datap_store_sched                (ctrl_datap_store_sched                 )
        ,.ctrl_datap_store_base_addr            (ctrl_datap_store_base_addr             )

        ,.datap_ctrl_produce_pkt                (datap_ctrl_produce_pkt                 )
    
        ,.proto_calc_tx_pkt_val                 (tx_pkt_hdr_val                         )
        ,.proto_calc_tx_pkt_rdy                 (tx_pkt_hdr_rdy                         )
    );
    
    ram_1r1w_sync_backpressure #(
         .width_p   (FOUR_TUPLE_STRUCT_W    )
        ,.els_p     (MAX_FLOW_CNT           )
    ) flowid_to_addr_mem (
         .clk(clk)
        ,.rst(rst)

        ,.wr_req_val    (new_flow_val                   )
        ,.wr_req_addr   (new_flow_flow_id               )
        ,.wr_req_data   (new_flow_lookup_entry          )
        ,.wr_req_rdy    (tx_new_flow_rdy                )

        ,.rd_req_val    (proto_calc_tuple_rd_req_val    )
        ,.rd_req_addr   (proto_calc_tuple_rd_req_addr   )
        ,.rd_req_rdy    (tuple_proto_calc_rd_req_rdy    )

        ,.rd_resp_val   (tuple_proto_calc_rd_resp_val   )
        ,.rd_resp_data  (tuple_proto_calc_rd_resp_data  )
        ,.rd_resp_rdy   (proto_calc_tuple_rd_resp_rdy   )
    );

    tx_timeout_eng tx_timeout_eng (
         .clk   (clk   )
        ,.rst   (rst   )
    
        ,.new_flow_val                      (new_flow_val       )
        ,.new_flow_flowid                   (new_flow_flow_id   )
        ,.new_flow_our_ack_num              (new_flow_rx_state.our_ack_state.ack_num    )
    
        ,.tx_timeout_rx_state_rd_req_val    (tx_timeout_rx_state_rd_req_val     )
        ,.tx_timeout_rx_state_rd_req_addr   (tx_timeout_rx_state_rd_req_addr    )
        ,.rx_state_tx_timeout_rd_req_rdy    (rx_state_tx_timeout_rd_req_rdy     )
                                                                                
        ,.rx_state_tx_timeout_rd_resp_val   (rx_state_tx_timeout_rd_resp_val    )
        ,.rx_state_tx_timeout_rd_resp_data  (rx_state_tx_timeout_rd_resp_data   )
        ,.tx_timeout_rx_state_rd_resp_rdy   (tx_timeout_rx_state_rd_resp_rdy    )
    
        ,.tx_timeout_tx_sched_cmd_val       (tx_timeout_tx_sched_update_val     )
        ,.tx_timeout_tx_sched_cmd_data      (tx_timeout_tx_sched_update_cmd     )
        ,.tx_sched_tx_timeout_cmd_rdy       (tx_sched_tx_timeout_update_rdy     )
    );

    mem_mux #(
         .ADDR_W    (FLOWID_W               )
        ,.DATA_W    (SMOL_RX_STATE_STRUCT_W )
    ) rx_mem_mux (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.src0_rd_req_val   (proto_calc_rx_state_rd_req_val     )
        ,.src0_rd_req_addr  (proto_calc_rx_state_rd_req_addr    )
        ,.src0_rd_req_rdy   (rx_state_proto_calc_rd_req_rdy     )
        
        ,.src0_rd_resp_val  (rx_state_proto_calc_rd_resp_val    )
        ,.src0_rd_resp_data (rx_state_proto_calc_rd_resp_data   )
        ,.src0_rd_resp_rdy  (proto_calc_rx_state_rd_resp_rdy    )
        
        ,.src1_rd_req_val   (tx_timeout_rx_state_rd_req_val     )
        ,.src1_rd_req_addr  (tx_timeout_rx_state_rd_req_addr    )
        ,.src1_rd_req_rdy   (rx_state_tx_timeout_rd_req_rdy     )
        
        ,.src1_rd_resp_val  (rx_state_tx_timeout_rd_resp_val    )
        ,.src1_rd_resp_data (rx_state_tx_timeout_rd_resp_data   )
        ,.src1_rd_resp_rdy  (tx_timeout_rx_state_rd_resp_rdy    )
    
        ,.dst_rd_req_val    (tx_pipe_rx_state_rd_req_val        )
        ,.dst_rd_req_addr   (tx_pipe_rx_state_rd_req_addr       )
        ,.dst_rd_req_rdy    (rx_state_tx_pipe_rd_req_rdy        )
        
        ,.dst_rd_resp_val   (rx_state_tx_pipe_rd_resp_val       )
        ,.dst_rd_resp_data  (rx_state_tx_pipe_rd_resp_data      )
        ,.dst_rd_resp_rdy   (tx_pipe_rx_state_rd_resp_rdy       )
    );

    prio0_mux #(
        .DATA_W (SCHED_CMD_STRUCT_W )
    ) tx_sched_mux (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.src0_val  (proto_calc_tx_sched_update_val )
        ,.src0_data (proto_calc_tx_sched_update_cmd )
        ,.src0_rdy  (tx_sched_proto_calc_update_rdy )
    
        ,.src1_val  (tx_timeout_tx_sched_update_val )
        ,.src1_data (tx_timeout_tx_sched_update_cmd )
        ,.src1_rdy  (tx_sched_tx_timeout_update_rdy )
    
        ,.dst_val   (tx_sched_update_val            )
        ,.dst_data  (tx_sched_update_cmd            )
        ,.dst_rdy   (sched_tx_update_rdy            )
    );

    tcp_buf_mgmt #(
         .MONITOR_DATA_W (MONITOR_DATA_W    )
    ) tx_buf_mgmt (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.src_mgmt_ctrl_cmd_val        (new_flow_tx_buf_mgmt_cmd_val    )
        ,.src_mgmt_ctrl_cmd            (new_flow_tx_buf_mgmt_cmd        )
        ,.mgmt_src_ctrl_cmd_rdy        (tx_buf_mgmt_new_flow_cmd_rdy    )

        ,.mgmt_dst_result_val          (tx_buf_mgmt_new_flow_result_val )
        ,.mgmt_dst_result_cap          (tx_buf_mgmt_new_flow_result     )
        ,.dst_mgmt_result_rdy          (new_flow_tx_buf_mgmt_result_rdy )

        ,.mgmt_monitor_noc_val         (tx_monitor_noc_val              )
        ,.mgmt_monitor_noc_data        (tx_monitor_noc_data             )
        ,.monitor_mgmt_noc_rdy         (monitor_tx_noc_rdy              )

        ,.monitor_mgmt_noc_val         (monitor_tx_noc_val              )
        ,.monitor_mgmt_noc_data        (monitor_tx_noc_data             )
        ,.mgmt_monitor_noc_rdy         (tx_monitor_noc_rdy              )

        ,.mgmt_dst_flow_base_addr_val  (tx_buf_mgmt_base_addr_wr_req_val    )
        ,.mgmt_dst_flow_base_address_id(tx_buf_mgmt_base_addr_wr_req_addr   )
        ,.mgmt_dst_flow_base_address   (tx_buf_mgmt_base_addr_wr_req_data   )
        ,.dst_mgmt_flow_base_addr_rdy  (base_addr_tx_buf_mgmt_wr_req_rdy    )
    );

endmodule

