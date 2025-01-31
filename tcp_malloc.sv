module tcp_malloc #(
     parameter PTR_W = 0 // determines how big the backing memory should be
    ,parameter LEN_MAX = 0 // the largest buffer that a user will request. in the naive impl, the memory is split into fixed sized chunks where this is the chunk size.
    ,parameter STALL = 0 // whether or not to stall when we get a malloc that we can't yet fulfill. stall=0 -> return !resp_success, stall=1 -> don't return until we fulfill the request.

    // generated param
    ,parameter LEN_W = $clog2(LEN_MAX)
)(
     input clk
    ,input rst

    ,input                                  malloc_req_val
    ,input          [LEN_W-1:0]             malloc_req_len // in the native impl, this must equal LEN_MAX
    ,output                                 malloc_req_rdy

    ,output                                 malloc_resp_val
    ,output                                 malloc_resp_success // 1 = addr is valid. 0 = addr is junk, retry your request or otherwise handle OOM.
    ,output         [PTR_W-1:0]             malloc_resp_addr
    ,input                                  malloc_resp_rdy

    ,output         [PTR_W:0]               malloc_approx_empty_space

    ,input                                  free_req_val
    ,input          [PTR_W-1:0]             free_req_addr
    ,input          [LEN_W-1:0]             free_req_len // in the native impl, this must equal LEN_MAX
    ,output                                 free_req_rdy
);

localparam BACKING_SIZE_UPPER = 2**PTR_W;

localparam NUM_TOTAL_SLICES = BACKING_SIZE_UPPER/LEN_MAX; // round down, half-avail slices aren't useful
localparam SLICES_W = $clog2(NUM_TOTAL_SLICES);
localparam BACKING_SIZE_EXACT = NUM_TOTAL_SLICES * LEN_MAX;

// hookup the inputs and outputs
logic malloc_req_fifo_wr_req;
logic [LEN_W-1:0] malloc_req_fifo_wr_data;
logic malloc_req_fifo_full;
assign malloc_req_fifo_wr_req = malloc_req_val;
assign malloc_req_fifo_wr_data = malloc_req_len;
assign malloc_req_rdy = ~malloc_req_fifo_full;

logic malloc_resp_fifo_empty;
logic [PTR_W:0] malloc_resp_fifo_rd_data;
logic malloc_resp_fifo_rd_req;
assign malloc_resp_val = ~malloc_resp_fifo_empty;
assign malloc_resp_success = malloc_resp_fifo_rd_data[PTR_W];
assign malloc_resp_addr = malloc_resp_fifo_rd_data[PTR_W-1:0];
assign malloc_resp_fifo_rd_req = malloc_resp_rdy;

logic free_req_fifo_wr_req;
logic [PTR_W+LEN_W-1:0] free_req_fifo_wr_data;
logic free_req_fifo_full;
assign free_req_fifo_wr_req = free_req_val;
assign free_req_fifo_wr_data = '{free_req_addr, free_req_len};
assign free_req_rdy = ~free_req_fifo_full;

always_ff @(posedge clk) begin
    if (malloc_req_val && malloc_req_rdy) begin
        if (malloc_req_len != LEN_MAX) begin
            $fatal("Error: naive malloc requires malloc_req_len == LEN_MAX == %d instead of %d", LEN_MAX, malloc_req_len);
        end
    end
    if (free_req_val && free_req_rdy) begin
        if (free_req_len != LEN_MAX) begin
            $fatal("Error: naive malloc requires free_req_len == LEN_MAX == %d instead of %d", LEN_MAX, free_req_len);
        end
    end
end

// internal logic. req feeds resp, free and reset feed slices, slices also feeds resp.
// free || reset -> slices, slices && req -> resp

logic slices_fifo_rd_req;
logic slices_fifo_empty;
logic [PTR_W+LEN_W-1:0] slices_fifo_rd_data;

logic slices_fifo_wr_req;
logic [PTR_W+LEN_W-1:0] slices_fifo_wr_data;
logic slices_fifo_full;

logic malloc_req_fifo_rd_req;
logic malloc_req_fifo_empty;
logic [LEN_W-1:0] malloc_req_fifo_rd_data; // unused.

logic malloc_resp_fifo_wr_req;
logic [LEN_W:0] malloc_resp_fifo_wr_data;
logic malloc_resp_fifo_full;

logic free_req_fifo_rd_req;
logic free_req_fifo_empty;
logic [PTR_W+LEN_W-1:0] free_req_fifo_rd_data;

// not actually a fifo, but framed like one for convenience
logic reset_fifo_rd_req;
logic reset_fifo_empty;
logic [PTR_W+LEN_W-1:0] reset_fifo_rd_data;

always_ff @(posedge clk) begin
    if (rst) begin
        if (LEN_MAX > BACKING_SIZE_EXACT) begin
            $fatal("len max > backing size of tcp malloc unit... bad configuration");
        end
    end else begin
        if (slices_fifo_full) begin
            $fatal("slices fifo should never fill up, an error was made calculating its size");
        end
    end
end

// free || reset -> slices
assign free_req_fifo_rd_req = ~slices_fifo_full;
assign reset_fifo_rd_req = free_req_fifo_empty && ~slices_fifo_full;
assign slices_fifo_wr_req = ~free_req_fifo_empty || (free_req_fifo_empty && ~reset_fifo_empty);
assign slices_fifo_wr_data = ~free_req_fifo_empty ? free_req_fifo_rd_data : reset_fifo_rd_data;

