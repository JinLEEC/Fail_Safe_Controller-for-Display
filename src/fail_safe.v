module fail_safe(
    input        clock,
    input        n_reset,
    input [11:0] active_width,
    input [10:0] line_num,
    output       Line_High_err,
    output       Line_Low_err,
    output       width_High_err,
    output       width_Low_err,
    output reg   OK
);

// Parameter 
parameter ACTIVE_WIDTH = 12'd1920;
parameter LINE_NUM     = 11'd1080;

// Define states
reg [2:0] present_state, next_state;
parameter IDLE                 = 3'd0;
parameter READY                = 3'd1;
parameter EACH_LINE_DETECTION  = 3'd2;
parameter LINE_CHECK           = 3'd3;
parameter ERROR                = 3'd4;
parameter TOTAL_LINE_DETECTION = 3'd5;

// State flag
wire idle_flag     = (present_state == IDLE)                 ? 1'b1 : 1'b0;
wire ready_flag    = (present_state == READY)                ? 1'b1 : 1'b0;
wire error_flag    = (present_state == ERROR)                ? 1'b1 : 1'b0;
wire eld_flag      = (present_state == EACH_LINE_DETECTION)  ? 1'b1 : 1'b0;
wire line_che_flag = (present_state == LINE_CHECK)           ? 1'b1 : 1'b0;
wire tld_flag      = (present_state == TOTAL_LINE_DETECTION) ? 1'b1 : 1'b0;

// State update
always@(negedge n_reset, posedge clock)
    if(!n_reset)
        present_state <= IDLE;
    else
        present_state <= next_state;

// State transition
always@(*) begin
    next_state = present_state;
    case(present_state)
        IDLE                 : next_state = (idle_flag & ((active_width_in > 0) | (line_num_in > 0)))  ? READY : IDLE;
        READY                : next_state = (ready_flag & (ready_cnt == 2'd3))                         ? EACH_LINE_DETECTION : READY;
        EACH_LINE_DETECTION  : next_state = (eld_flag & (aw_clk_cnt == active_width))                  ? LINE_CHECK : EACH_LINE_DETECTION;
        LINE_CHECK           : next_state = (line_che_flag) ? 
                                            ((line_index == line_num) ? TOTAL_LINE_DETECTION :
                                             ((line_index != line_num) ? 
                                              ((aw_clk_exact) ? EACH_LINE_DETECTION :
                                               ((aw_clk_over | aw_clk_low) ? ERROR : LINE_CHECK)) : LINE_CHECK)) : LINE_CHECK;
        ERROR                : next_state = (error_flag & (error_cnt == 4'd15))                         ? IDLE : ERROR;
        TOTAL_LINE_DETECTION : next_state = (tld_flag) ? ((line_over | line_low) ? ERROR : (line_exact) ? IDLE : TOTAL_LINE_DETECTION) : TOTAL_LINE_DETECTION;
    endcase
end

// input synchronized with clock
reg [11:0] active_width_in;
reg [10:0] line_num_in;
always@(negedge n_reset, posedge clock)
    if(!n_reset) begin
        active_width_in <= 12'b0;
        line_num_in     <= 11'b0;
    end
    else begin
        active_width_in <= active_width;
        line_num_in     <= line_num;
    end

// ready state coutner
reg [1:0] ready_cnt;
always@(negedge n_reset, posedge clock)
    if(!n_reset)
        ready_cnt <= 2'b0;
    else
        ready_cnt <= (ready_flag) ? ready_cnt + 1 : 2'b0;

// eld_flag negative edge
reg eld_flag_1d, eld_flag_2d;
wire eld_flag_negedge = ~eld_flag_1d & eld_flag_2d;
always@(negedge n_reset, posedge clock)
    if(!n_reset) begin
        eld_flag_1d <= 1'b0;
        eld_flag_2d <= 1'b0;
    end
    else begin
        eld_flag_1d <= eld_flag;
        eld_flag_2d <= eld_flag_1d;
    end

// active width clock counter
reg [11:0] aw_clk_cnt;
always@(negedge n_reset, posedge clock)
    if(!n_reset)
        aw_clk_cnt <= 12'b0;
    else
        aw_clk_cnt <= (~eld_flag) ? 12'b0 : 
                      (aw_clk_over | aw_clk_low | aw_clk_exact) ? 12'b0 :
                      (aw_clk_cnt == active_width) ? 12'b0 : aw_clk_cnt + 1'b1;

// active width clock counter 2-delay -> aw_clk_cnt 의 값을 2-clock delay 시켜 eld_flag_2d 와의 타이밍을 맞추기 위함.
reg [11:0] aw_clk_cnt_1d, aw_clk_cnt_2d;
always@(negedge n_reset, posedge clock)
    if(!n_reset) begin
        aw_clk_cnt_1d <= 12'b0;
        aw_clk_cnt_2d <= 12'b0;
    end
    else begin
        aw_clk_cnt_1d <= aw_clk_cnt;
        aw_clk_cnt_2d <= aw_clk_cnt_1d;
    end

assign aw_clk_over    = (eld_flag_negedge & (aw_clk_cnt_2d > ACTIVE_WIDTH))  ? 1'b1 : 1'b0;
assign width_High_err = aw_clk_over;

assign aw_clk_low     = (eld_flag_negedge & (aw_clk_cnt_2d < ACTIVE_WIDTH)) ? 1'b1 : 1'b0;
assign width_Low_err  = aw_clk_low;

wire aw_clk_exact     = (eld_flag_negedge & (aw_clk_cnt_2d == ACTIVE_WIDTH)) ? 1'b1 : 1'b0;

// error state counter
reg [3:0] error_cnt;
always@(negedge n_reset, posedge clock)
    if(!n_reset)
        error_cnt <= 4'b0;
    else
        error_cnt <= (error_flag) ? error_cnt + 1'b1 : 4'b0;

// line index
reg [10:0] line_index;
always@(negedge n_reset, posedge clock)
    if(!n_reset)
        line_index <= 11'b0;
    else
        line_index <= (idle_flag)    ? 11'b0 :
                      (aw_clk_exact) ? line_index + 1 : line_index;

// line index 1-clock delay
reg [10:0] line_index_1d;
always@(negedge n_reset, posedge clock)
    if(!n_reset)
        line_index_1d <= 11'b0;
    else
        line_index_1d <= line_index;

wire line_low;
assign line_low = (tld_flag & (line_index_1d < LINE_NUM)) ? 1'b1 : 1'b0;
assign Line_Low_err = line_low;

wire line_over;
assign line_over = (tld_flag & (line_index_1d > LINE_NUM)) ? 1'b1 : 1'b0;
assign Line_High_err = line_over;

wire line_exact;
assign line_exact = (tld_flag & (line_index_1d == LINE_NUM)) ? 1'b1 : 1'b0;

// OK
always@(negedge n_reset, posedge clock)
    if(!n_reset)
        OK <= 1'b0;
    else
        OK <= (line_exact) ? 1'b1 : 1'b0;

endmodule
