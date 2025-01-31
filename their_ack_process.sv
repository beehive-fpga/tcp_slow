`include "packet_defs.vh"
// This module generates the ACK number for the receiving stream which will be sent with 
// outgoing packets
module their_ack_process 
import tcp_pkg::*;
(
     input  logic   [`ACK_NUM_W-1:0]            their_curr_ack_num
    ,input  logic   [`SEQ_NUM_W-1:0]            packet_seq_num
    ,input  logic   [PAYLOAD_ENTRY_LEN_W-1:0]   packet_payload_len
    ,input  logic   [RX_PAYLOAD_IDX_W:0]        rx_tail_idx
    ,input  logic   [RX_PAYLOAD_IDX_W:0]        rx_head_idx
    ,input  logic                               malloc_success
    ,input  logic   [RX_PAYLOAD_PTR_W:0]        malloc_approx_space

    ,output logic   [`ACK_NUM_W-1:0]            their_next_ack_num
    ,output logic                               accept_payload 
    ,output logic   [RX_PAYLOAD_IDX_W:0]        next_rx_tail_idx
    ,output logic   [RX_PAYLOAD_PTR_W:0]        our_win
);


    logic   [RX_PAYLOAD_IDX_W:0]    rx_buf_idx_used;
    logic   [RX_PAYLOAD_IDX_W:0]    rx_buf_idx_left;
    logic                           rx_buf_has_idx;

    assign rx_buf_idx_used = rx_tail_idx - rx_head_idx;
    assign rx_buf_idx_left = {1'b1, {(RX_PAYLOAD_IDX_W){1'b0}}} - rx_buf_idx_used;
    assign rx_buf_has_idx = rx_buf_idx_left >= 1;


    // we're calculating ack numbers here by bytes rather than straight packet numbers
    // this can be modified later
    always_comb begin
        their_next_ack_num = their_curr_ack_num;
        next_rx_tail_idx = rx_tail_idx;
        our_win = malloc_approx_space;
        accept_payload = 1'b0;

        // if we've received the packet we expect, then ack for the next byte
        if (malloc_success & rx_buf_has_space & (packet_seq_num == their_curr_ack_num)) begin
            accept_payload = 1'b1;
            their_next_ack_num = packet_seq_num + packet_payload_len;
            next_rx_tail_idx = rx_tail_idx + 1;
            our_win = malloc_approx_space - packet_payload_len;
        end
        // we're somehow out of order...just dup ack
        else begin
            accept_payload = 1'b0;
            their_next_ack_num = their_curr_ack_num;
            next_rx_tail_idx = rx_tail_idx;
            our_win = malloc_approx_space;
        end
    end
endmodule
