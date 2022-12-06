`include "packet_defs.vh"
// This module generates the ACK number for the receiving stream which will be sent with 
// outgoing packets
module their_ack_process 
import tcp_pkg::*;
(
     input  logic   [`ACK_NUM_W-1:0]            their_curr_ack_num
    ,input  logic   [`SEQ_NUM_W-1:0]            packet_seq_num
    ,input  logic   [PAYLOAD_ENTRY_LEN_W-1:0]   packet_payload_len
    ,input  logic   [RX_PAYLOAD_PTR_W:0]        rx_tail_ptr
    ,input  logic   [RX_PAYLOAD_PTR_W:0]        rx_head_ptr

    ,output logic   [`ACK_NUM_W-1:0]            their_next_ack_num
    ,output logic                               accept_payload 
    ,output logic   [RX_PAYLOAD_PTR_W:0]        next_rx_tail_ptr
    ,output logic   [RX_PAYLOAD_PTR_W:0]        our_win
);


    logic   [RX_PAYLOAD_PTR_W:0]    rx_buf_space_used;
    logic   [RX_PAYLOAD_PTR_W:0]    rx_buf_space_left;
    logic                           rx_buf_has_space;

    assign rx_buf_space_used = rx_tail_ptr - rx_head_ptr;
    assign rx_buf_space_left = {1'b1, {(RX_PAYLOAD_PTR_W){1'b0}}} - rx_buf_space_used;
    assign rx_buf_has_space = rx_buf_space_left >= packet_payload_len;


    // we're calculating ack numbers here by bytes rather than straight packet numbers
    // this can be modified later
    always_comb begin
        their_next_ack_num = their_curr_ack_num;
        next_rx_tail_ptr = rx_tail_ptr;
        our_win = rx_buf_space_left;
        accept_payload = 1'b0;

        // if we've received the packet we expect, then ack for the next byte
        if (rx_buf_has_space & (packet_seq_num == their_curr_ack_num)) begin
            accept_payload = 1'b1;
            their_next_ack_num = packet_seq_num + packet_payload_len;
            next_rx_tail_ptr = rx_tail_ptr + packet_payload_len;
            our_win = rx_buf_space_left - packet_payload_len;
        end
        // we're somehow out of order...just dup ack
        else begin
            accept_payload = 1'b0;
            their_next_ack_num = their_curr_ack_num;
            next_rx_tail_ptr = rx_tail_ptr;
            our_win = rx_buf_space_left;
        end
    end
endmodule
