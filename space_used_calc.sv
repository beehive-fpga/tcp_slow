module space_used_calc #(
    parameter PTR_W = -1
)
(
     input  logic   [PTR_W:0]   lead_ptr
    ,input  logic   [PTR_W:0]   trail_ptr
    
    ,output logic   [PTR_W:0]   space_used_calc
);

    always_comb begin
        if (lead_ptr < trail_ptr) begin
            space_used_calc = (1<<PTR_W) - trail_ptr + lead_ptr;
        end
        else begin
            space_used_calc = lead_ptr - trail_ptr;
        end
    end
endmodule