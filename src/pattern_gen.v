module pattern_gen(
    input           clock,
    input           n_reset,
    input           start,
    output          h_sync, // Hsync
    output          v_sync, // Vsync 
    output reg      d_en,
    output [7:0]    data
);

// Define states
reg [1:0] present_state, next_state;
parameter IDLE  = 2'd0;
parameter READY = 2'd1;
parameter SEND  = 2'd2;

// State flag
wire idle_flag  = (present_state == IDLE)  ? 1'b1 : 1'b0;
wire ready_flag = (present_state == READY) ? 1'b1 : 1'b0;
wire send_flag  = (present_state == SEND)  ? 1'b1 : 1'b0;

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
        IDLE  : next_state = (idle_flag  & start_posedge)          ? READY : IDLE;
        READY : next_state = (ready_flag & (ready_cnt == 2'd3))    ? SEND : READY;
        SEND  : next_state = (send_flag  & (clk_1920 == 11'd1920)) ? IDLE : SEND;
    endcase
end

// start positive edge
reg start_1d, start_2d;
wire start_posedge = start_1d & ~start_2d;
always@(negedge n_reset, posedge clock)
    if(!n_reset) begin
        start_1d <= 1'b0;
        start_2d <= 1'b0;
    end
    else begin
        start_1d <= start;
        start_2d <= start_1d;
    end

// h_sync
assign h_sync = ready_flag;

// vsync
assign v_sync = (ready_flag & (line_index == 11'b0));

// ready state counter
reg [1:0] ready_cnt;
always@(negedge n_reset, posedge clock)
    if(!n_reset)
        ready_cnt <= 2'b0;
    else
        ready_cnt <= (ready_flag) ? ready_cnt + 1'b1 : 2'b0;

// Date enable clock counter
reg [10:0] clk_1920;
always@(negedge n_reset, posedge clock)
    if(!n_reset)
        clk_1920 <= 11'b0;
    else
        clk_1920 <= (~d_en) ? 11'b0 :
                    (clk_1920 == 11'd1920) ? 11'b0 : clk_1920 + 1'b1;

// Data enable
always@(negedge n_reset, posedge clock)
    if(!n_reset)
        d_en <= 1'b0;
    else
        d_en <= (idle_flag) ? 1'b0 :
                (send_flag & (clk_1920 != 11'd1920)) ? 1'b1 : 1'b0;

// 7-clock counter
reg [2:0] clk_7;
always@(negedge n_reset, posedge clock)
    if(!n_reset)
        clk_7 <= 3'b0;
    else
        clk_7 <= (~d_en) ? 3'b0 :
                 (clk_7 == 3'd6 | (clk_1920 == 11'd1919)) ? 3'b0 : clk_7 + 1'b1;

// clk_7 index
reg [8:0] clk7_index;
always@(negedge n_reset, posedge clock)
    if(!n_reset)
        clk7_index <= 9'b0;
    else
        clk7_index <= (~d_en | (clk_1920 == 11'd1919)) ? 9'b0 :
                      (clk_7 == 3'd6) ? clk7_index + 1'b1 : clk7_index;

// pixel_data -> 0: black, 128: gray, 254: white
reg [7:0] pixel_data;
always@(negedge n_reset, posedge clock)
    if(!n_reset)
        pixel_data <= 8'b0;
    else
        pixel_data <= (~d_en | (pixel_data == 8'd255) | (clk7_index < 9'd9) | (clk7_index >= 9'd264)) ? 8'b0 :
                      (clk_7 == 3'd6) ? pixel_data + 1'b1 : pixel_data;

assign data = pixel_data;

// Line index
reg [10:0] line_index;
always@(negedge n_reset, posedge clock)
    if(!n_reset)
        line_index <= 11'b0;
    else
        line_index <= (clk_1920 == 11'd1919) ? 
                      ((line_index == 11'd1079) ? 11'b0 : line_index + 1'b1) : line_index; 

endmodule
