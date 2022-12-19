module rx_buf_ptrs
import tcp_pkg::*;
(
     input clk
    ,input rst
    
    ,input                                  head_ptr_wr_req_val
    ,input          [FLOWID_W-1:0]          head_ptr_wr_req_addr
    ,input          [RX_PAYLOAD_PTR_W:0]    head_ptr_wr_req_data
    ,output                                 head_ptr_wr_req_rdy

    ,input                                  head_ptr_rd0_req_val
    ,input          [FLOWID_W-1:0]          head_ptr_rd0_req_addr
    ,output logic                           head_ptr_rd0_req_rdy

    ,output logic                           head_ptr_rd0_resp_val
    ,output logic   [RX_PAYLOAD_PTR_W:0]    head_ptr_rd0_resp_data
    ,input                                  head_ptr_rd0_resp_rdy
    
    ,input                                  head_ptr_rd1_req_val
    ,input          [FLOWID_W-1:0]          head_ptr_rd1_req_addr
    ,output logic                           head_ptr_rd1_req_rdy

    ,output logic                           head_ptr_rd1_resp_val
    ,output logic   [RX_PAYLOAD_PTR_W:0]    head_ptr_rd1_resp_data
    ,input                                  head_ptr_rd1_resp_rdy
    
    ,input                                  commit_ptr_wr_req_val
    ,input          [FLOWID_W-1:0]          commit_ptr_wr_req_addr
    ,input          [RX_PAYLOAD_PTR_W:0]    commit_ptr_wr_req_data
    ,output                                 commit_ptr_wr_req_rdy

    ,input                                  commit_ptr_rd0_req_val
    ,input          [FLOWID_W-1:0]          commit_ptr_rd0_req_addr
    ,output logic                           commit_ptr_rd0_req_rdy

    ,output logic                           commit_ptr_rd0_resp_val
    ,output logic   [RX_PAYLOAD_PTR_W:0]    commit_ptr_rd0_resp_data
    ,input                                  commit_ptr_rd0_resp_rdy
    
    ,input                                  commit_ptr_rd1_req_val
    ,input          [FLOWID_W-1:0]          commit_ptr_rd1_req_addr
    ,output logic                           commit_ptr_rd1_req_rdy

    ,output logic                           commit_ptr_rd1_resp_val
    ,output logic   [RX_PAYLOAD_PTR_W:0]    commit_ptr_rd1_resp_data
    ,input                                  commit_ptr_rd1_resp_rdy
    
    ,input                                  tail_ptr_wr_req_val
    ,input          [FLOWID_W-1:0]          tail_ptr_wr_req_addr
    ,input          [RX_PAYLOAD_PTR_W:0]    tail_ptr_wr_req_data
    ,output                                 tail_ptr_wr_req_rdy

    ,input                                  tail_ptr_rd_req_val
    ,input          [FLOWID_W-1:0]          tail_ptr_rd_req_addr
    ,output logic                           tail_ptr_rd_req_rdy

    ,output logic                           tail_ptr_rd_resp_val
    ,output logic   [RX_PAYLOAD_PTR_W:0]    tail_ptr_rd_resp_data
    ,input                                  tail_ptr_rd_resp_rdy

    ,input                                  new_flow_val
    ,input          [FLOWID_W-1:0]          new_flow_flowid
    ,input          [RX_PAYLOAD_PTR_W:0]    new_rx_head_ptr
    ,input          [RX_PAYLOAD_PTR_W:0]    new_rx_tail_ptr
    ,output                                 new_flow_rx_payload_ptrs_rdy
);

    logic   head_ptr_mem_wr_req_rdy;
    logic   tail_ptr_mem_wr_req_rdy;
    logic   commit_ptr_mem_wr_req_rdy;
    
    logic   head_ptr_mem_wr_req_val;
    logic   tail_ptr_mem_wr_req_val;
    logic   commit_ptr_mem_wr_req_val;
    
    logic   [RX_PAYLOAD_PTR_W:0]   head_ptr_mem_wr_req_data;
    logic   [RX_PAYLOAD_PTR_W:0]   tail_ptr_mem_wr_req_data;
    logic   [RX_PAYLOAD_PTR_W:0]   commit_ptr_mem_wr_req_data;
    
    logic   [FLOWID_W-1:0]        head_ptr_mem_wr_req_addr;
    logic   [FLOWID_W-1:0]        tail_ptr_mem_wr_req_addr;
    logic   [FLOWID_W-1:0]        commit_ptr_mem_wr_req_addr;

    assign new_flow_rx_payload_ptrs_rdy = head_ptr_mem_wr_req_rdy
                                        & tail_ptr_mem_wr_req_rdy
                                        & commit_ptr_mem_wr_req_rdy;

    assign head_ptr_wr_req_rdy = ~new_flow_val & head_ptr_mem_wr_req_rdy;
    assign tail_ptr_wr_req_rdy = ~new_flow_val & tail_ptr_mem_wr_req_rdy;
    assign commit_ptr_wr_req_rdy = ~new_flow_val & commit_ptr_mem_wr_req_rdy;

    assign head_ptr_mem_wr_req_val = new_flow_val | head_ptr_wr_req_val;
    assign tail_ptr_mem_wr_req_val = new_flow_val | tail_ptr_wr_req_val;
    assign commit_ptr_mem_wr_req_val = new_flow_val | commit_ptr_wr_req_val;

    assign head_ptr_mem_wr_req_addr = new_flow_val
                                    ? new_flow_flowid
                                    : head_ptr_wr_req_addr;
    
    assign tail_ptr_mem_wr_req_addr = new_flow_val
                                    ? new_flow_flowid
                                    : tail_ptr_wr_req_addr;
    
    assign commit_ptr_mem_wr_req_addr = new_flow_val
                                      ? new_flow_flowid
                                      : commit_ptr_wr_req_addr;

    assign head_ptr_mem_wr_req_data = new_flow_val
                                    ? new_rx_head_ptr
                                    : head_ptr_wr_req_data;
    
    assign tail_ptr_mem_wr_req_data = new_flow_val
                                    ? new_rx_tail_ptr
                                    : tail_ptr_wr_req_data;
    
    assign commit_ptr_mem_wr_req_data = new_flow_val
                                      ? new_rx_tail_ptr
                                      : commit_ptr_wr_req_data;

    ram_2r1w_sync_backpressure #(
         .width_p   (RX_PAYLOAD_PTR_W + 1   )
        ,.els_p     (MAX_FLOW_CNT           )
    ) head_ptrs (
         .clk   (clk)
        ,.rst   (rst)

        ,.wr_req_val    (head_ptr_mem_wr_req_val    )
        ,.wr_req_addr   (head_ptr_mem_wr_req_addr   )
        ,.wr_req_data   (head_ptr_mem_wr_req_data   )
        ,.wr_req_rdy    (head_ptr_mem_wr_req_rdy    )
                                                 
        ,.rd0_req_val   (head_ptr_rd0_req_val       )
        ,.rd0_req_addr  (head_ptr_rd0_req_addr      )
        ,.rd0_req_rdy   (head_ptr_rd0_req_rdy       )
                                                     
        ,.rd0_resp_val  (head_ptr_rd0_resp_val      )
        ,.rd0_resp_addr ()
        ,.rd0_resp_data (head_ptr_rd0_resp_data     )
        ,.rd0_resp_rdy  (head_ptr_rd0_resp_rdy      )
                                                     
        ,.rd1_req_val   (head_ptr_rd1_req_val       )
        ,.rd1_req_addr  (head_ptr_rd1_req_addr      )
        ,.rd1_req_rdy   (head_ptr_rd1_req_rdy       )
                                                     
        ,.rd1_resp_val  (head_ptr_rd1_resp_val      )
        ,.rd1_resp_addr ()
        ,.rd1_resp_data (head_ptr_rd1_resp_data     )
        ,.rd1_resp_rdy  (head_ptr_rd1_resp_rdy      )
    );
    
    ram_2r1w_sync_backpressure #(
         .width_p   (RX_PAYLOAD_PTR_W + 1   )
        ,.els_p     (MAX_FLOW_CNT           )
    ) commit_ptrs (
         .clk   (clk)
        ,.rst   (rst)

        ,.wr_req_val    (commit_ptr_mem_wr_req_val    )
        ,.wr_req_addr   (commit_ptr_mem_wr_req_addr   )
        ,.wr_req_data   (commit_ptr_mem_wr_req_data   )
        ,.wr_req_rdy    (commit_ptr_mem_wr_req_rdy    )
                                                 
        ,.rd0_req_val   (commit_ptr_rd0_req_val       )
        ,.rd0_req_addr  (commit_ptr_rd0_req_addr      )
        ,.rd0_req_rdy   (commit_ptr_rd0_req_rdy       )
                                                     
        ,.rd0_resp_val  (commit_ptr_rd0_resp_val      )
        ,.rd0_resp_addr ()
        ,.rd0_resp_data (commit_ptr_rd0_resp_data     )
        ,.rd0_resp_rdy  (commit_ptr_rd0_resp_rdy      )
                                                     
        ,.rd1_req_val   (commit_ptr_rd1_req_val       )
        ,.rd1_req_addr  (commit_ptr_rd1_req_addr      )
        ,.rd1_req_rdy   (commit_ptr_rd1_req_rdy       )
                                                     
        ,.rd1_resp_val  (commit_ptr_rd1_resp_val      )
        ,.rd1_resp_addr ()
        ,.rd1_resp_data (commit_ptr_rd1_resp_data     )
        ,.rd1_resp_rdy  (commit_ptr_rd1_resp_rdy      )
    );

    ram_1r1w_sync_backpressure #(
         .width_p   (RX_PAYLOAD_PTR_W + 1   )
        ,.els_p     (MAX_FLOW_CNT           )
    ) tail_ptrs (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.wr_req_val    (tail_ptr_mem_wr_req_val    )
        ,.wr_req_addr   (tail_ptr_mem_wr_req_addr   )
        ,.wr_req_data   (tail_ptr_mem_wr_req_data   )
        ,.wr_req_rdy    (tail_ptr_mem_wr_req_rdy    )
                                                       
        ,.rd_req_val    (tail_ptr_rd_req_val        )
        ,.rd_req_addr   (tail_ptr_rd_req_addr       )
        ,.rd_req_rdy    (tail_ptr_rd_req_rdy        )
                                                       
        ,.rd_resp_val   (tail_ptr_rd_resp_val       )
        ,.rd_resp_data  (tail_ptr_rd_resp_data      )
        ,.rd_resp_rdy   (tail_ptr_rd_resp_rdy       )
    );

endmodule
