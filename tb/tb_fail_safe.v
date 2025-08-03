module tb_fail_safe;

reg             clock, n_reset;
reg     [11:0]  active_width;
reg     [10:0]  line_num;
wire            Line_High_err;
wire            Line_Low_err;
wire            width_High_err;
wire            width_Low_err;
wire            OK;

always #2.5 clock = ~clock;

initial begin
     n_reset = 0;
     clock = 0;

#100 n_reset = 1;
end

fail_safe #(
    .ACTIVE_WIDTH       (12'd1920),
    .LINE_NUM           (11'd1080)
) t0(
    .clock              (clock),
    .n_reset            (n_reset),
    .active_width       (12'd1920),
    .line_num           (11'd1080),
    .Line_High_err      (Line_High_err),
    .Line_Low_err       (Line_Low_err),
    .width_High_err     (width_High_err),
    .width_Low_err      (width_Low_err),
    .OK                 (OK)
);

initial begin
    $dumpfile("tb_fail_safe.vcd");
    $dumpvars(0, tb_fail_safe);
    #19000000
    $finish;
end

endmodule
