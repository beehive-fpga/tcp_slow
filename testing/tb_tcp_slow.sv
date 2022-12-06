`include "packet_defs.vh"
module tb_tcp_slow 
import tcp_pkg::*;
import tcp_misc_pkg::*;
import packet_struct_pkg::*;
(
     input clk
    ,input rst

    ,input                                          src_tcp_rx_hdr_val
    ,output logic                                   tcp_src_rx_hdr_rdy
    ,input          [`IP_ADDR_W-1:0]                src_tcp_rx_src_ip
    ,input          [`IP_ADDR_W-1:0]                src_tcp_rx_dst_ip
    ,input  logic   [TCP_HDR_W-1:0]                 src_tcp_rx_tcp_hdr
    ,input  logic   [SMOL_PAYLOAD_BUF_STRUCT_W-1:0] src_tcp_rx_payload_entry

    ,output logic                                   tx_pkt_hdr_val
    ,output logic   [FLOWID_W-1:0]                  tx_pkt_flowid
    ,output logic   [TCP_HDR_W-1:0]                 tx_pkt_hdr
    ,output logic   [`IP_ADDR_W-1:0]                tx_pkt_src_ip_addr
    ,output logic   [`IP_ADDR_W-1:0]                tx_pkt_dst_ip_addr
    ,output logic   [SMOL_PAYLOAD_BUF_STRUCT_W-1:0] tx_pkt_payload
    ,input  logic                                   tx_pkt_hdr_rdy
   
    /********************************
     * RX copy to buffers
     *******************************/
    ,output logic                                   tcp_rx_dst_hdr_val
    ,output logic   [FLOWID_W-1:0]                  tcp_rx_dst_flowid
    ,output logic                                   tcp_rx_dst_pkt_accept
    ,output logic   [SMOL_PAYLOAD_BUF_STRUCT_W-1:0] tcp_rx_dst_payload_entry
    ,input  logic                                   dst_tcp_rx_hdr_rdy

    ,input  logic                               store_buf_commit_ptr_wr_req_val
    ,input  logic   [FLOWID_W-1:0]              store_buf_commit_ptr_wr_req_addr
    ,input  logic   [RX_PAYLOAD_PTR_W:0]        store_buf_commit_ptr_wr_req_data
    ,output logic                               commit_ptr_store_buf_wr_req_rdy

    ,input  logic                               store_buf_commit_ptr_rd_req_val
    ,input  logic   [FLOWID_W-1:0]              store_buf_commit_ptr_rd_req_addr
    ,output logic                               commit_ptr_store_buf_rd_req_rdy

    ,output logic                               commit_ptr_store_buf_rd_resp_val
    ,output logic   [RX_PAYLOAD_PTR_W:0]        commit_ptr_store_buf_rd_resp_data
    ,input  logic                               store_buf_commit_ptr_rd_resp_rdy

    /********************************
     * App interface
     *******************************/
    ,output logic                               app_new_flow_notif_val
    ,output logic   [FLOWID_W-1:0]              app_new_flow_flowid
    ,output logic   [FOUR_TUPLE_STRUCT_W-1:0]   app_new_flow_entry
    ,input  logic                               app_new_flow_notif_rdy
    
    ,input  logic                               app_rx_head_ptr_wr_req_val
    ,input  logic   [FLOWID_W-1:0]              app_rx_head_ptr_wr_req_addr
    ,input  logic   [RX_PAYLOAD_PTR_W:0]        app_rx_head_ptr_wr_req_data
    ,output logic                               rx_head_ptr_app_wr_req_rdy

    ,input  logic                               app_rx_head_ptr_rd_req_val
    ,input  logic   [FLOWID_W-1:0]              app_rx_head_ptr_rd_req_addr
    ,output logic                               rx_head_ptr_app_rd_req_rdy
    
    ,output logic                               rx_head_ptr_app_rd_resp_val
    ,output logic   [RX_PAYLOAD_PTR_W:0]        rx_head_ptr_app_rd_resp_data
    ,input  logic                               app_rx_head_ptr_rd_resp_rdy
    
    ,input  logic                               app_rx_commit_ptr_rd_req_val
    ,input  logic   [FLOWID_W-1:0]              app_rx_commit_ptr_rd_req_addr
    ,output logic                               rx_commit_ptr_app_rd_req_rdy

    ,output logic                               rx_commit_ptr_app_rd_resp_val
    ,output logic   [RX_PAYLOAD_PTR_W:0]        rx_commit_ptr_app_rd_resp_data
    ,input  logic                               app_rx_commit_ptr_rd_resp_rdy
    
    ,input                                      app_tx_head_ptr_rd_req_val
    ,input          [FLOWID_W-1:0]              app_tx_head_ptr_rd_req_addr
    ,output logic                               tx_head_ptr_app_rd_req_rdy

    ,output                                     tx_head_ptr_app_rd_resp_val
    ,output logic   [FLOWID_W-1:0]              tx_head_ptr_app_rd_resp_addr
    ,output logic   [TX_PAYLOAD_PTR_W:0]        tx_head_ptr_app_rd_resp_data
    ,input  logic                               app_tx_head_ptr_rd_resp_rdy
    
    ,input                                      app_tx_tail_ptr_wr_req_val
    ,input          [FLOWID_W-1:0]              app_tx_tail_ptr_wr_req_addr
    ,input          [TX_PAYLOAD_PTR_W:0]        app_tx_tail_ptr_wr_req_data
    ,output                                     tx_tail_ptr_app_wr_req_rdy
    
    ,input  logic                               app_sched_update_val
    ,input  logic   [SCHED_CMD_STRUCT_W-1:0]    app_sched_update_cmd
    ,output logic                               sched_app_update_rdy
    
    ,input                                      app_tx_tail_ptr_rd_req_val
    ,input          [FLOWID_W-1:0]              app_tx_tail_ptr_rd_req_addr
    ,output logic                               tx_tail_ptr_app_rd_req_rdy
    
    ,output                                     tx_tail_ptr_app_rd_resp_val
    ,output logic   [FLOWID_W-1:0]              tx_tail_ptr_app_rd_resp_flowid
    ,output logic   [TX_PAYLOAD_PTR_W:0]        tx_tail_ptr_app_rd_resp_data
    ,input  logic                               app_tx_tail_ptr_rd_resp_rdy
);

    tcp DUT (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.src_tcp_rx_hdr_val        (src_tcp_rx_hdr_val         )
        ,.tcp_src_rx_hdr_rdy        (tcp_src_rx_hdr_rdy         )
        ,.src_tcp_rx_src_ip         (src_tcp_rx_src_ip          )
        ,.src_tcp_rx_dst_ip         (src_tcp_rx_dst_ip          )
        ,.src_tcp_rx_tcp_hdr        (src_tcp_rx_tcp_hdr         )
        ,.src_tcp_rx_payload_entry  (src_tcp_rx_payload_entry   )
                                                                
        ,.tx_pkt_hdr_val            (tx_pkt_hdr_val             )
        ,.tx_pkt_flowid             (tx_pkt_flowid              )
        ,.tx_pkt_hdr                (tx_pkt_hdr                 )
        ,.tx_pkt_src_ip_addr        (tx_pkt_src_ip_addr         )
        ,.tx_pkt_dst_ip_addr        (tx_pkt_dst_ip_addr         )
        ,.tx_pkt_payload            (tx_pkt_payload             )
        ,.tx_pkt_hdr_rdy            (tx_pkt_hdr_rdy             )
       
        /********************************
         * RX copy to buffers
         *******************************/
        ,.tcp_rx_dst_hdr_val                (tcp_rx_dst_hdr_val                 )
        ,.tcp_rx_dst_flowid                 (tcp_rx_dst_flowid                  )
        ,.tcp_rx_dst_pkt_accept             (tcp_rx_dst_pkt_accept              )
        ,.tcp_rx_dst_payload_entry          (tcp_rx_dst_payload_entry           )
        ,.dst_tcp_rx_hdr_rdy                (dst_tcp_rx_hdr_rdy                 )
                                                                                
        ,.store_buf_commit_ptr_wr_req_val   (store_buf_commit_ptr_wr_req_val    )
        ,.store_buf_commit_ptr_wr_req_addr  (store_buf_commit_ptr_wr_req_addr   )
        ,.store_buf_commit_ptr_wr_req_data  (store_buf_commit_ptr_wr_req_data   )
        ,.commit_ptr_store_buf_wr_req_rdy   (commit_ptr_store_buf_wr_req_rdy    )
                                                                                
        ,.store_buf_commit_ptr_rd_req_val   (store_buf_commit_ptr_rd_req_val    )
        ,.store_buf_commit_ptr_rd_req_addr  (store_buf_commit_ptr_rd_req_addr   )
        ,.commit_ptr_store_buf_rd_req_rdy   (commit_ptr_store_buf_rd_req_rdy    )
                                                                                
        ,.commit_ptr_store_buf_rd_resp_val  (commit_ptr_store_buf_rd_resp_val   )
        ,.commit_ptr_store_buf_rd_resp_data (commit_ptr_store_buf_rd_resp_data  )
        ,.store_buf_commit_ptr_rd_resp_rdy  (store_buf_commit_ptr_rd_resp_rdy   )
    
        /********************************
         * App interface
         *******************************/
        ,.app_new_flow_notif_val            (app_new_flow_notif_val         )
        ,.app_new_flow_flowid               (app_new_flow_flowid            )
        ,.app_new_flow_entry                (app_new_flow_entry             )
        ,.app_new_flow_notif_rdy            (app_new_flow_notif_rdy         )
                                                                            
        ,.app_rx_head_ptr_wr_req_val        (app_rx_head_ptr_wr_req_val     )
        ,.app_rx_head_ptr_wr_req_addr       (app_rx_head_ptr_wr_req_addr    )
        ,.app_rx_head_ptr_wr_req_data       (app_rx_head_ptr_wr_req_data    )
        ,.rx_head_ptr_app_wr_req_rdy        (rx_head_ptr_app_wr_req_rdy     )
                                                                            
        ,.app_rx_head_ptr_rd_req_val        (app_rx_head_ptr_rd_req_val     )
        ,.app_rx_head_ptr_rd_req_addr       (app_rx_head_ptr_rd_req_addr    )
        ,.rx_head_ptr_app_rd_req_rdy        (rx_head_ptr_app_rd_req_rdy     )
                                                                            
        ,.rx_head_ptr_app_rd_resp_val       (rx_head_ptr_app_rd_resp_val    )
        ,.rx_head_ptr_app_rd_resp_data      (rx_head_ptr_app_rd_resp_data   )
        ,.app_rx_head_ptr_rd_resp_rdy       (app_rx_head_ptr_rd_resp_rdy    )
                                                                            
        ,.app_rx_commit_ptr_rd_req_val      (app_rx_commit_ptr_rd_req_val   )
        ,.app_rx_commit_ptr_rd_req_addr     (app_rx_commit_ptr_rd_req_addr  )
        ,.rx_commit_ptr_app_rd_req_rdy      (rx_commit_ptr_app_rd_req_rdy   )
                                                                            
        ,.rx_commit_ptr_app_rd_resp_val     (rx_commit_ptr_app_rd_resp_val  )
        ,.rx_commit_ptr_app_rd_resp_data    (rx_commit_ptr_app_rd_resp_data )
        ,.app_rx_commit_ptr_rd_resp_rdy     (app_rx_commit_ptr_rd_resp_rdy  )
                                                                            
        ,.app_tx_head_ptr_rd_req_val        (app_tx_head_ptr_rd_req_val     )
        ,.app_tx_head_ptr_rd_req_addr       (app_tx_head_ptr_rd_req_addr    )
        ,.tx_head_ptr_app_rd_req_rdy        (tx_head_ptr_app_rd_req_rdy     )
                                                                            
        ,.tx_head_ptr_app_rd_resp_val       (tx_head_ptr_app_rd_resp_val    )
        ,.tx_head_ptr_app_rd_resp_addr      (tx_head_ptr_app_rd_resp_addr   )
        ,.tx_head_ptr_app_rd_resp_data      (tx_head_ptr_app_rd_resp_data   )
        ,.app_tx_head_ptr_rd_resp_rdy       (app_tx_head_ptr_rd_resp_rdy    )
                                                                            
        ,.app_tx_tail_ptr_wr_req_val        (app_tx_tail_ptr_wr_req_val     )
        ,.app_tx_tail_ptr_wr_req_addr       (app_tx_tail_ptr_wr_req_addr    )
        ,.app_tx_tail_ptr_wr_req_data       (app_tx_tail_ptr_wr_req_data    )
        ,.tx_tail_ptr_app_wr_req_rdy        (tx_tail_ptr_app_wr_req_rdy     )
                                                                            
        ,.app_sched_update_val              (app_sched_update_val           )
        ,.app_sched_update_cmd              (app_sched_update_cmd           )
        ,.sched_app_update_rdy              (sched_app_update_rdy           )
                                                                            
        ,.app_tx_tail_ptr_rd_req_val        (app_tx_tail_ptr_rd_req_val     )
        ,.app_tx_tail_ptr_rd_req_addr       (app_tx_tail_ptr_rd_req_addr    )
        ,.tx_tail_ptr_app_rd_req_rdy        (tx_tail_ptr_app_rd_req_rdy     )
                                                                            
        ,.tx_tail_ptr_app_rd_resp_val       (tx_tail_ptr_app_rd_resp_val    )
        ,.tx_tail_ptr_app_rd_resp_flowid    (tx_tail_ptr_app_rd_resp_flowid )
        ,.tx_tail_ptr_app_rd_resp_data      (tx_tail_ptr_app_rd_resp_data   )
        ,.app_tx_tail_ptr_rd_resp_rdy       (app_tx_tail_ptr_rd_resp_rdy    )
    );

endmodule
