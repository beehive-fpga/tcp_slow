module tx_buf_ptrs 
import tcp_pkg::*;
(
     input   clk
    ,input   rst

    ,input                                  head_ptr_rd_req0_val
    ,input          [FLOWID_W-1:0]          head_ptr_rd_req0_addr
    ,output logic                           head_ptr_rd_req0_rdy

    ,output                                 head_ptr_rd_resp0_val
    ,output logic   [FLOWID_W-1:0]          head_ptr_rd_resp0_addr
    ,output logic   [TX_PAYLOAD_PTR_W:0]    head_ptr_rd_resp0_data
    ,input  logic                           head_ptr_rd_resp0_rdy
    
    ,input                                  head_ptr_rd_req1_val
    ,input          [FLOWID_W-1:0]          head_ptr_rd_req1_addr
    ,output logic                           head_ptr_rd_req1_rdy

    ,output                                 head_ptr_rd_resp1_val
    ,output logic   [FLOWID_W-1:0]          head_ptr_rd_resp1_addr
    ,output logic   [TX_PAYLOAD_PTR_W:0]    head_ptr_rd_resp1_data
    ,input  logic                           head_ptr_rd_resp1_rdy

    ,input                                  head_ptr_wr_req_val
    ,input          [FLOWID_W-1:0]          head_ptr_wr_req_addr
    ,input          [TX_PAYLOAD_PTR_W:0]    head_ptr_wr_req_data
    ,output                                 head_ptr_wr_req_rdy
    
    ,input                                  tail_ptr_rd_req0_val
    ,input          [FLOWID_W-1:0]          tail_ptr_rd_req0_addr
    ,output logic                           tail_ptr_rd_req0_rdy

    ,output                                 tail_ptr_rd_resp0_val
    ,output logic   [FLOWID_W-1:0]          tail_ptr_rd_resp0_addr
    ,output logic   [TX_PAYLOAD_PTR_W:0]    tail_ptr_rd_resp0_data
    ,input  logic                           tail_ptr_rd_resp0_rdy
    
    ,input                                  tail_ptr_rd_req1_val
    ,input          [FLOWID_W-1:0]          tail_ptr_rd_req1_addr
    ,output logic                           tail_ptr_rd_req1_rdy

    ,output                                 tail_ptr_rd_resp1_val
    ,output logic   [FLOWID_W-1:0]          tail_ptr_rd_resp1_addr
    ,output logic   [TX_PAYLOAD_PTR_W:0]    tail_ptr_rd_resp1_data
    ,input  logic                           tail_ptr_rd_resp1_rdy

    ,input                                  tail_ptr_wr_req_val
    ,input          [FLOWID_W-1:0]          tail_ptr_wr_req_addr
    ,input          [TX_PAYLOAD_PTR_W:0]    tail_ptr_wr_req_data
    ,output                                 tail_ptr_wr_req_rdy

    ,input                                  new_flow_val
    ,input          [FLOWID_W-1:0]          new_flow_flowid
    ,input          [TX_PAYLOAD_PTR_W:0]    new_flow_head_ptr
    ,input          [TX_PAYLOAD_PTR_W:0]    new_flow_tail_ptr
    ,output                                 new_flow_rdy
);
    logic                           head_ptr_mem_wr_req_val;
    logic   [FLOWID_W-1:0]          head_ptr_mem_wr_req_addr;
    logic   [TX_PAYLOAD_PTR_W:0]    head_ptr_mem_wr_req_data;
    logic                           head_ptr_mem_wr_req_rdy;
    
    logic                           tail_ptr_mem_wr_req_val;
    logic   [FLOWID_W-1:0]          tail_ptr_mem_wr_req_addr;
    logic   [TX_PAYLOAD_PTR_W:0]    tail_ptr_mem_wr_req_data;
    logic                           tail_ptr_mem_wr_req_rdy;

    assign new_flow_rdy = head_ptr_mem_wr_req_rdy & tail_ptr_mem_wr_req_rdy;
    // we always accept the new flow write request over any other write request
    assign head_ptr_wr_req_rdy = ~new_flow_val & (head_ptr_mem_wr_req_rdy);
    assign tail_ptr_wr_req_rdy = ~new_flow_val;

    assign head_ptr_mem_wr_req_val = new_flow_val | head_ptr_wr_req_val;
    assign head_ptr_mem_wr_req_addr = new_flow_val
                                ? new_flow_flowid
                                : head_ptr_wr_req_addr;
    assign head_ptr_mem_wr_req_data = new_flow_val
                                ? new_flow_head_ptr
                                : head_ptr_wr_req_data;

    assign tail_ptr_mem_wr_req_val = new_flow_val | tail_ptr_wr_req_val;
    assign tail_ptr_mem_wr_req_addr = new_flow_val
                                ? new_flow_flowid
                                : tail_ptr_wr_req_addr;
    assign tail_ptr_mem_wr_req_data = new_flow_val
                                ? new_flow_tail_ptr
                                : tail_ptr_wr_req_data;
    
    ram_2r1w_sync_backpressure #(
         .width_p   (TX_PAYLOAD_PTR_W + 1)
        ,.els_p     (MAX_FLOW_CNT)
   ) head_ptrs (
         .clk   (clk)
        ,.rst   (rst)

        ,.wr_req_val    (head_ptr_mem_wr_req_val    )
        ,.wr_req_addr   (head_ptr_mem_wr_req_addr   )
        ,.wr_req_data   (head_ptr_mem_wr_req_data   )
        ,.wr_req_rdy    (head_ptr_mem_wr_req_rdy    )

        ,.rd0_req_val   (head_ptr_rd_req0_val       )
        ,.rd0_req_addr  (head_ptr_rd_req0_addr      )
        ,.rd0_req_rdy   (head_ptr_rd_req0_rdy       )

        ,.rd0_resp_val  (head_ptr_rd_resp0_val      )
        ,.rd0_resp_addr (head_ptr_rd_resp0_addr     )
        ,.rd0_resp_data (head_ptr_rd_resp0_data     )
        ,.rd0_resp_rdy  (head_ptr_rd_resp0_rdy      )

        ,.rd1_req_val   (head_ptr_rd_req1_val       )
        ,.rd1_req_addr  (head_ptr_rd_req1_addr      )
        ,.rd1_req_rdy   (head_ptr_rd_req1_rdy       )
                                                     
        ,.rd1_resp_val  (head_ptr_rd_resp1_val      )
        ,.rd1_resp_addr (head_ptr_rd_resp1_addr     )
        ,.rd1_resp_data (head_ptr_rd_resp1_data     )
        ,.rd1_resp_rdy  (head_ptr_rd_resp1_rdy      )
   );   

    ram_2r1w_sync_backpressure #(
         .width_p   (TX_PAYLOAD_PTR_W+1)
        ,.els_p     (MAX_FLOW_CNT)
    ) tail_ptrs (
         .clk   (clk)
        ,.rst   (rst)

        ,.wr_req_val    (tail_ptr_mem_wr_req_val    )
        ,.wr_req_addr   (tail_ptr_mem_wr_req_addr   )
        ,.wr_req_data   (tail_ptr_mem_wr_req_data   )
        ,.wr_req_rdy    (tail_ptr_mem_wr_req_rdy    )

        ,.rd0_req_val   (tail_ptr_rd_req0_val       )
        ,.rd0_req_addr  (tail_ptr_rd_req0_addr      )
        ,.rd0_req_rdy   (tail_ptr_rd_req0_rdy       )
                                                     
        ,.rd0_resp_val  (tail_ptr_rd_resp0_val      )
        ,.rd0_resp_addr (tail_ptr_rd_resp0_addr     )
        ,.rd0_resp_data (tail_ptr_rd_resp0_data     )
        ,.rd0_resp_rdy  (tail_ptr_rd_resp0_rdy      )
                                                     
        ,.rd1_req_val   (tail_ptr_rd_req1_val       )
        ,.rd1_req_addr  (tail_ptr_rd_req1_addr      )
        ,.rd1_req_rdy   (tail_ptr_rd_req1_rdy       )
                                                     
        ,.rd1_resp_val  (tail_ptr_rd_resp1_val      )
        ,.rd1_resp_addr (tail_ptr_rd_resp1_addr     )
        ,.rd1_resp_data (tail_ptr_rd_resp1_data     )
        ,.rd1_resp_rdy  (tail_ptr_rd_resp1_rdy      )
    );

endmodule
