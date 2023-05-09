module rr_sched_engine 
import tcp_pkg::*;
import tcp_misc_pkg::*;
(
     input clk
    ,input rst
    
    ,input  logic                   app_sched_update_val
    ,input  sched_cmd_struct        app_sched_update_cmd
    ,output logic                   sched_app_update_rdy

    ,input  logic                   rx_sched_update_val
    ,input  sched_cmd_struct        rx_sched_update_cmd
    ,output logic                   sched_rx_update_rdy
    
    ,input  logic                   tx_sched_update_val
    ,input  sched_cmd_struct        tx_sched_update_cmd
    ,output logic                   sched_tx_update_rdy

    ,output logic                   sched_tx_req_val
    ,output sched_data_struct       sched_tx_req_data
    ,input  logic                   tx_sched_req_rdy

    ,input  logic                   new_flow_val
    ,input  logic   [FLOWID_W-1:0]  new_flow_flowid
);

    typedef enum logic[1:0] {
        RD_SCHED_STATE = 2'b0,
        WAIT_SCHED_STATE = 2'b1,
        OUTPUT = 2'd2,
        REQUEUE = 2'd3,
        UNDEF = 'X
    } find_state_e;

    typedef enum logic[1:0] {
        RD_CMD = 2'b0,
        UPDATE_STATE = 2'b1,
        WRITEBACK = 2'd2,
        UND = 'X
    } update_state_e;
    
    localparam ARB_NUM_SRCS = 3;
    logic   [ARB_NUM_SRCS-1:0]  arbiter_vals;
    logic   [ARB_NUM_SRCS-1:0]  arbiter_grants;
    logic                       advance_arb;

    logic   [ARB_NUM_SRCS-1:0]  grants_reg;
    logic   [ARB_NUM_SRCS-1:0]  grants_next;

    find_state_e find_state_reg;
    find_state_e find_state_next;

    update_state_e update_state_reg;
    update_state_e update_state_next;

    sched_cmd_struct        cmd_reg;
    sched_cmd_struct        cmd_next;
    logic                   store_cmd;

    sched_data_struct       next_sched_state_reg;
    sched_data_struct       next_sched_state_next;
    sched_data_struct       next_sched_state;
    sched_flag_data_struct  next_rt_flag;
    sched_flag_data_struct  next_ack_flag;
    sched_flag_data_struct  next_data_flag;
    logic                   store_next_sched_state;

    logic                   update_wr_req_val;
    sched_data_struct       update_wr_req_data;
    logic                   update_wr_req_rdy;

    logic                   sched_state_wr_req_val;
    sched_data_struct       sched_state_wr_req_data;
    logic                   sched_state_wr_req_rdy;
    
    logic                   update_rd_req_val;
    logic   [FLOWID_W-1:0]  update_rd_req_addr;
    logic                   update_rd_req_rdy;

    logic                   update_rd_resp_val;
    sched_data_struct       update_rd_resp_data;
    logic                   update_rd_resp_rdy;

    logic                   find_rd_req_val;
    logic   [FLOWID_W-1:0]  find_rd_req_addr;
    logic                   find_rd_req_rdy;

    logic                   find_rd_resp_val;
    sched_data_struct       find_rd_resp_data;
    logic                   find_rd_resp_rdy;

    logic   [FLOWID_W-1:0]  find_curr_flowid_reg;
    logic   [FLOWID_W-1:0]  find_curr_flowid_next;
    logic                   find_store_flowid;

    logic                   find_flowid_fifo_rd_req;
    logic   [FLOWID_W-1:0]  find_flowid_fifo_rd_data;
    logic                   find_flowid_fifo_empty;
    
    logic                   find_flowid_fifo_wr_req;
    logic   [FLOWID_W-1:0]  find_flowid_fifo_wr_data;
    logic                   find_flowid_fifo_wr_rdy;
    
    logic   should_sched;
    sched_data_struct       sched_data_reg;
    sched_data_struct       sched_data_next;
    logic                   store_sched_data;

    logic   active_fifo_wr_req;
    logic   active_fifo_wr_rdy;
    logic   active_fifo_full;
    logic   [FLOWID_W-1:0]  active_fifo_wr_data;

    logic               update_val;
    sched_cmd_struct    update_cmd;
    logic               update_rdy;

    assign update_val =| arbiter_vals;

    // update scheduler data
    always_ff @(posedge clk) begin
        if (rst) begin 
            update_state_reg <= RD_CMD;
        end
        else begin
            update_state_reg <= update_state_next;
            cmd_reg <= cmd_next;
            next_sched_state_reg <= next_sched_state_next;
        end
    end

    assign cmd_next = store_cmd
                    ? update_cmd
                    : cmd_reg;

    assign next_sched_state_next = store_next_sched_state
                                ? next_sched_state
                                : next_sched_state_reg;

    assign update_rd_req_addr = update_cmd.flowid;
    assign update_wr_req_data = next_sched_state_reg;

    always_comb begin
        next_sched_state = update_rd_resp_data;
        next_sched_state.rt_flag = next_rt_flag;
        next_sched_state.ack_pend_flag = next_ack_flag;
        next_sched_state.data_pend_flag = next_data_flag;
    end

    sched_cmd_flag_update rt_flag (
         .flag_cmd          (cmd_reg.rt_pend_set_clear      )
        ,.curr_flag_state   (update_rd_resp_data.rt_flag    )
    
        ,.next_flag_state   (next_rt_flag                   )
    );
    
    sched_cmd_flag_update ack_flag (
         .flag_cmd          (cmd_reg.ack_pend_set_clear         )
        ,.curr_flag_state   (update_rd_resp_data.ack_pend_flag  )
    
        ,.next_flag_state   (next_ack_flag                      )
    );
    
    sched_cmd_flag_update data_flag (
         .flag_cmd          (cmd_reg.data_pend_set_clear         )
        ,.curr_flag_state   (update_rd_resp_data.data_pend_flag  )
    
        ,.next_flag_state   (next_data_flag                      )
    );

    always_comb begin
        store_cmd = 1'b0;
        update_rd_req_val = 1'b0;
        update_rd_resp_rdy = 1'b0;
        update_wr_req_val = 1'b0;
        update_rdy = 1'b0;
        advance_arb = 1'b0;

        store_next_sched_state = 1'b0;

        update_state_next = update_state_reg;
        case (update_state_reg)
            RD_CMD: begin
                update_rd_req_val = update_val;
                update_rdy = update_rd_req_rdy;
                store_cmd = 1'b1;
                if (update_rd_req_rdy & update_val) begin
                    advance_arb = 1'b1;
                    update_state_next = UPDATE_STATE;
                end
            end
            UPDATE_STATE: begin
                store_next_sched_state = 1'b1;
                update_rd_resp_rdy = 1'b1;
                if (update_rd_resp_val) begin
                    update_state_next = WRITEBACK;
                end
            end
            WRITEBACK: begin
                update_wr_req_val = 1'b1;
                if (update_wr_req_rdy) begin
                    update_state_next = RD_CMD;
                end
            end
        endcase
    end
    
    // Find a flow
    always_ff @(posedge clk) begin
        if (rst) begin
            find_state_reg <= RD_SCHED_STATE;
        end
        else begin
            find_state_reg <= find_state_next;
            find_curr_flowid_reg <= find_curr_flowid_next;
            sched_data_reg <= sched_data_next;
        end
    end

    assign sched_tx_req_data = sched_data_reg;

    assign find_curr_flowid_next = find_store_flowid
                                ? find_flowid_fifo_rd_data
                                : find_curr_flowid_reg;

    assign find_rd_req_addr = find_flowid_fifo_rd_data;

    assign find_flowid_fifo_wr_data = find_curr_flowid_reg;

    assign sched_data_next = store_sched_data
                            ? find_rd_resp_data
                            : sched_data_reg;

    assign should_sched = find_rd_resp_data.rt_flag.flag
                        | find_rd_resp_data.ack_pend_flag.flag
                        | find_rd_resp_data.data_pend_flag.flag;

    always_comb begin
        find_flowid_fifo_rd_req = 1'b0;
        find_flowid_fifo_wr_req = 1'b0;
        
        sched_tx_req_val = 1'b0;

        find_store_flowid = 1'b0;
        find_rd_req_val = 1'b0;
        find_rd_resp_rdy = 1'b0;

        store_sched_data = 1'b0;

        find_state_next = find_state_reg;
        case (find_state_reg)
            RD_SCHED_STATE: begin
                find_store_flowid = 1'b1;
                if (~find_flowid_fifo_empty) begin
                    find_rd_req_val = 1'b1;
                    find_flowid_fifo_rd_req = 1'b1;
                    find_state_next = WAIT_SCHED_STATE;
                end
            end
            WAIT_SCHED_STATE: begin
                find_rd_resp_rdy = 1'b1;
                store_sched_data = 1'b1;
                if (find_rd_resp_val) begin
                    if (should_sched) begin
                        find_state_next = OUTPUT;
                    end
                    else begin
                        find_flowid_fifo_wr_req = 1'b1;
                        if (find_flowid_fifo_wr_rdy) begin
                            find_state_next = RD_SCHED_STATE;
                        end
                        else begin
                            find_state_next = REQUEUE;
                        end
                    end
                end
            end
            OUTPUT: begin
                sched_tx_req_val = 1'b1;
                if (tx_sched_req_rdy) begin
                    find_flowid_fifo_wr_req = 1'b1;
                    if (find_flowid_fifo_wr_rdy) begin
                        find_state_next = RD_SCHED_STATE;
                    end
                    else begin
                        find_state_next = REQUEUE;
                    end
                end
            end
            REQUEUE: begin
                find_flowid_fifo_wr_req = 1'b1;
                if (find_flowid_fifo_wr_rdy) begin
                    find_state_next = RD_SCHED_STATE;
                end
            end
        endcase
    end

    sched_data_struct   new_sched_data;
    always_comb begin
        new_sched_data = '0;
        new_sched_data.flowid = new_flow_flowid;
    end

    prio0_mux #(
        .DATA_W (SCHED_DATA_STRUCT_W    )
    ) sched_state_mux (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.src0_val  (new_flow_val               )
        ,.src0_data (new_sched_data             )
        ,.src0_rdy  (                           )
    
        ,.src1_val  (update_wr_req_val          )
        ,.src1_data (update_wr_req_data         )
        ,.src1_rdy  (update_wr_req_rdy          )
    
        ,.dst_val   (sched_state_wr_req_val     )
        ,.dst_data  (sched_state_wr_req_data    )
        ,.dst_rdy   (sched_state_wr_req_rdy     )
    );


    // State holding modules
    ram_2r1w_sync_backpressure #(
         .width_p   (SCHED_DATA_STRUCT_W    )
        ,.els_p     (MAX_FLOW_CNT           )
    ) sched_state_mem (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.wr_req_val    (sched_state_wr_req_val         )
        ,.wr_req_addr   (sched_state_wr_req_data.flowid )
        ,.wr_req_data   (sched_state_wr_req_data        )
        ,.wr_req_rdy    (sched_state_wr_req_rdy         )
    
        ,.rd0_req_val   (update_rd_req_val              )
        ,.rd0_req_addr  (update_rd_req_addr             )
        ,.rd0_req_rdy   (update_rd_req_rdy              )
    
        ,.rd0_resp_val  (update_rd_resp_val             )
        ,.rd0_resp_addr ()
        ,.rd0_resp_data (update_rd_resp_data            )
        ,.rd0_resp_rdy  (update_rd_resp_rdy             )
        
        ,.rd1_req_val   (find_rd_req_val    )
        ,.rd1_req_addr  (find_rd_req_addr   )
        ,.rd1_req_rdy   (find_rd_req_rdy    )
    
        ,.rd1_resp_val  (find_rd_resp_val   )
        ,.rd1_resp_addr ()
        ,.rd1_resp_data (find_rd_resp_data  )
        ,.rd1_resp_rdy  (find_rd_resp_rdy   )
    );

    prio0_mux #(
        .DATA_W (FLOWID_W   )
    ) new_flow_mux (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.src0_val  (new_flow_val               )
        ,.src0_data (new_flow_flowid            )
        ,.src0_rdy  ()
    
        ,.src1_val  (find_flowid_fifo_wr_req    )
        ,.src1_data (find_flowid_fifo_wr_data   )
        ,.src1_rdy  (find_flowid_fifo_wr_rdy    )
    
        ,.dst_val   (active_fifo_wr_req         )
        ,.dst_data  (active_fifo_wr_data        )
        ,.dst_rdy   (active_fifo_wr_rdy         )
    );

    assign active_fifo_wr_rdy = ~active_fifo_full;
    fifo_1r1w #(
         .width_p       (FLOWID_W   )
        ,.log2_els_p    (FLOWID_W   )
    ) active_flow_fifo (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.rd_req    (find_flowid_fifo_rd_req    )
        ,.rd_data   (find_flowid_fifo_rd_data   )
        ,.empty     (find_flowid_fifo_empty     )
    
        ,.wr_req    (active_fifo_wr_req         )
        ,.wr_data   (active_fifo_wr_data        )
        ,.full      (active_fifo_full           )
    );

    assign arbiter_vals = {app_sched_update_val, rx_sched_update_val, tx_sched_update_val};

    bsg_arb_round_robin #(
        .width_p   (3  )
    ) cmd_arbiter (
        .clk_i      (clk    )
       ,.reset_i    (rst    )
    
       ,.reqs_i     (arbiter_vals   )
       ,.grants_o   (arbiter_grants )
       ,.yumi_i     (advance_arb    )
    );
    
    bsg_mux_one_hot #(
         .width_p   (SCHED_CMD_STRUCT_W )
        ,.els_p     (ARB_NUM_SRCS       )
    ) update_cmd_mux (
         .data_i        ({app_sched_update_cmd, rx_sched_update_cmd, tx_sched_update_cmd}   )
        ,.sel_one_hot_i (arbiter_grants     )
        ,.data_o        (update_cmd         )
    );

    demux_one_hot #(
         .NUM_OUTPUTS   (ARB_NUM_SRCS   )
        ,.INPUT_WIDTH   (1              )
    ) rdy_demux (
         .input_sel     (arbiter_grants )
        ,.data_input    (update_rdy     )
        ,.data_outputs  ({sched_app_update_rdy, sched_rx_update_rdy, sched_tx_update_rdy})
    );
endmodule
