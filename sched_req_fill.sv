module sched_req_fill 
import tcp_pkg::*;
import tcp_misc_pkg::*;
(
     input  logic   [FLOWID_W-1:0]  flowid
    ,output sched_cmd_struct        filled_req
);
    always_comb begin
        filled_req = '0;

        filled_req.flowid = flowid;

        filled_req.rt_pend_set_clear.timestamp = '0;
        filled_req.ack_pend_set_clear.timestamp = '0;
        filled_req.data_pend_set_clear.timestamp = '0;

        filled_req.rt_pend_set_clear.cmd = NOP;
        filled_req.ack_pend_set_clear.cmd = NOP;
        filled_req.data_pend_set_clear.cmd = SET;
    end
endmodule
