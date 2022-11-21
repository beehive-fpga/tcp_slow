package tcp_misc_pkg;
    `include "packet_defs.vh"
    import tcp_pkg::*;
    
    typedef enum logic [1:0]{
        SET = 2'b0,
        CLEAR = 2'b1,
        NOP = 2'd2
    } sched_cmd_e;

    typedef struct packed {
        logic   [FLOWID_W-1:0]  flowid;
        sched_cmd_e             rt_pend_set_clear;
        sched_cmd_e             ack_pend_set_clear;
        sched_cmd_e             data_pend_set_clear;
    } sched_cmd_struct;
    localparam SCHED_CMD_STRUCT_W = FLOWID_W + ($bits(sched_cmd_e) * 3)

    typedef struct packed {
        logic   [FLOWID_W-1:0]  flowid;
        logic                   rt_flag;
        logic                   ack_pend_flag;
        logic                   data_pend_flag;
    } sched_data_struct;
    localparam SCHED_DATA_STRUCT_W = FLOWID_W + 3;

    typedef struct packed {
        tcp_pkt_hdr                 pkt_hdr;
        smol_payload_buf_struct     payload;
        logic   [`IP_ADDR_W-1:0]    src_ip; 
        logic   [`IP_ADDR_W-1:0]    dst_ip;
    } send_pkt_struct;
    localparam SEND_PKT_STRUCT_W = $bits(send_pkt_struct);
endpackage
