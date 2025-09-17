package buf_mgmt_pkg;
    import tcp_pkg::*;

    // FIXME: need to implement connection teardown
    typedef enum logic {
        NEW_FLOW = 1'b0,
        FREE_FLOW = 1'b1
    } buf_cmd_e;

    typedef struct packed {
        logic   [FLOWID_W-1:0]  flowid;
        buf_cmd_e               cmd;        
    } buf_mgmt_cmd;

endpackage