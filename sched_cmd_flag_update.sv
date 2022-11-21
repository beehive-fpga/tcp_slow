module sched_cmd_flag_update 
import tcp_misc_pkg::*;
(
     input sched_cmd_e  cmd
    ,input logic        curr_flag

    ,output logic       next_flag
);

    assign next_flag = cmd == SET
                        ? 1'b1
                        : cmd == CLEAR
                            ? 1'b0
                            : curr_flag;
endmodule
