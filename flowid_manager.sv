module flowid_manager 
import tcp_pkg::*;
(
     input clk
    ,input rst

    ,input                          flowid_ret_val
    ,input          [FLOWID_W-1:0]  flowid_ret_id
    ,output                         flowid_ret_rdy

    ,input                          flowid_req
    ,output logic                   flowid_avail
    ,output logic   [FLOWID_W-1:0]  flowid
);

    logic   [FLOWID_W-1:0]  flowid_reg;
    logic   [FLOWID_W-1:0]  flowid_next;
    logic                   use_fifo_reg;
    logic                   use_fifo_next;
    
    logic                   fifo_rd_req;
    logic                   fifo_empty;
    logic   [FLOWID_W-1:0]  fifo_rd_data;

    logic                   fifo_wr_req;
    logic   [FLOWID_W-1:0]  fifo_wr_data;
    logic                   fifo_full;

    assign flowid_avail = use_fifo_reg ? ~fifo_empty : 1'b1;
    assign flowid = use_fifo_reg ? fifo_rd_data : flowid_reg;
    assign fifo_rd_req = flowid_req & use_fifo_reg;

    assign fifo_wr_req = flowid_ret_val;
    assign fifo_wr_data = flowid_ret_id;
    assign flowid_ret_rdy = ~fifo_full;


    always_ff @(posedge clk) begin
        if (rst) begin
            flowid_reg <= '0;
            use_fifo_reg <= '0;
        end
        else begin
            flowid_reg <= flowid_next;
            use_fifo_reg <= use_fifo_next;
        end
    end

    always_comb begin
        use_fifo_next = use_fifo_reg;
        flowid_next = flowid_reg;
        if (flowid_req) begin
            if (flowid_reg == {FLOWID_W{1'b1}}) begin
                flowid_next = '0;
                use_fifo_next = 1'b1;
            end
            else begin
                flowid_next = flowid_reg + 1'b1;
                use_fifo_next = 1'b0;
            end
        end
        else begin
            use_fifo_next = use_fifo_reg;
            flowid_next = flowid_reg;
        end
    end

    fifo_1r1w #(
         .width_p       (FLOWID_W)
        ,.log2_els_p    (FLOWID_W)
    ) reclaimed_flowids (
         .clk   (clk)
        ,.rst   (rst)

        ,.rd_req    (fifo_rd_req    )
        ,.empty     (fifo_empty     )
        ,.rd_data   (fifo_rd_data   )

        ,.wr_req    (fifo_wr_req    )
        ,.wr_data   (fifo_wr_data   )
        ,.full      (fifo_full      )
    );

endmodule
