package buf_mgmt_pkg;
import tcp_pkg::*;
    typedef enum logic[1:0] {
        NEW_FLOW = 2'd0
    } cmd_e;

    typedef struct packed {
        cmd_e cmd;
        logic [FLOWID_W-1:0]    flowid;
    } buf_mgmt_cmd;
endpackage