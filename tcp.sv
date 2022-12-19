`include "packet_defs.vh"
module tcp 
import tcp_pkg::*;
import tcp_misc_pkg::*;
import packet_struct_pkg::*;
(
     input clk
    ,input rst

    ,input                                      src_tcp_rx_hdr_val
    ,output logic                               tcp_src_rx_hdr_rdy
    ,input          [`IP_ADDR_W-1:0]            src_tcp_rx_src_ip
    ,input          [`IP_ADDR_W-1:0]            src_tcp_rx_dst_ip
    ,input  tcp_pkt_hdr                         src_tcp_rx_tcp_hdr
    ,input  payload_buf_struct                  src_tcp_rx_payload_entry

    ,output logic                               tx_pkt_hdr_val
    ,output tcp_pkt_hdr                         tx_pkt_hdr
    ,output logic   [FLOWID_W-1:0]              tx_pkt_flowid
    ,output logic   [`IP_ADDR_W-1:0]            tx_pkt_src_ip_addr
    ,output logic   [`IP_ADDR_W-1:0]            tx_pkt_dst_ip_addr
    ,output payload_buf_struct                  tx_pkt_payload
    ,input  logic                               tx_pkt_hdr_rdy
   
    /********************************
     * RX copy to buffers
     *******************************/
    ,output logic                               tcp_rx_dst_hdr_val
    ,output logic   [FLOWID_W-1:0]              tcp_rx_dst_flowid
    ,output logic                               tcp_rx_dst_pkt_accept
    ,output payload_buf_struct                  tcp_rx_dst_payload_entry
    ,input  logic                               dst_tcp_rx_hdr_rdy

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
    ,output four_tuple_struct                   app_new_flow_entry
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
    
    ,input                                      app_tx_tail_ptr_rd_req_val
    ,input          [FLOWID_W-1:0]              app_tx_tail_ptr_rd_req_addr
    ,output logic                               tx_tail_ptr_app_rd_req_rdy
    
    ,output                                     tx_tail_ptr_app_rd_resp_val
    ,output logic   [FLOWID_W-1:0]              tx_tail_ptr_app_rd_resp_flowid
    ,output logic   [TX_PAYLOAD_PTR_W:0]        tx_tail_ptr_app_rd_resp_data
    ,input  logic                               app_tx_tail_ptr_rd_resp_rdy
    
    ,input  logic                               app_sched_update_val
    ,input  sched_cmd_struct                    app_sched_update_cmd
    ,output logic                               sched_app_update_rdy
    
);
    
    logic                           curr_rx_state_rd_req_val;
    logic   [FLOWID_W-1:0]          curr_rx_state_rd_req_addr;
    logic                           curr_rx_state_rd_req_rdy;
    
    logic                           curr_rx_state_rd_resp_val;
    smol_rx_state_struct            curr_rx_state_rd_resp_data;
    logic                           curr_rx_state_rd_resp_rdy;

    logic                           next_rx_state_wr_req_val;
    logic   [FLOWID_W-1:0]          next_rx_state_wr_req_addr;
    smol_rx_state_struct            next_rx_state_wr_req_data;
    logic                           next_rx_state_wr_req_rdy;
    
    logic                           curr_tx_state_rd_req_val;
    logic   [FLOWID_W-1:0]          curr_tx_state_rd_req_addr;
    logic                           curr_tx_state_rd_req_rdy;

    logic                           curr_tx_state_rd_resp_val;
    smol_tx_state_struct            curr_tx_state_rd_resp_data;
    logic                           curr_tx_state_rd_resp_rdy;
    
    logic                           new_flow_val;
    logic   [FLOWID_W-1:0]          new_flow_flow_id;
    four_tuple_struct               new_flow_lookup_entry;
    smol_tx_state_struct            new_flow_tx_state;
    smol_rx_state_struct            new_flow_rx_state;
    logic   [TX_PAYLOAD_PTR_W:0]    new_tx_head_ptr;
    logic   [TX_PAYLOAD_PTR_W:0]    new_tx_tail_ptr;
    logic                           new_flow_rdy;
    
    logic                           rx_pipe_rx_head_ptr_rd_req_val;
    logic   [FLOWID_W-1:0]          rx_pipe_rx_head_ptr_rd_req_addr;
    logic                           rx_head_ptr_rx_pipe_rd_req_rdy;

    logic                           rx_head_ptr_rx_pipe_rd_resp_val;
    logic   [RX_PAYLOAD_PTR_W:0]    rx_head_ptr_rx_pipe_rd_resp_data;
    logic                           rx_pipe_rx_head_ptr_rd_resp_rdy;
    
    logic                           rx_pipe_rx_tail_ptr_wr_req_val;
    logic   [FLOWID_W-1:0]          rx_pipe_rx_tail_ptr_wr_req_addr;
    logic   [RX_PAYLOAD_PTR_W:0]    rx_pipe_rx_tail_ptr_wr_req_data;
    logic                           rx_tail_ptr_rx_pipe_wr_req_rdy;

    logic                           rx_pipe_rx_tail_ptr_rd_req_val;
    logic   [FLOWID_W-1:0]          rx_pipe_rx_tail_ptr_rd_req_addr;
    logic                           rx_tail_ptr_rx_pipe_rd_req_rdy;

    logic                           rx_tail_ptr_rx_pipe_rd_resp_val;
    logic   [RX_PAYLOAD_PTR_W:0]    rx_tail_ptr_rx_pipe_rd_resp_data;
    logic                           rx_pipe_rx_tail_ptr_rd_resp_rdy;
    
    logic                           rx_pipe_tx_head_ptr_wr_req_val;
    logic   [FLOWID_W-1:0]          rx_pipe_tx_head_ptr_wr_req_addr;
    logic   [TX_PAYLOAD_PTR_W:0]    rx_pipe_tx_head_ptr_wr_req_data;
    logic                           tx_head_ptr_rx_pipe_wr_req_rdy;

    logic                           new_flow_rx_state_rdy;
    logic                           rx_state_wr_req_val;
    logic   [FLOWID_W-1:0]          rx_state_wr_req_addr;
    smol_rx_state_struct            rx_state_wr_req_data;
    logic                           rx_state_wr_req_rdy;

    logic                           new_flow_rx_payload_ptrs_rdy;
    
    logic                           new_flow_tx_state_rdy;
    logic                           tx_state_wr_req_val;
    logic   [FLOWID_W-1:0]          tx_state_wr_req_addr;
    smol_tx_state_struct            tx_state_wr_req_data;
    logic                           tx_state_wr_req_rdy;
    
    logic                           new_flow_tx_payload_ptrs_rdy;

    logic                           rx_send_pkt_mux_val;
    logic   [FLOWID_W-1:0]          rx_send_pkt_flowid;
    tcp_pkt_hdr                     rx_send_pkt_hdr;
    payload_buf_struct              rx_send_pkt_payload;
    logic   [`IP_ADDR_W-1:0]        rx_send_pkt_src_ip;
    logic   [`IP_ADDR_W-1:0]        rx_send_pkt_dst_ip;
    send_pkt_struct                 rx_send_pkt_mux_data;
    logic                           send_pkt_mux_rx_rdy;
    
    logic                           tx_send_pkt_mux_val;
    tcp_pkt_hdr                     tx_send_pkt_mux_hdr;
    payload_buf_struct              tx_send_pkt_mux_payload;
    logic   [`IP_ADDR_W-1:0]        tx_send_pkt_mux_src_ip;
    logic   [`IP_ADDR_W-1:0]        tx_send_pkt_mux_dst_ip;
    logic   [FLOWID_W-1:0]          tx_send_pkt_mux_flowid;
    send_pkt_struct                 tx_send_pkt_mux_data;
    logic                           send_pkt_mux_tx_rdy;

    send_pkt_struct                 tx_send_pkt_struct;

    logic                           tx_new_flow_rdy;
    
    logic                           sched_tx_req_val;
    sched_data_struct               sched_tx_req_data;
    logic                           tx_sched_req_rdy;

    logic                           tx_sched_update_val;
    sched_cmd_struct                tx_sched_update_cmd;
    logic                           sched_tx_update_rdy;
    
    logic                           rx_sched_update_val;
    sched_cmd_struct                rx_sched_update_cmd;
    logic                           sched_rx_update_rdy;
    
    logic                           tx_pipe_tx_tail_ptr_rd_req_val;
    logic   [FLOWID_W-1:0]          tx_pipe_tx_tail_ptr_rd_req_addr;
    logic                           tx_tail_ptr_tx_pipe_rd_req_rdy;
    
    logic                           tx_tail_ptr_tx_pipe_rd_resp_val;
    logic   [TX_PAYLOAD_PTR_W:0]    tx_tail_ptr_tx_pipe_rd_resp_data;
    logic                           tx_pipe_tx_tail_ptr_rd_resp_rdy;
    
    logic                           tx_pipe_rx_state_rd_req_val;
    logic   [FLOWID_W-1:0]          tx_pipe_rx_state_rd_req_addr;
    logic                           rx_state_tx_pipe_rd_req_rdy;

    logic                           rx_state_tx_pipe_rd_resp_val;
    smol_rx_state_struct            rx_state_tx_pipe_rd_resp_data;
    logic                           tx_pipe_rx_state_rd_resp_rdy;
    
    logic                           tx_pipe_tx_state_wr_req_val;
    logic   [FLOWID_W-1:0]          tx_pipe_tx_state_wr_req_addr;
    smol_tx_state_struct            tx_pipe_tx_state_wr_req_data;
    logic                           tx_state_tx_pipe_wr_req_rdy;
    
    logic                           tx_pipe_tx_state_rd_req_val;
    logic   [FLOWID_W-1:0]          tx_pipe_tx_state_rd_req_addr;
    logic                           tx_state_tx_pipe_rd_req_rdy;

    logic                           tx_state_tx_pipe_rd_resp_val;
    smol_tx_state_struct            tx_state_tx_pipe_rd_resp_data;
    logic                           tx_pipe_tx_state_rd_resp_rdy;

    assign new_flow_rdy = new_flow_rx_state_rdy & 
                        & new_flow_rx_payload_ptrs_rdy & new_flow_tx_state_rdy & new_flow_tx_payload_ptrs_rdy
                        & tx_new_flow_rdy;

    // tx mux
    always_comb begin
        rx_send_pkt_mux_data = '0;
        rx_send_pkt_mux_data.flowid = rx_send_pkt_flowid;
        rx_send_pkt_mux_data.pkt_hdr = rx_send_pkt_hdr;
        rx_send_pkt_mux_data.payload = '0;
        rx_send_pkt_mux_data.src_ip = rx_send_pkt_src_ip;
        rx_send_pkt_mux_data.dst_ip = rx_send_pkt_dst_ip;

        tx_send_pkt_mux_data = '0;
        tx_send_pkt_mux_data.pkt_hdr = tx_send_pkt_mux_hdr;
        tx_send_pkt_mux_data.flowid = tx_send_pkt_mux_flowid;
        tx_send_pkt_mux_data.payload = tx_send_pkt_mux_payload;
        tx_send_pkt_mux_data.src_ip = tx_send_pkt_mux_src_ip;
        tx_send_pkt_mux_data.dst_ip = tx_send_pkt_mux_dst_ip;
    end

    send_pkt_mux tx_mux (
         .clk   (clk)
        ,.rst   (rst)

        ,.src0_mux_val  (rx_send_pkt_mux_val    )
        ,.src0_mux_data (rx_send_pkt_mux_data   )
        ,.mux_src0_rdy  (send_pkt_mux_rx_rdy    )

        ,.src1_mux_val  (tx_send_pkt_mux_val    )
        ,.src1_mux_data (tx_send_pkt_mux_data   )
        ,.mux_src1_rdy  (send_pkt_mux_tx_rdy    )
    
        ,.mux_dst_val   (tx_pkt_hdr_val         )
        ,.mux_dst_data  (tx_send_pkt_struct     )
        ,.dst_mux_rdy   (tx_pkt_hdr_rdy         )
    );

    assign tx_pkt_src_ip_addr = tx_send_pkt_struct.src_ip;
    assign tx_pkt_dst_ip_addr = tx_send_pkt_struct.dst_ip;
    assign tx_pkt_payload = tx_send_pkt_struct.payload;
    assign tx_pkt_flowid = tx_send_pkt_struct.flowid;
    assign tx_pkt_hdr = tx_send_pkt_struct.pkt_hdr;

    tcp_rx rx_engine (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.recv_tcp_hdr_val                  (src_tcp_rx_hdr_val                 )
        ,.recv_src_ip                       (src_tcp_rx_src_ip                  )
        ,.recv_dst_ip                       (src_tcp_rx_dst_ip                  )
        ,.recv_tcp_hdr                      (src_tcp_rx_tcp_hdr                 )
        ,.recv_payload_entry                (src_tcp_rx_payload_entry           )
        ,.recv_hdr_rdy                      (tcp_src_rx_hdr_rdy                 )
    
        ,.tcp_rx_dst_hdr_val                (tcp_rx_dst_hdr_val                 )
        ,.tcp_rx_dst_flowid                 (tcp_rx_dst_flowid                  )
        ,.tcp_rx_dst_pkt_accept             (tcp_rx_dst_pkt_accept              )
        ,.tcp_rx_dst_payload_entry          (tcp_rx_dst_payload_entry           )
        ,.dst_tcp_rx_hdr_rdy                (dst_tcp_rx_hdr_rdy                 )
    
        ,.new_flow_val                      (new_flow_val                       )
        ,.new_flow_flow_id                  (new_flow_flow_id                   )
        ,.new_flow_lookup_entry             (new_flow_lookup_entry              )
        ,.new_flow_tx_state                 (new_flow_tx_state                  )
        ,.new_flow_rx_state                 (new_flow_rx_state                  )
        ,.new_tx_head_ptr                   (new_tx_head_ptr                    )
        ,.new_tx_tail_ptr                   (new_tx_tail_ptr                    )
        ,.new_flow_rdy                      (new_flow_rdy                       )
        
        ,.app_new_flow_notif_val            (app_new_flow_notif_val             )
        ,.app_new_flow_flowid               (app_new_flow_flowid                )
        ,.app_new_flow_entry                (app_new_flow_entry                 )
        ,.app_new_flow_notif_rdy            (app_new_flow_notif_rdy             )
        
        ,.curr_rx_state_rd_req_val          (curr_rx_state_rd_req_val           )
        ,.curr_rx_state_rd_req_addr         (curr_rx_state_rd_req_addr          )
        ,.curr_rx_state_rd_req_rdy          (curr_rx_state_rd_req_rdy           )
                                                                                
        ,.curr_rx_state_rd_resp_val         (curr_rx_state_rd_resp_val          )
        ,.curr_rx_state_rd_resp_data        (curr_rx_state_rd_resp_data         )
        ,.curr_rx_state_rd_resp_rdy         (curr_rx_state_rd_resp_rdy          )
                                                                                
        ,.next_rx_state_wr_req_val          (next_rx_state_wr_req_val           )
        ,.next_rx_state_wr_req_addr         (next_rx_state_wr_req_addr          )
        ,.next_rx_state_wr_req_data         (next_rx_state_wr_req_data          )
        ,.next_rx_state_wr_req_rdy          (next_rx_state_wr_req_rdy           )
    
        ,.curr_tx_state_rd_req_val          (curr_tx_state_rd_req_val           )
        ,.curr_tx_state_rd_req_addr         (curr_tx_state_rd_req_addr          )
        ,.curr_tx_state_rd_req_rdy          (curr_tx_state_rd_req_rdy           )
                                                                                
        ,.curr_tx_state_rd_resp_val         (curr_tx_state_rd_resp_val          )
        ,.curr_tx_state_rd_resp_data        (curr_tx_state_rd_resp_data         )
        ,.curr_tx_state_rd_resp_rdy         (curr_tx_state_rd_resp_rdy          )
        
        ,.rx_pipe_rx_head_ptr_rd_req_val    (rx_pipe_rx_head_ptr_rd_req_val     )
        ,.rx_pipe_rx_head_ptr_rd_req_addr   (rx_pipe_rx_head_ptr_rd_req_addr    )
        ,.rx_head_ptr_rx_pipe_rd_req_rdy    (rx_head_ptr_rx_pipe_rd_req_rdy     )
                                                                                
        ,.rx_head_ptr_rx_pipe_rd_resp_val   (rx_head_ptr_rx_pipe_rd_resp_val    )
        ,.rx_head_ptr_rx_pipe_rd_resp_data  (rx_head_ptr_rx_pipe_rd_resp_data   )
        ,.rx_pipe_rx_head_ptr_rd_resp_rdy   (rx_pipe_rx_head_ptr_rd_resp_rdy    )
                                                                                
        ,.rx_pipe_rx_tail_ptr_wr_req_val    (rx_pipe_rx_tail_ptr_wr_req_val     )
        ,.rx_pipe_rx_tail_ptr_wr_req_addr   (rx_pipe_rx_tail_ptr_wr_req_addr    )
        ,.rx_pipe_rx_tail_ptr_wr_req_data   (rx_pipe_rx_tail_ptr_wr_req_data    )
        ,.rx_tail_ptr_rx_pipe_wr_req_rdy    (rx_tail_ptr_rx_pipe_wr_req_rdy     )
                                                                                
        ,.rx_pipe_rx_tail_ptr_rd_req_val    (rx_pipe_rx_tail_ptr_rd_req_val     )
        ,.rx_pipe_rx_tail_ptr_rd_req_addr   (rx_pipe_rx_tail_ptr_rd_req_addr    )
        ,.rx_tail_ptr_rx_pipe_rd_req_rdy    (rx_tail_ptr_rx_pipe_rd_req_rdy     )
                                                                                
        ,.rx_tail_ptr_rx_pipe_rd_resp_val   (rx_tail_ptr_rx_pipe_rd_resp_val    )
        ,.rx_tail_ptr_rx_pipe_rd_resp_data  (rx_tail_ptr_rx_pipe_rd_resp_data   )
        ,.rx_pipe_rx_tail_ptr_rd_resp_rdy   (rx_pipe_rx_tail_ptr_rd_resp_rdy    )
        
        ,.rx_pipe_tx_head_ptr_wr_req_val    (rx_pipe_tx_head_ptr_wr_req_val     )
        ,.rx_pipe_tx_head_ptr_wr_req_addr   (rx_pipe_tx_head_ptr_wr_req_addr    )
        ,.rx_pipe_tx_head_ptr_wr_req_data   (rx_pipe_tx_head_ptr_wr_req_data    )
        ,.tx_head_ptr_rx_pipe_wr_req_rdy    (tx_head_ptr_rx_pipe_wr_req_rdy     )
    
        ,.rx_send_pkt_enq_req_val           (rx_send_pkt_mux_val                )
        ,.rx_send_pkt_enq_flowid            (rx_send_pkt_flowid                 )
        ,.rx_send_pkt_enq_pkt               (rx_send_pkt_hdr                    )
        ,.rx_send_pkt_enq_src_ip            (rx_send_pkt_src_ip                 )
        ,.rx_send_pkt_enq_dst_ip            (rx_send_pkt_dst_ip                 )
        ,.send_pkt_rx_enq_req_rdy           (send_pkt_mux_rx_rdy                )
    
        ,.rx_sched_update_val               (rx_sched_update_val                )
        ,.rx_sched_update_cmd               (rx_sched_update_cmd                )
        ,.sched_rx_update_rdy               (sched_rx_update_rdy                )
    );

    tcp_tx tx_engine (
         .clk   (clk    )
        ,.rst   (rst    )
        
        ,.sched_tx_req_val                      (sched_tx_req_val                   )
        ,.sched_tx_req_data                     (sched_tx_req_data                  )
        ,.tx_sched_req_rdy                      (tx_sched_req_rdy                   )
                                                                                    
        ,.tx_sched_update_val                   (tx_sched_update_val                )
        ,.tx_sched_update_cmd                   (tx_sched_update_cmd                )
        ,.sched_tx_update_rdy                   (sched_tx_update_rdy                )
    
        ,.tx_pipe_tx_tail_ptr_rd_req_val        (tx_pipe_tx_tail_ptr_rd_req_val     )
        ,.tx_pipe_tx_tail_ptr_rd_req_addr       (tx_pipe_tx_tail_ptr_rd_req_addr    )
        ,.tx_tail_ptr_tx_pipe_rd_req_rdy        (tx_tail_ptr_tx_pipe_rd_req_rdy     )
                                                                                    
        ,.tx_tail_ptr_tx_pipe_rd_resp_val       (tx_tail_ptr_tx_pipe_rd_resp_val    )
        ,.tx_tail_ptr_tx_pipe_rd_resp_data      (tx_tail_ptr_tx_pipe_rd_resp_data   )
        ,.tx_pipe_tx_tail_ptr_rd_resp_rdy       (tx_pipe_tx_tail_ptr_rd_resp_rdy    )
        
        ,.tx_pipe_rx_state_rd_req_val           (tx_pipe_rx_state_rd_req_val        )
        ,.tx_pipe_rx_state_rd_req_addr          (tx_pipe_rx_state_rd_req_addr       )
        ,.rx_state_tx_pipe_rd_req_rdy           (rx_state_tx_pipe_rd_req_rdy        )
                                                                                    
        ,.rx_state_tx_pipe_rd_resp_val          (rx_state_tx_pipe_rd_resp_val       )
        ,.rx_state_tx_pipe_rd_resp_data         (rx_state_tx_pipe_rd_resp_data      )
        ,.tx_pipe_rx_state_rd_resp_rdy          (tx_pipe_rx_state_rd_resp_rdy       )
        
        ,.tx_pipe_tx_state_rd_req_val           (tx_pipe_tx_state_rd_req_val        )
        ,.tx_pipe_tx_state_rd_req_addr          (tx_pipe_tx_state_rd_req_addr       )
        ,.tx_state_tx_pipe_rd_req_rdy           (tx_state_tx_pipe_rd_req_rdy        )
                                                                                    
        ,.tx_state_tx_pipe_rd_resp_val          (tx_state_tx_pipe_rd_resp_val       )
        ,.tx_state_tx_pipe_rd_resp_data         (tx_state_tx_pipe_rd_resp_data      )
        ,.tx_pipe_tx_state_rd_resp_rdy          (tx_pipe_tx_state_rd_resp_rdy       )
                                                                                    
        ,.tx_pipe_tx_state_wr_req_val           (tx_pipe_tx_state_wr_req_val        )
        ,.tx_pipe_tx_state_wr_req_addr          (tx_pipe_tx_state_wr_req_addr       )
        ,.tx_pipe_tx_state_wr_req_data          (tx_pipe_tx_state_wr_req_data       )
        ,.tx_state_tx_pipe_wr_req_rdy           (tx_state_tx_pipe_wr_req_rdy        )
    
        ,.tx_pkt_hdr_val                        (tx_send_pkt_mux_val                )
        ,.tx_pkt_hdr                            (tx_send_pkt_mux_hdr                )
        ,.tx_pkt_flowid                         (tx_send_pkt_mux_flowid             )
        ,.tx_pkt_src_ip_addr                    (tx_send_pkt_mux_src_ip             )
        ,.tx_pkt_dst_ip_addr                    (tx_send_pkt_mux_dst_ip             )
        ,.tx_pkt_payload                        (tx_send_pkt_mux_payload            )
        ,.tx_pkt_hdr_rdy                        (send_pkt_mux_tx_rdy                )
        
        ,.new_flow_val                          (new_flow_val                       )
        ,.new_flow_flow_id                      (new_flow_flow_id                   )
        ,.new_flow_lookup_entry                 (new_flow_lookup_entry              )
        ,.new_flow_rx_state                     (new_flow_rx_state                  )
        ,.tx_new_flow_rdy                       (tx_new_flow_rdy                    )
    );

/************************************************
 * Scheduler
 ***********************************************/

    rr_sched_engine tx_scheduler (
         .clk   (clk    )
        ,.rst   (rst    )
        
        ,.app_sched_update_val  (app_sched_update_val   )
        ,.app_sched_update_cmd  (app_sched_update_cmd   )
        ,.sched_app_update_rdy  (sched_app_update_rdy   )
    
        ,.rx_sched_update_val   (rx_sched_update_val    )
        ,.rx_sched_update_cmd   (rx_sched_update_cmd    )
        ,.sched_rx_update_rdy   (sched_rx_update_rdy    )
        
        ,.tx_sched_update_val   (tx_sched_update_val    )
        ,.tx_sched_update_cmd   (tx_sched_update_cmd    )
        ,.sched_tx_update_rdy   (sched_tx_update_rdy    )
    
        ,.sched_tx_req_val      (sched_tx_req_val       )
        ,.sched_tx_req_data     (sched_tx_req_data      )
        ,.tx_sched_req_rdy      (tx_sched_req_rdy       )
    
        ,.new_flow_val          (new_flow_val           )
        ,.new_flow_flowid       (new_flow_flow_id       )
    );

/************************************************
 * State stores
 ***********************************************/

    new_state_mux #(
        .DATA_W (SMOL_RX_STATE_STRUCT_W + FLOWID_W   )
    ) rx_wr_state_mux (
         .new_state_val     (new_flow_val               )
        ,.new_state_data    ({new_flow_rx_state, new_flow_flow_id}  )
        ,.new_state_rdy     (new_flow_rx_state_rdy      )

        ,.update_state_val  (next_rx_state_wr_req_val   )
        ,.update_state_data ({next_rx_state_wr_req_data, next_rx_state_wr_req_addr})
        ,.update_state_rdy  (next_rx_state_wr_req_rdy   )
    
        ,.wr_state_val      (rx_state_wr_req_val        )
        ,.wr_state_data     ({rx_state_wr_req_data, rx_state_wr_req_addr})
        ,.wr_state_rdy      (rx_state_wr_req_rdy        )
    );
    

    ram_2r1w_sync_backpressure #(
         .width_p   (SMOL_RX_STATE_STRUCT_W )
        ,.els_p     (MAX_FLOW_CNT           )
    ) rx_state_store (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.wr_req_val    (rx_state_wr_req_val            )
        ,.wr_req_addr   (rx_state_wr_req_addr           )
        ,.wr_req_data   (rx_state_wr_req_data           )
        ,.wr_req_rdy    (rx_state_wr_req_rdy            )
    
        ,.rd0_req_val   (curr_rx_state_rd_req_val       )
        ,.rd0_req_addr  (curr_rx_state_rd_req_addr      )
        ,.rd0_req_rdy   (curr_rx_state_rd_req_rdy       )
    
        ,.rd0_resp_val  (curr_rx_state_rd_resp_val      )
        ,.rd0_resp_addr ()
        ,.rd0_resp_data (curr_rx_state_rd_resp_data     )
        ,.rd0_resp_rdy  (curr_rx_state_rd_resp_rdy      )
        
        ,.rd1_req_val   (tx_pipe_rx_state_rd_req_val    )
        ,.rd1_req_addr  (tx_pipe_rx_state_rd_req_addr   )
        ,.rd1_req_rdy   (rx_state_tx_pipe_rd_req_rdy    )
    
        ,.rd1_resp_val  (rx_state_tx_pipe_rd_resp_val   )
        ,.rd1_resp_addr ()
        ,.rd1_resp_data (rx_state_tx_pipe_rd_resp_data  )
        ,.rd1_resp_rdy  (tx_pipe_rx_state_rd_resp_rdy   )
    );


    new_state_mux #(
        .DATA_W (SMOL_TX_STATE_STRUCT_W + FLOWID_W   )
    ) tx_state_mux (
         .new_state_val     (new_flow_val           )
        ,.new_state_data    ({new_flow_tx_state, new_flow_flow_id}  )
        ,.new_state_rdy     (new_flow_tx_state_rdy  )

        ,.update_state_val  (tx_pipe_tx_state_wr_req_val    )
        ,.update_state_data ({tx_pipe_tx_state_wr_req_data, tx_pipe_tx_state_wr_req_addr}   )
        ,.update_state_rdy  (tx_state_tx_pipe_wr_req_rdy    )
    
        ,.wr_state_val      (tx_state_wr_req_val    )
        ,.wr_state_data     ({tx_state_wr_req_data, tx_state_wr_req_addr}   )
        ,.wr_state_rdy      (tx_state_wr_req_rdy    )
    );
    
    ram_2r1w_sync_backpressure #(
         .width_p   (SMOL_TX_STATE_STRUCT_W )
        ,.els_p     (MAX_FLOW_CNT           )
    ) tx_state_store (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.wr_req_val    (tx_state_wr_req_val            )
        ,.wr_req_addr   (tx_state_wr_req_addr           )
        ,.wr_req_data   (tx_state_wr_req_data           )
        ,.wr_req_rdy    (tx_state_wr_req_rdy            )
    
        ,.rd0_req_val   (tx_pipe_tx_state_rd_req_val    )
        ,.rd0_req_addr  (tx_pipe_tx_state_rd_req_addr   )
        ,.rd0_req_rdy   (tx_state_tx_pipe_rd_req_rdy    )
    
        ,.rd0_resp_val  (tx_state_tx_pipe_rd_resp_val   )
        ,.rd0_resp_addr ()
        ,.rd0_resp_data (tx_state_tx_pipe_rd_resp_data  )
        ,.rd0_resp_rdy  (tx_pipe_tx_state_rd_resp_rdy   )
        
        ,.rd1_req_val   (curr_tx_state_rd_req_val       )
        ,.rd1_req_addr  (curr_tx_state_rd_req_addr      )
        ,.rd1_req_rdy   (curr_tx_state_rd_req_rdy       )
    
        ,.rd1_resp_val  (curr_tx_state_rd_resp_val      )
        ,.rd1_resp_addr ()
        ,.rd1_resp_data (curr_tx_state_rd_resp_data     )
        ,.rd1_resp_rdy  (curr_tx_state_rd_resp_rdy      )
    );

    rx_buf_ptrs rx_ptrs ( 
         .clk   (clk    )
        ,.rst   (rst    )
        
        ,.head_ptr_wr_req_val           (app_rx_head_ptr_wr_req_val         )
        ,.head_ptr_wr_req_addr          (app_rx_head_ptr_wr_req_addr        )
        ,.head_ptr_wr_req_data          (app_rx_head_ptr_wr_req_data        )
        ,.head_ptr_wr_req_rdy           (rx_head_ptr_app_wr_req_rdy         )
    
        ,.head_ptr_rd0_req_val          (app_rx_head_ptr_rd_req_val         )
        ,.head_ptr_rd0_req_addr         (app_rx_head_ptr_rd_req_addr        )
        ,.head_ptr_rd0_req_rdy          (rx_head_ptr_app_rd_req_rdy         )
    
        ,.head_ptr_rd0_resp_val         (rx_head_ptr_app_rd_resp_val        )
        ,.head_ptr_rd0_resp_data        (rx_head_ptr_app_rd_resp_data       )
        ,.head_ptr_rd0_resp_rdy         (app_rx_head_ptr_rd_resp_rdy        )
        
        ,.head_ptr_rd1_req_val          (rx_pipe_rx_head_ptr_rd_req_val     )
        ,.head_ptr_rd1_req_addr         (rx_pipe_rx_head_ptr_rd_req_addr    )
        ,.head_ptr_rd1_req_rdy          (rx_head_ptr_rx_pipe_rd_req_rdy     )
    
        ,.head_ptr_rd1_resp_val         (rx_head_ptr_rx_pipe_rd_resp_val    )
        ,.head_ptr_rd1_resp_data        (rx_head_ptr_rx_pipe_rd_resp_data   )
        ,.head_ptr_rd1_resp_rdy         (rx_pipe_rx_head_ptr_rd_resp_rdy    )
        
        ,.commit_ptr_wr_req_val         (store_buf_commit_ptr_wr_req_val    )
        ,.commit_ptr_wr_req_addr        (store_buf_commit_ptr_wr_req_addr   )
        ,.commit_ptr_wr_req_data        (store_buf_commit_ptr_wr_req_data   )
        ,.commit_ptr_wr_req_rdy         (commit_ptr_store_buf_wr_req_rdy    )
    
        ,.commit_ptr_rd0_req_val        (store_buf_commit_ptr_rd_req_val    )
        ,.commit_ptr_rd0_req_addr       (store_buf_commit_ptr_rd_req_addr   )
        ,.commit_ptr_rd0_req_rdy        (commit_ptr_store_buf_rd_req_rdy    )
    
        ,.commit_ptr_rd0_resp_val       (commit_ptr_store_buf_rd_resp_val   )
        ,.commit_ptr_rd0_resp_data      (commit_ptr_store_buf_rd_resp_data  )
        ,.commit_ptr_rd0_resp_rdy       (store_buf_commit_ptr_rd_resp_rdy   )
        
        ,.commit_ptr_rd1_req_val        (app_rx_commit_ptr_rd_req_val       )
        ,.commit_ptr_rd1_req_addr       (app_rx_commit_ptr_rd_req_addr      )
        ,.commit_ptr_rd1_req_rdy        (rx_commit_ptr_app_rd_req_rdy       )
    
        ,.commit_ptr_rd1_resp_val       (rx_commit_ptr_app_rd_resp_val      )
        ,.commit_ptr_rd1_resp_data      (rx_commit_ptr_app_rd_resp_data     )
        ,.commit_ptr_rd1_resp_rdy       (app_rx_commit_ptr_rd_resp_rdy      )
        
        ,.tail_ptr_wr_req_val           (rx_pipe_rx_tail_ptr_wr_req_val     )
        ,.tail_ptr_wr_req_addr          (rx_pipe_rx_tail_ptr_wr_req_addr    )
        ,.tail_ptr_wr_req_data          (rx_pipe_rx_tail_ptr_wr_req_data    )
        ,.tail_ptr_wr_req_rdy           (rx_tail_ptr_rx_pipe_wr_req_rdy     )
    
        ,.tail_ptr_rd_req_val           (rx_pipe_rx_tail_ptr_rd_req_val     )
        ,.tail_ptr_rd_req_addr          (rx_pipe_rx_tail_ptr_rd_req_addr    )
        ,.tail_ptr_rd_req_rdy           (rx_tail_ptr_rx_pipe_rd_req_rdy     )
    
        ,.tail_ptr_rd_resp_val          (rx_tail_ptr_rx_pipe_rd_resp_val    )
        ,.tail_ptr_rd_resp_data         (rx_tail_ptr_rx_pipe_rd_resp_data   )
        ,.tail_ptr_rd_resp_rdy          (rx_pipe_rx_tail_ptr_rd_resp_rdy    )
    
        ,.new_flow_val                  (new_flow_val                       )
        ,.new_flow_flowid               (new_flow_flow_id                   )
        ,.new_rx_head_ptr               ('0)
        ,.new_rx_tail_ptr               ('0)
        ,.new_flow_rx_payload_ptrs_rdy  (new_flow_rx_payload_ptrs_rdy       )
    );

    tx_buf_ptrs tx_payload_qs (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.head_ptr_rd_req0_val      (app_tx_head_ptr_rd_req_val         )
        ,.head_ptr_rd_req0_addr     (app_tx_head_ptr_rd_req_addr        )
        ,.head_ptr_rd_req0_rdy      (tx_head_ptr_app_rd_req_rdy         )
    
        ,.head_ptr_rd_resp0_val     (tx_head_ptr_app_rd_resp_val        )
        ,.head_ptr_rd_resp0_addr    (tx_head_ptr_app_rd_resp_addr       )
        ,.head_ptr_rd_resp0_data    (tx_head_ptr_app_rd_resp_data       )
        ,.head_ptr_rd_resp0_rdy     (app_tx_head_ptr_rd_resp_rdy        )
        
        ,.head_ptr_rd_req1_val      (1'b0)
        ,.head_ptr_rd_req1_addr     ('0)
        ,.head_ptr_rd_req1_rdy      ()
    
        ,.head_ptr_rd_resp1_val     ()
        ,.head_ptr_rd_resp1_addr    ()
        ,.head_ptr_rd_resp1_data    ()
        ,.head_ptr_rd_resp1_rdy     (1'b1)
    
        ,.head_ptr_wr_req_val       (rx_pipe_tx_head_ptr_wr_req_val     )
        ,.head_ptr_wr_req_addr      (rx_pipe_tx_head_ptr_wr_req_addr    )
        ,.head_ptr_wr_req_data      (rx_pipe_tx_head_ptr_wr_req_data    )
        ,.head_ptr_wr_req_rdy       (tx_head_ptr_rx_pipe_wr_req_rdy     )
        
        ,.tail_ptr_rd_req0_val      (tx_pipe_tx_tail_ptr_rd_req_val     )
        ,.tail_ptr_rd_req0_addr     (tx_pipe_tx_tail_ptr_rd_req_addr    )
        ,.tail_ptr_rd_req0_rdy      (tx_tail_ptr_tx_pipe_rd_req_rdy     )
    
        ,.tail_ptr_rd_resp0_val     (tx_tail_ptr_tx_pipe_rd_resp_val    )
        ,.tail_ptr_rd_resp0_addr    ()
        ,.tail_ptr_rd_resp0_data    (tx_tail_ptr_tx_pipe_rd_resp_data   )
        ,.tail_ptr_rd_resp0_rdy     (tx_pipe_tx_tail_ptr_rd_resp_rdy    )
        
        ,.tail_ptr_rd_req1_val      (app_tx_tail_ptr_rd_req_val         )
        ,.tail_ptr_rd_req1_addr     (app_tx_tail_ptr_rd_req_addr        )
        ,.tail_ptr_rd_req1_rdy      (tx_tail_ptr_app_rd_req_rdy         )
    
        ,.tail_ptr_rd_resp1_val     (tx_tail_ptr_app_rd_resp_val        )
        ,.tail_ptr_rd_resp1_addr    (tx_tail_ptr_app_rd_resp_flowid     )
        ,.tail_ptr_rd_resp1_data    (tx_tail_ptr_app_rd_resp_data       )
        ,.tail_ptr_rd_resp1_rdy     (app_tx_tail_ptr_rd_resp_rdy        )
    
        ,.tail_ptr_wr_req_val       (app_tx_tail_ptr_wr_req_val         )
        ,.tail_ptr_wr_req_addr      (app_tx_tail_ptr_wr_req_addr        )
        ,.tail_ptr_wr_req_data      (app_tx_tail_ptr_wr_req_data        )
        ,.tail_ptr_wr_req_rdy       (tx_tail_ptr_app_wr_req_rdy         )
    
        ,.new_flow_val              (new_flow_val                       )
        ,.new_flow_flowid           (new_flow_flow_id                   )
        ,.new_flow_head_ptr         (new_tx_head_ptr                    )
        ,.new_flow_tail_ptr         (new_tx_tail_ptr                    )
        ,.new_flow_rdy              (new_flow_tx_payload_ptrs_rdy       )
    );

endmodule