// slices && req -> resp
assign slices_fifo_rd_req = ~malloc_resp_fifo_full && ~malloc_req_fifo_empty;
generate
    if (STALL) begin
        assign malloc_req_fifo_rd_req = ~malloc_resp_fifo_full && ~slices_fifo_empty;
        assign malloc_resp_fifo_wr_req = ~slices_fifo_empty && ~malloc_req_fifo_empty;
        assign malloc_resp_fifo_wr_data = '{1'b1, slices_fifo_rd_data[PTR_W+LEN_W-1:LEN_W]};
    end else begin
        assign malloc_req_fifo_rd_req = ~malloc_resp_fifo_full;
        assign malloc_resp_fifo_wr_req = ~malloc_req_fifo_empty;
        assign malloc_resp_fifo_wr_data = '{~slices_fifo_empty, slices_fifo_rd_data[PTR_W+LEN_W-1:LEN_W]};
    end
endgenerate


// reset logic
logic [PTR_W:0] reset_current_addr_reg = 0;
logic [PTR_W:0] reset_current_addr_next;
logic reset_done = 0;
assign reset_current_addr_next = reset_current_addr_reg + LEN_MAX;

assign reset_fifo_empty = reset_done;
assign reset_fifo_rd_data = '{reset_current_addr[PTR_W-1:0], LEN_MAX};

always_ff @(posedge clk) begin
    if (rst) begin
        reset_current_addr_reg <= '0;
        reset_done <= '0;
    end else begin
        if (reset_fifo_rd_req && ~reset_fifo_empty) begin
            // transaction occurred.
            reset_current_addr_reg <= reset_current_addr_next;
            if (reset_current_addr_next >= BACKING_SIZE_EXACT) begin
                reset_done <= 1;
            end
        end
    end
end

// free bytes/empty space logic
logic [PTR_W:0] free_bytes_cnt_reg = BACKING_SIZE_EXACT;
logic [PTR_W:0] free_bytes_cnt_next;
assign malloc_approx_empty_space = free_bytes_cnt_reg;

always_comb begin
    free_bytes_cnt_next = free_bytes_cnt_reg;

    // malloc request means one fewer slice
    if (slices_fifo_rd_req && ~slices_fifo_empty) begin
        free_bytes_cnt_next = free_bytes_cnt_next - LEN_MAX;
    end

    // slice write from the free fifo means one more slice
    // notably, reset doesn't increment. it starts out totally empty.
    if (slices_fifo_wr_req && ~slices_fifo_full && ~free_req_fifo_empty && free_req_fifo_rd_req) begin
        free_bytes_cnt_next = free_bytes_cnt_next + LEN_MAX;
    end
end

always @(posedge clk) begin
    if (rst) begin
        free_bytes_cnt_reg <= BACKING_SIZE_EXACT;
    end else begin
        free_bytes_cnt_reg <= free_bytes_cnt_next;
        if (free_bytes_cnt_next > BACKING_SIZE_EXACT) begin
            $fatal("bug in free bytes calculation")
        end
    end

end

fifo_1r1w #(
    .width_p       (PTR_W+LEN_W)
    ,.log2_els_p   (SLICES_W)
) slices_fifo (
     .clk   (clk)
    ,.rst   (rst)

    ,.rd_req    (slices_fifo_rd_req    )
    ,.empty     (slices_fifo_empty     )
    ,.rd_data   (slices_fifo_rd_data   )

    ,.wr_req    (slices_fifo_wr_req    )
    ,.wr_data   (slices_fifo_wr_data   )
    ,.full      (slices_fifo_full      )
);

fifo_1r1w #(
    .width_p       (LEN_W)
    ,.log2_els_p   (1)
) malloc_req_fifo (
     .clk   (clk)
    ,.rst   (rst)

    ,.rd_req    (malloc_req_fifo_rd_req    )
    ,.empty     (malloc_req_fifo_empty     )
    ,.rd_data   (malloc_req_fifo_rd_data   )

    ,.wr_req    (malloc_req_fifo_wr_req    )
    ,.wr_data   (malloc_req_fifo_wr_data   )
    ,.full      (malloc_req_fifo_full      )
);

fifo_1r1w #(
    .width_p       (1+LEN_W)
    ,.log2_els_p   (1)
) malloc_resp_fifo (
     .clk   (clk)
    ,.rst   (rst)

    ,.rd_req    (malloc_resp_fifo_rd_req    )
    ,.empty     (malloc_resp_fifo_empty     )
    ,.rd_data   (malloc_resp_fifo_rd_data   )

    ,.wr_req    (malloc_resp_fifo_wr_req    )
    ,.wr_data   (malloc_resp_fifo_wr_data   )
    ,.full      (malloc_resp_fifo_full      )
);

fifo_1r1w #(
    .width_p       (PTR_W+LEN_W)
    ,.log2_els_p   (1)
) free_req_fifo (
     .clk   (clk)
    ,.rst   (rst)

    ,.rd_req    (free_req_fifo_rd_req    )
    ,.empty     (free_req_fifo_empty     )
    ,.rd_data   (free_req_fifo_rd_data   )

    ,.wr_req    (free_req_fifo_wr_req    )
    ,.wr_data   (free_req_fifo_wr_data   )
    ,.full      (free_req_fifo_full      )
);

endmodule