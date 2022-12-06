package tcp_misc_pkg;
    `include "packet_defs.vh"
    import packet_struct_pkg::*;
    import tcp_pkg::*;
    
    typedef enum logic [1:0]{
        SET = 2'b0,
        CLEAR = 2'b1,
        NOP = 2'd2
    } sched_cmd_e;
    
    typedef struct packed {
        sched_cmd_e                 cmd;
        logic   [TIMESTAMP_W-1:0]   timestamp;
    } sched_flag_cmd_struct;
    localparam SCHED_FLAG_CMD_STRUCT_W = $bits(sched_flag_cmd_struct);

    typedef struct packed {
        logic   [FLOWID_W-1:0]  flowid;
        sched_flag_cmd_struct   rt_pend_set_clear;
        sched_flag_cmd_struct   ack_pend_set_clear;
        sched_flag_cmd_struct   data_pend_set_clear;
    } sched_cmd_struct;
    localparam SCHED_CMD_STRUCT_W = FLOWID_W + (3*$bits(sched_flag_cmd_struct));
    
    typedef struct packed {
        logic                       flag;
        logic   [TIMESTAMP_W-1:0]   timestamp;
    } sched_flag_data_struct;
    localparam SCHED_FLAG_STRUCT_W = $bits(sched_flag_data_struct);

    typedef struct packed {
        logic   [FLOWID_W-1:0]  flowid;
        sched_flag_data_struct  rt_flag;
        sched_flag_data_struct  ack_pend_flag;
        sched_flag_data_struct  data_pend_flag;
    } sched_data_struct;
    localparam SCHED_DATA_STRUCT_W = FLOWID_W + (3*$bits(sched_flag_data_struct));


    typedef struct packed {
        tcp_pkt_hdr                 pkt_hdr;
        logic   [FLOWID_W-1:0]      flowid;
        smol_payload_buf_struct     payload;
        logic   [`IP_ADDR_W-1:0]    src_ip; 
        logic   [`IP_ADDR_W-1:0]    dst_ip;
    } send_pkt_struct;
    localparam SEND_PKT_STRUCT_W = $bits(send_pkt_struct);
endpackage
