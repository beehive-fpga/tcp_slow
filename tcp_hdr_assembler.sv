`include "packet_defs.vh"
import packet_struct_pkg::*;
import tcp_pkg::*;

module tcp_hdr_assembler(
     input                      tcp_hdr_req_val
    ,input  [`PORT_NUM_W-1:0]   host_port
    ,input  [`PORT_NUM_W-1:0]   dest_port
    ,input  [`SEQ_NUM_W-1:0]    seq_num
    ,input  [`ACK_NUM_W-1:0]    ack_num
    ,input  [`FLAGS_W-1:0]      flags
    ,input  [PAYLOAD_PTR_W:0]   window
    ,output                     tcp_hdr_req_rdy

    ,output                     outbound_tcp_hdr_val
    ,input                      outbound_tcp_hdr_rdy
    ,output tcp_pkt_hdr         outbound_tcp_hdr

);

    tcp_pkt_hdr outbound_tcp_hdr_struct;
    
    assign outbound_tcp_hdr = outbound_tcp_hdr_struct;
    assign outbound_tcp_hdr_val = tcp_hdr_req_val;
    
    assign tcp_hdr_req_rdy = outbound_tcp_hdr_rdy;
    
    logic   [PAYLOAD_PTR_W:0]   max_window;
    logic   [`WIN_SIZE_W-1:0]   scaled_window;
    assign max_window = 1 << `WIN_SIZE_W;

    assign scaled_window = window >= max_window
                        ? max_window - 1
                        : window;
    
    always @(*) begin
        if (tcp_hdr_req_val) begin
            outbound_tcp_hdr_struct.src_port = host_port;
            outbound_tcp_hdr_struct.dst_port = dest_port;
            // because we're using 16 byte payloads
            // Add 1 for the SYN-ACK we sent
            outbound_tcp_hdr_struct.seq_num = seq_num;
            outbound_tcp_hdr_struct.ack_num = ack_num;
            outbound_tcp_hdr_struct.flags = flags;
    
            outbound_tcp_hdr_struct.chksum = `TCP_CHKSUM_W'b0;
    
            outbound_tcp_hdr_struct.raw_data_offset = TCP_HDR_BYTES >> 2;
            outbound_tcp_hdr_struct.reserved = `RESERVED_W'b0;
            outbound_tcp_hdr_struct.urg_pointer = `URG_W'b0;
        
            outbound_tcp_hdr_struct.win_size = scaled_window;
    
        end
        else begin
            outbound_tcp_hdr_struct = '0;
        end
    end

endmodule
