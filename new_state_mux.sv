module new_state_mux #(
    parameter DATA_W = -1
)(
     input  logic                   new_state_val
    ,input  logic   [DATA_W-1:0]    new_state_data
    ,output logic                   new_state_rdy

    ,input  logic                   update_state_val
    ,input  logic   [DATA_W-1:0]    update_state_data
    ,output logic                   update_state_rdy

    ,output logic                   wr_state_val
    ,output logic   [DATA_W-1:0]    wr_state_data
    ,input  logic                   wr_state_rdy
);

    assign wr_state_val = new_state_val | update_state_val;

    assign wr_state_data = new_state_val
                        ? new_state_data
                        : update_state_data;
    assign new_state_rdy = wr_state_rdy;

    assign update_state_rdy = ~new_state_val & wr_state_rdy;
endmodule
