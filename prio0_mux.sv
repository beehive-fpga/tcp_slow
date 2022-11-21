module prio0_mux #(
    parameter DATA_W = -1
)(
     input clk
    ,input rst

    ,input  logic                   src0_val
    ,input  logic   [DATA_W-1:0]    src0_data
    ,output logic                   src0_rdy

    ,input  logic                   src1_val
    ,input  logic   [DATA_W-1:0]    src1_data
    ,output logic                   src1_rdy

    ,output logic                   dst_val
    ,output logic   [DATA_W-1:0]    dst_data
    ,input  logic                   dst_rdy
);

    assign dst_val = src0_val | src1_val;
    
    assign dst_data = src0_val
                    ? src0_data
                    : src1_data;

    assign src0_rdy = dst_rdy;
    assign src1_rdy = ~src0_val & dst_rdy;
endmodule
