module rx_buf_store
import tcp_pkg::*;
(
     input clk
    ,input rst
    
    ,input                                  wr_req_val
    ,input          [FLOWID_W-1:0]          wr_req_flowid // this and idx are concatenated to make the real waddr
    ,input          [RX_PAYLOAD_IDX_W-1:0]  wr_req_idx
    ,input          tcp_buf                 wr_req_data
    ,output                                 wr_req_rdy

    ,input                                  rd0_req_val
    ,input          [FLOWID_W-1:0]          rd0_req_flowid
    ,input          [RX_PAYLOAD_IDX_W-1:0]  rd0_req_idx
    ,output logic                           rd0_req_rdy

    ,output logic                           rd0_resp_val
    ,output         tcp_buf                 rd0_resp_data // we can't return it with the idx because the idx is incomplete (missing top bit)
    ,input                                  rd0_resp_rdy
    
    ,input                                  rd1_req_val
    ,input          [FLOWID_W-1:0]          rd1_req_flowid
    ,input          [RX_PAYLOAD_IDX_W-1:0]  rd1_req_idx
    ,output logic                           rd1_req_rdy

    ,output logic                           rd1_resp_val
    ,output         tcp_buf                 rd1_resp_data
    ,input                                  rd1_resp_rdy
);

// convert from flowid + index to addr
wire [FLOWID_W + MAX_PAYLOAD_IDX_W - 1:0] wr_req_addr  = '{wr_req_flowid , wr_req_idx };
wire [FLOWID_W + MAX_PAYLOAD_IDX_W - 1:0] rd0_req_addr = '{rd0_req_flowid, rd0_req_idx};
wire [FLOWID_W + MAX_PAYLOAD_IDX_W - 1:0] rd1_req_addr = '{rd1_req_flowid, rd1_req_idx};

ram_2r1w_sync_backpressure #(
     .width_p   (TCP_BUF_W )
    ,.els_p     (MAX_FLOW_CNT * MAX_NUM_BUFS )
) rx_state_store (
     .clk   (clk    )
    ,.rst   (rst    )

    ,.wr_req_val    (wr_req_val            )
    ,.wr_req_addr   (wr_req_addr           )
    ,.wr_req_data   (wr_req_data           )
    ,.wr_req_rdy    (wr_req_rdy            )

    ,.rd0_req_val   (rd0_req_val       )
    ,.rd0_req_addr  (rd0_req_addr      )
    ,.rd0_req_rdy   (rd0_req_rdy       )

    ,.rd0_resp_val  (rd0_resp_val      )
    ,.rd0_resp_addr ()
    ,.rd0_resp_data (rd0_resp_data     )
    ,.rd0_resp_rdy  (rd0_resp_rdy      )
    
    ,.rd1_req_val   (rd1_req_val    )
    ,.rd1_req_addr  (rd1_req_addr   )
    ,.rd1_req_rdy   (rd1_req_rdy    )

    ,.rd1_resp_val  (rd1_resp_val   )
    ,.rd1_resp_addr ()
    ,.rd1_resp_data (rd1_resp_data  )
    ,.rd1_resp_rdy  (rd1_resp_rdy   )
);

endmodule