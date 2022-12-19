`include "packet_defs.vh"
module tcp_rx 
import tcp_pkg::*;
import tcp_misc_pkg::*;
import packet_struct_pkg::*;
(
     input clk
    ,input rst

    ,input  logic   [`IP_ADDR_W-1:0]        recv_src_ip
    ,input  logic   [`IP_ADDR_W-1:0]        recv_dst_ip
    ,input  logic                           recv_tcp_hdr_val
    ,input  tcp_pkt_hdr                     recv_tcp_hdr
    ,input  payload_buf_struct              recv_payload_entry
    ,output logic                           recv_hdr_rdy
    
    ,output logic                           tcp_rx_dst_hdr_val
    ,output logic   [FLOWID_W-1:0]          tcp_rx_dst_flowid
    ,output logic                           tcp_rx_dst_pkt_accept
    ,output payload_buf_struct              tcp_rx_dst_payload_entry
    ,input  logic                           dst_tcp_rx_hdr_rdy

    ,output logic                           new_flow_val
    ,output logic   [FLOWID_W-1:0]          new_flow_flow_id
    ,output four_tuple_struct               new_flow_lookup_entry
    ,output smol_tx_state_struct            new_flow_tx_state
    ,output smol_rx_state_struct            new_flow_rx_state
    ,output logic   [TX_PAYLOAD_PTR_W:0]    new_tx_head_ptr
    ,output logic   [TX_PAYLOAD_PTR_W:0]    new_tx_tail_ptr
    ,input  logic                           new_flow_rdy
    
    ,output logic                           app_new_flow_notif_val
    ,output logic   [FLOWID_W-1:0]          app_new_flow_flowid
    ,output four_tuple_struct               app_new_flow_entry
    ,input  logic                           app_new_flow_notif_rdy
    
    ,output logic                           curr_rx_state_rd_req_val
    ,output logic   [FLOWID_W-1:0]          curr_rx_state_rd_req_addr
    ,input  logic                           curr_rx_state_rd_req_rdy
    
    ,input  logic                           curr_rx_state_rd_resp_val
    ,input  smol_rx_state_struct            curr_rx_state_rd_resp_data
    ,output logic                           curr_rx_state_rd_resp_rdy

    ,output logic                           next_rx_state_wr_req_val
    ,output logic   [FLOWID_W-1:0]          next_rx_state_wr_req_addr
    ,output smol_rx_state_struct            next_rx_state_wr_req_data
    ,input  logic                           next_rx_state_wr_req_rdy

    ,output logic                           curr_tx_state_rd_req_val
    ,output logic   [FLOWID_W-1:0]          curr_tx_state_rd_req_addr
    ,input  logic                           curr_tx_state_rd_req_rdy

    ,input  logic                           curr_tx_state_rd_resp_val
    ,input  smol_tx_state_struct            curr_tx_state_rd_resp_data
    ,output logic                           curr_tx_state_rd_resp_rdy
    
    ,output logic                           rx_pipe_rx_head_ptr_rd_req_val
    ,output logic   [FLOWID_W-1:0]          rx_pipe_rx_head_ptr_rd_req_addr
    ,input  logic                           rx_head_ptr_rx_pipe_rd_req_rdy

    ,input  logic                           rx_head_ptr_rx_pipe_rd_resp_val
    ,input  logic   [RX_PAYLOAD_PTR_W:0]    rx_head_ptr_rx_pipe_rd_resp_data
    ,output logic                           rx_pipe_rx_head_ptr_rd_resp_rdy
    
    ,output logic                           rx_pipe_rx_tail_ptr_wr_req_val
    ,output logic   [FLOWID_W-1:0]          rx_pipe_rx_tail_ptr_wr_req_addr
    ,output logic   [RX_PAYLOAD_PTR_W:0]    rx_pipe_rx_tail_ptr_wr_req_data
    ,input  logic                           rx_tail_ptr_rx_pipe_wr_req_rdy

    ,output logic                           rx_pipe_rx_tail_ptr_rd_req_val
    ,output logic   [FLOWID_W-1:0]          rx_pipe_rx_tail_ptr_rd_req_addr
    ,input  logic                           rx_tail_ptr_rx_pipe_rd_req_rdy

    ,input  logic                           rx_tail_ptr_rx_pipe_rd_resp_val
    ,input  logic   [RX_PAYLOAD_PTR_W:0]    rx_tail_ptr_rx_pipe_rd_resp_data
    ,output logic                           rx_pipe_rx_tail_ptr_rd_resp_rdy
    
    ,output                                 rx_pipe_tx_head_ptr_wr_req_val
    ,output         [FLOWID_W-1:0]          rx_pipe_tx_head_ptr_wr_req_addr
    ,output         [TX_PAYLOAD_PTR_W:0]    rx_pipe_tx_head_ptr_wr_req_data
    ,input                                  tx_head_ptr_rx_pipe_wr_req_rdy

    ,output logic                           rx_send_pkt_enq_req_val
    ,output logic   [FLOWID_W-1:0]          rx_send_pkt_enq_flowid
    ,output tcp_pkt_hdr                     rx_send_pkt_enq_pkt
    ,output logic   [`IP_ADDR_W-1:0]        rx_send_pkt_enq_src_ip
    ,output logic   [`IP_ADDR_W-1:0]        rx_send_pkt_enq_dst_ip
    ,input                                  send_pkt_rx_enq_req_rdy

    ,output logic                           rx_sched_update_val
    ,output sched_cmd_struct                rx_sched_update_cmd
    ,input  logic                           sched_rx_update_rdy
);
    
    logic                           read_flow_cam_val;
    logic                           read_flow_cam_hit;
    logic   [FLOWID_W-1:0]          read_flow_cam_flowid;
    four_tuple_struct               read_flow_cam_tag;
    
    logic                           ctrl_datap_save_input;
    logic                           ctrl_datap_save_flow_state;
    logic                           ctrl_datap_save_calcs;
    
    logic                       slow_path_val;
    tcp_pkt_hdr                 slow_path_pkt;
    logic                       slow_path_rdy;

    logic                       slow_path_done_val;
    logic                       drop_pkt;
    logic                       slow_path_done_rdy;
    
    logic                       flowid_manager_req;
    logic                       flowid_avail;

    logic                       store_flowid_cam;
    logic                       slow_path_store_flowid;
    
    logic   [FLOWID_W-1:0]      flowid_manager_flowid;

    tcp_rx_new_flow_ctrl new_flow_ctrl (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.slow_path_val                     (slow_path_val              )
        ,.slow_path_pkt                     (slow_path_pkt              )
        ,.slow_path_rdy                     (slow_path_rdy              )
                                                                        
        ,.slow_path_done_val                (slow_path_done_val         )
        ,.drop_pkt                          (drop_pkt                   )
        ,.slow_path_done_rdy                (slow_path_done_rdy         )
    
        ,.flowid_manager_req                (flowid_manager_req         )
        ,.flowid_avail                      (flowid_avail               )
        
        ,.slow_path_send_pkt_enqueue_val    (rx_send_pkt_enq_req_val    )
        ,.slow_path_send_pkt_enqueue_rdy    (send_pkt_rx_enq_req_rdy    )
    
        ,.init_state_val                    (new_flow_val               )
        ,.init_state_rdy                    (new_flow_rdy               )
    
        ,.app_flow_notif_val                (app_new_flow_notif_val     )
        ,.app_flow_notif_rdy                (app_new_flow_notif_rdy     )
    
        ,.slow_path_store_flowid            (slow_path_store_flowid     )
    );

    tcp_rx_ctrl ctrl (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.rx_tcp_hdr_val                    (recv_tcp_hdr_val                   )
        ,.rx_hdr_rdy                        (recv_hdr_rdy                       )

        ,.tcp_rx_dst_hdr_val                (tcp_rx_dst_hdr_val                 )
        ,.dst_tcp_rx_hdr_rdy                (dst_tcp_rx_hdr_rdy                 )
    
        ,.read_flow_cam_val                 (read_flow_cam_val                  )
        ,.read_flow_cam_hit                 (read_flow_cam_hit                  )
    
        ,.curr_rx_state_rd_req_val          (curr_rx_state_rd_req_val           )
        ,.curr_rx_state_rd_req_rdy          (curr_rx_state_rd_req_rdy           )
        
        ,.curr_rx_state_rd_resp_val         (curr_rx_state_rd_resp_val          )
        ,.curr_rx_state_rd_resp_rdy         (curr_rx_state_rd_resp_rdy          )
    
        ,.next_rx_state_wr_req_val          (next_rx_state_wr_req_val           )
        ,.next_rx_state_wr_req_rdy          (next_rx_state_wr_req_rdy           )
    
        ,.curr_tx_state_rd_req_val          (curr_tx_state_rd_req_val           )
        ,.curr_tx_state_rd_req_rdy          (curr_tx_state_rd_req_rdy           )
    
        ,.curr_tx_state_rd_resp_val         (curr_tx_state_rd_resp_val          )
        ,.curr_tx_state_rd_resp_rdy         (curr_tx_state_rd_resp_rdy          )
        
        ,.rx_pipe_rx_head_ptr_rd_req_val    (rx_pipe_rx_head_ptr_rd_req_val     )
        ,.rx_head_ptr_rx_pipe_rd_req_rdy    (rx_head_ptr_rx_pipe_rd_req_rdy     )
    
        ,.rx_head_ptr_rx_pipe_rd_resp_val   (rx_head_ptr_rx_pipe_rd_resp_val    )
        ,.rx_pipe_rx_head_ptr_rd_resp_rdy   (rx_pipe_rx_head_ptr_rd_resp_rdy    )
        
        ,.rx_pipe_rx_tail_ptr_wr_req_val    (rx_pipe_rx_tail_ptr_wr_req_val     )
        ,.rx_tail_ptr_rx_pipe_wr_req_rdy    (rx_tail_ptr_rx_pipe_wr_req_rdy     )
    
        ,.rx_pipe_rx_tail_ptr_rd_req_val    (rx_pipe_rx_tail_ptr_rd_req_val     )
        ,.rx_tail_ptr_rx_pipe_rd_req_rdy    (rx_tail_ptr_rx_pipe_rd_req_rdy     )
    
        ,.rx_tail_ptr_rx_pipe_rd_resp_val   (rx_tail_ptr_rx_pipe_rd_resp_val    )
        ,.rx_pipe_rx_tail_ptr_rd_resp_rdy   (rx_pipe_rx_tail_ptr_rd_resp_rdy    )
        
        ,.rx_pipe_tx_head_ptr_wr_req_val    (rx_pipe_tx_head_ptr_wr_req_val     )
        ,.tx_head_ptr_rx_pipe_wr_req_rdy    (tx_head_ptr_rx_pipe_wr_req_rdy     )
    
        ,.ctrl_datap_save_input             (ctrl_datap_save_input              )
        ,.ctrl_datap_save_flow_state        (ctrl_datap_save_flow_state         )
        ,.ctrl_datap_save_calcs             (ctrl_datap_save_calcs              )

        ,.rx_sched_update_val               (rx_sched_update_val                )
        ,.sched_rx_update_rdy               (sched_rx_update_rdy                )

        ,.store_flowid_cam                  (store_flowid_cam                   )
    
        ,.slow_path_val                     (slow_path_val                      )
        ,.slow_path_rdy                     (slow_path_rdy                      )
    
        ,.slow_path_done_val                (slow_path_done_val                 )
        ,.slow_path_done_rdy                (slow_path_done_rdy                 )
    );
    
    flowid_manager flowid_manager (
         .clk   (clk)
        ,.rst   (rst)

        ,.flowid_ret_val    (1'b0)
        ,.flowid_ret_id     ('0)
        ,.flowid_ret_rdy    ()

        ,.flowid_req        (flowid_manager_req     )
        ,.flowid_avail      (flowid_avail           )
        ,.flowid            (flowid_manager_flowid  )
    );

    tcp_rx_datap datap (
         .clk   (clk    )
        ,.rst   (rst    )
        
        ,.rx_src_ip                         (recv_src_ip                        )
        ,.rx_dst_ip                         (recv_dst_ip                        )
        ,.rx_tcp_hdr                        (recv_tcp_hdr                       )
        ,.rx_payload_entry                  (recv_payload_entry                 )
    
        ,.tcp_rx_dst_flowid                 (tcp_rx_dst_flowid                  )
        ,.tcp_rx_dst_pkt_accept             (tcp_rx_dst_pkt_accept              )
        ,.tcp_rx_dst_payload_entry          (tcp_rx_dst_payload_entry           )
    
        ,.read_flow_cam_tag                 (read_flow_cam_tag                  )
        ,.read_flow_cam_flowid              (read_flow_cam_flowid               )
    
        ,.flowid_manager_flowid             (flowid_manager_flowid              )
        
        ,.curr_rx_state_rd_req_addr         (curr_rx_state_rd_req_addr          )
        
        ,.curr_rx_state_rd_resp_data        (curr_rx_state_rd_resp_data         )
    
        ,.next_rx_state_wr_req_addr         (next_rx_state_wr_req_addr          )
        ,.next_rx_state_wr_req_data         (next_rx_state_wr_req_data          )
    
        ,.curr_tx_state_rd_req_addr         (curr_tx_state_rd_req_addr          )
    
        ,.curr_tx_state_rd_resp_data        (curr_tx_state_rd_resp_data         )
        
        ,.rx_pipe_rx_head_ptr_rd_req_addr   (rx_pipe_rx_head_ptr_rd_req_addr    )
    
        ,.rx_head_ptr_rx_pipe_rd_resp_data  (rx_head_ptr_rx_pipe_rd_resp_data   )
        
        ,.rx_pipe_rx_tail_ptr_wr_req_addr   (rx_pipe_rx_tail_ptr_wr_req_addr    )
        ,.rx_pipe_rx_tail_ptr_wr_req_data   (rx_pipe_rx_tail_ptr_wr_req_data    )
    
        ,.rx_pipe_rx_tail_ptr_rd_req_addr   (rx_pipe_rx_tail_ptr_rd_req_addr    )
    
        ,.rx_tail_ptr_rx_pipe_rd_resp_data  (rx_tail_ptr_rx_pipe_rd_resp_data   )
        
        ,.rx_pipe_tx_head_ptr_wr_req_addr   (rx_pipe_tx_head_ptr_wr_req_addr    )
        ,.rx_pipe_tx_head_ptr_wr_req_data   (rx_pipe_tx_head_ptr_wr_req_data    )
    
        ,.new_flow_flowid                   (new_flow_flow_id                   )
        ,.new_flow_lookup_entry             (new_flow_lookup_entry              )
        ,.new_flow_tx_state                 (new_flow_tx_state                  )
        ,.new_flow_rx_state                 (new_flow_rx_state                  )
        ,.new_tx_head_ptr                   (new_tx_head_ptr                    )
        ,.new_tx_tail_ptr                   (new_tx_tail_ptr                    )
        
        ,.app_new_flow_flowid               (app_new_flow_flowid                )
        ,.app_new_flow_entry                (app_new_flow_entry                 )
                                                                                
        ,.ctrl_datap_save_input             (ctrl_datap_save_input              )
        ,.ctrl_datap_save_flow_state        (ctrl_datap_save_flow_state         )
        ,.ctrl_datap_save_calcs             (ctrl_datap_save_calcs              )

        ,.rx_sched_update_cmd               (rx_sched_update_cmd                )

        ,.store_flowid_cam                  (store_flowid_cam                   )
        ,.store_flowid_manager              (slow_path_store_flowid             )

        ,.datap_slow_path_pkt               (slow_path_pkt                      )
                                                                                
        ,.slow_path_send_pkt_enqueue_pkt    (rx_send_pkt_enq_pkt                )
        ,.slow_path_send_pkt_enqueue_flowid (rx_send_pkt_enq_flowid             )
        ,.slow_path_send_pkt_enqueue_src_ip (rx_send_pkt_enq_src_ip             )
        ,.slow_path_send_pkt_enqueue_dst_ip (rx_send_pkt_enq_dst_ip             )
    );

    logic   [MAX_FLOW_CNT-1:0] cam_wr_val;
    assign cam_wr_val = {{(FLOWID_W-1){1'b0}}, new_flow_val} << new_flow_flow_id;
    
    bsg_cam_1r1w_unmanaged #(
         .els_p         (MAX_FLOW_CNT           )  
        ,.tag_width_p   (FOUR_TUPLE_STRUCT_W    )
        ,.data_width_p  (FLOWID_W               )
    ) addr_to_flowid (
         .clk_i     (clk)
        ,.reset_i   (rst)

        // Synchronous write/invalidate of a tag
        // one or zero-hot
        ,.w_v_i             (cam_wr_val             )
        ,.w_set_not_clear_i (1'b1)
        // Tag/data to set on write
        ,.w_tag_i           (new_flow_lookup_entry  )
        ,.w_data_i          (new_flow_flow_id       )
        // Metadata useful for an external replacement policy
        // Whether there's an empty entry in the tag array
        ,.w_empty_o         ()
        
        // Asynchronous read of a tag, if exists
        ,.r_v_i             (read_flow_cam_val      )
        ,.r_tag_i           (read_flow_cam_tag      )

        ,.r_data_o          (read_flow_cam_flowid   )
        ,.r_v_o             (read_flow_cam_hit      )
    );
endmodule
