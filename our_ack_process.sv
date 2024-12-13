`include "packet_defs.vh"
module our_ack_process 
import tcp_pkg::*;
(
     input  logic   [`ACK_NUM_W-1:0]            pkt_ack_num
    ,input  logic   [`SEQ_NUM_W-1:0]            our_curr_seq_num
    ,input  ack_state_struct                    our_curr_ack_state
    ,input  logic    [PAYLOAD_ENTRY_LEN_W-1:0]  pkt_payload_len

    ,output ack_state_struct                    our_next_ack_state
    ,output logic                               set_rt_flag
    
    ,output logic   [TX_PAYLOAD_PTR_W:0]        next_tx_head_ptr
);
    logic   [`ACK_NUM_W-1:0]    our_curr_ack_num;
    logic   [RT_ACK_THRESHOLD_W-1:0]    our_curr_ack_cnt;
    logic   [RT_ACK_THRESHOLD_W-1:0]    next_ack_cnt;

    logic   dup_ack;
    logic   data_unacked;
    logic   update_ack;

    assign our_curr_ack_num = our_curr_ack_state.ack_num;
    assign our_curr_ack_cnt = our_curr_ack_state.dup_ack_cnt;

    assign data_unacked = ~(our_curr_seq_num == our_curr_ack_num);

    assign our_next_ack_state.ack_num = update_ack
                            ? pkt_ack_num
                            : our_curr_ack_num;
    assign our_next_ack_state.dup_ack_cnt = next_ack_cnt;

    assign next_tx_head_ptr = our_next_ack_state.ack_num[TX_PAYLOAD_PTR_W:0];

    // FIXME: RFC 5681, section 2 gives the full definition of duplicate ACKs,
    // probably check all the conditions eventually https://datatracker.ietf.org/doc/html/rfc5681#section-2
    assign dup_ack = (our_curr_ack_num == pkt_ack_num) && data_unacked && (pkt_payload_len == 0);

    always_comb begin
        update_ack = 1'b0;
        // if the sequence number has wrapped, but the ack number hasn't yet
        // if there's actually data waiting to be ACKed, the ACK is valid if
        // it is either greater than the current ACK num (so between ACK and max
        // SEQ num) or less than or equal to the current SEQ num plus 1
        // (so between 0 and the current SEQ num)
        if (our_curr_seq_num < our_curr_ack_num) begin
            if (data_unacked 
             & ((pkt_ack_num > our_curr_ack_num)
             |  (pkt_ack_num <= our_curr_seq_num + 1))) begin
                update_ack = 1'b1;
            end
        end
        else begin
            // if there's actually data waiting to be ACKed and the ACK is
            // valid (greater than last received ACK, less than sent SEQ num + 1)
            if (data_unacked 
             & ((pkt_ack_num > our_curr_ack_num) 
             & (pkt_ack_num <= our_curr_seq_num + 1))) begin
                update_ack = 1'b1;
            end
        end
    end

    always_comb begin
        next_ack_cnt = our_curr_ack_cnt;
        if (~data_unacked | set_rt_flag | ~dup_ack) begin
            next_ack_cnt = '0;
        end
        else begin
            next_ack_cnt = our_curr_ack_cnt + dup_ack;
        end
    end

    assign set_rt_flag = (our_curr_ack_cnt + dup_ack) == RT_ACK_THRESHOLD;
endmodule
