module sched_cmd_flag_update 
import tcp_misc_pkg::*;
(
     input sched_flag_cmd_struct    flag_cmd
    ,input sched_flag_data_struct   curr_flag_state

    ,output sched_flag_data_struct  next_flag_state
);

    always_comb begin
        next_flag_state = curr_flag_state;
        case (flag_cmd.cmd)
            SET: begin
                next_flag_state.flag = 1'b1;
                next_flag_state.timestamp = curr_flag_state + 1'b1;
            end
            CLEAR: begin
                // if the cmd came in with an old timestamp, leave it alone
                if (flag_cmd.timestamp < curr_flag_state.timestamp) begin
                    next_flag_state = curr_flag_state;
                end
                else begin
                    next_flag_state.flag = 1'b0;
                    next_flag_state.timestamp = curr_flag_state.timestamp;
                end
            end
            NOP: begin
                next_flag_state = curr_flag_state;
            end
        endcase
    end

//    assign next_flag_state.timestamp = curr_flag_state.timestamp;
//    assign next_flag_state.flag = flag_cmd.cmd == SET
//                                ? 1'b1
//                                : flag_cmd.cmd == CLEAR
//                                    ? 1'b0
//                                    : curr_flag_state.flag;
endmodule
