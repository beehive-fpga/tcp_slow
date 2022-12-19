`include "packet_defs.vh"
module tx_timeout_eng 
import tcp_pkg::*;
import tcp_misc_pkg::*;
(
     input clk
    ,input rst

    ,input  logic                       new_flow_val
    ,input  logic   [FLOWID_W-1:0]      new_flow_flowid
    ,input  logic   [`ACK_NUM_W-1:0]    new_flow_our_ack_num

    ,output logic                       tx_timeout_rx_state_rd_req_val
    ,output logic   [FLOWID_W-1:0]      tx_timeout_rx_state_rd_req_addr
    ,input  logic                       rx_state_tx_timeout_rd_req_rdy

    ,input  logic                       rx_state_tx_timeout_rd_resp_val
    ,input  smol_rx_state_struct        rx_state_tx_timeout_rd_resp_data
    ,output logic                       tx_timeout_rx_state_rd_resp_rdy

    ,output logic                       tx_timeout_tx_sched_cmd_val
    ,output sched_cmd_struct            tx_timeout_tx_sched_cmd_data
    ,input  logic                       tx_sched_tx_timeout_cmd_rdy
);

    typedef enum logic [2:0] {
        FIND_NEXT = 3'd0,
        RD_ACK_STATE = 3'd1,
        STORE_ACK_STATE = 3'd2,
        RD_TIMER = 3'd3,
        COMPUTE = 3'd4,
        WRITE_SCHED = 3'd5,
        WRITE_STATE = 3'd6,
        UND = 'X
    } state_e;

    typedef struct packed {
        logic   [TIMESTAMP_W-1:0]   timestamp;
        logic   [`ACK_NUM_W-1:0]    last_seen_ack;
    } timeout_state_struct;

    localparam TIMEOUT_STATE_STRUCT_W = $bits(timeout_state_struct);

    state_e state_reg;
    state_e state_next;

    logic   [MAX_FLOW_CNT-1:0] active_bitvec_reg;
    logic   [MAX_FLOW_CNT-1:0] active_bitvec_next;

    logic                       wr_state_val;
    timeout_state_struct        wr_state_data;
    logic   [FLOWID_W-1:0]      wr_state_addr;
    
    logic                       update_state_val;

    logic                       rd_state_val;
    logic   [FLOWID_W-1:0]      rd_state_addr;
    timeout_state_struct        rd_state_data;

    logic                       ram_rdy;

    logic   [FLOWID_W-1:0]      bitvec_index_reg;
    logic   [FLOWID_W-1:0]      bitvec_index_next;
    logic                       incr_bitvec_index;
    
    logic   [TIMESTAMP_W-1:0]   timestamp_reg;

    smol_rx_state_struct        rx_state_reg;
    smol_rx_state_struct        rx_state_next;
    logic                       store_rx_state;

    sched_cmd_struct            sched_cmd_reg;
    sched_cmd_struct            sched_cmd_next;
    sched_cmd_struct            sched_cmd;

    timeout_state_struct        next_state_reg;
    timeout_state_struct        next_state_next;
    timeout_state_struct        next_state;

    logic                       store_calc;

    logic                       timer_exp;

    always_comb begin
        active_bitvec_next = active_bitvec_reg;
        if (new_flow_val) begin
            active_bitvec_next[new_flow_flowid] = 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= FIND_NEXT;
            active_bitvec_reg <= '0;
            bitvec_index_reg <= '0;
            timestamp_reg <= '0;
        end
        else begin
            state_reg <= state_next;
            active_bitvec_reg <= active_bitvec_next;
            bitvec_index_reg <= bitvec_index_next;
            timestamp_reg <= timestamp_reg + 1'b1;
            rx_state_reg <= rx_state_next;
            sched_cmd_reg <= sched_cmd_next;
            next_state_reg <= next_state_next;
        end
    end

    assign rx_state_next = store_rx_state
                            ? rx_state_tx_timeout_rd_resp_data
                            : rx_state_reg;

    assign bitvec_index_next = incr_bitvec_index
                            ? bitvec_index_reg == (MAX_FLOW_CNT - 1)
                                ? '0
                                : bitvec_index_reg + 1'b1
                            : bitvec_index_reg;

    assign ram_rdy = ~new_flow_val;

    assign rd_state_addr = bitvec_index_reg;

    timeout_state_struct new_state;
    assign new_state.timestamp = timestamp_reg +  RT_TIMEOUT_CYCLES;
    assign new_state.last_seen_ack = new_flow_our_ack_num;

    assign tx_timeout_rx_state_rd_req_addr = bitvec_index_reg;

    assign tx_timeout_tx_sched_cmd_data = sched_cmd_reg;

    assign timer_exp = (rd_state_data.last_seen_ack == rx_state_reg.our_ack_state.ack_num) &
                       (rd_state_data.timestamp <= timestamp_reg);

    assign sched_cmd_next = store_calc
                        ? sched_cmd
                        : sched_cmd_reg;

    assign next_state_next = store_calc
                            ? next_state
                            : next_state_reg;

    always_comb begin
        sched_cmd = '0;
        sched_cmd.flowid = bitvec_index_reg;
        sched_cmd.ack_pend_set_clear.cmd = NOP;
        sched_cmd.ack_pend_set_clear.timestamp = '0;
        sched_cmd.data_pend_set_clear.cmd = NOP;
        sched_cmd.data_pend_set_clear.timestamp = '0;

        sched_cmd.rt_pend_set_clear.timestamp = '0;
        sched_cmd.rt_pend_set_clear.cmd = timer_exp 
                                    ? SET
                                    : NOP;
    end

    always_comb begin
        next_state = rd_state_data;
        next_state.last_seen_ack = rx_state_reg.our_ack_state.ack_num;

        if (rd_state_data.last_seen_ack != rx_state_reg.our_ack_state.ack_num) begin
            next_state.timestamp = timestamp_reg + RT_TIMEOUT_CYCLES;
        end
        else begin
            next_state.timestamp = rd_state_data.timestamp;
        end
    end

    prio0_mux #(
        .DATA_W (TIMEOUT_STATE_STRUCT_W + FLOWID_W)
    ) new_state_mux (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.src0_val  (new_flow_val                   )
        ,.src0_data ({new_state, new_flow_flowid}   )
        ,.src0_rdy  ()
    
        ,.src1_val  (update_state_val   )
        ,.src1_data ({next_state_reg, bitvec_index_reg} )
        ,.src1_rdy  ()
    
        ,.dst_val   (wr_state_val   )
        ,.dst_data  ({wr_state_data, wr_state_addr} )
        ,.dst_rdy   ()
    );
    
    ram_1r1w_sync #(
         .DATA_W    (TIMEOUT_STATE_STRUCT_W )
        ,.DEPTH     (MAX_FLOW_CNT           )
    ) timeout_state (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.wr_en_a   (wr_state_val   )
        ,.wr_addr_a (wr_state_addr  )
        ,.wr_data_a (wr_state_data  )
    
        ,.rd_en_a   (rd_state_val   )
        ,.rd_addr_a (rd_state_addr  )
    
        ,.rd_data_a (rd_state_data  )
    );

    // control stuff
    always_comb begin
        rd_state_val = 1'b0;
        store_rx_state = 1'b0;
        incr_bitvec_index = 1'b0;
        tx_timeout_rx_state_rd_req_val = 1'b0;
        tx_timeout_rx_state_rd_resp_rdy = 1'b0;
        tx_timeout_tx_sched_cmd_val = 1'b0;
        update_state_val = 1'b0;
        store_calc = 1'b0;
        state_next = state_reg;
        case (state_reg)
            FIND_NEXT: begin
                if (active_bitvec_reg[bitvec_index_reg]) begin
                    state_next = RD_ACK_STATE;
                end
                else begin
                    incr_bitvec_index = 1'b1;
                end
            end
            RD_ACK_STATE: begin
                tx_timeout_rx_state_rd_req_val = 1'b1;
                if (rx_state_tx_timeout_rd_req_rdy) begin
                    state_next = STORE_ACK_STATE;
                end
            end
            STORE_ACK_STATE: begin
                store_rx_state = 1'b1;
                tx_timeout_rx_state_rd_resp_rdy = 1'b1;
                if (rx_state_tx_timeout_rd_resp_val) begin
                    state_next = RD_TIMER;
                end
            end
            RD_TIMER: begin
                if (ram_rdy) begin
                    rd_state_val = 1'b1;
                    state_next = COMPUTE;
                end
            end
            COMPUTE: begin
                store_calc = 1'b1;
                state_next = WRITE_SCHED;
            end
            WRITE_SCHED: begin
                if (sched_cmd_reg.rt_pend_set_clear.cmd == SET) begin
                    tx_timeout_tx_sched_cmd_val = 1'b1;
                    if (tx_sched_tx_timeout_cmd_rdy) begin
                        state_next = WRITE_STATE;
                    end
                end
                else begin
                    state_next = WRITE_STATE;
                end
            end
            WRITE_STATE: begin
                if (ram_rdy) begin
                    incr_bitvec_index = 1'b1;
                    update_state_val = 1'b1;
                    state_next = FIND_NEXT;
                end
            end
        endcase
    end

endmodule
