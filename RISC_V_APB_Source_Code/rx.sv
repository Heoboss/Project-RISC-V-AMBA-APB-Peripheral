`timescale 1ns / 1ps

module rx(
    input clk,
    input rst,
    input rx,
    input tick,
    output [7:0] rx_data,
    output rx_done
    );

    parameter IDLE=0, START=1,DATA=2, STOP=3;
    reg [1:0] rx_state, rx_next;
    reg [7:0] rx_out_reg, rx_out_next;
    reg [3:0] tick_cnt_reg, tick_cnt_next;
    reg [3:0] data_cnt_reg, data_cnt_next;

    reg rx_done_reg, rx_done_next;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_state <=0;
            rx_done_reg <=1'b0;
            rx_out_reg <=8'bx;
            data_cnt_reg <= 8'b0;
            tick_cnt_reg <= 8'b0;
        end else begin
            rx_state <= rx_next;
            rx_out_reg <= rx_out_next;
            data_cnt_reg <= data_cnt_next;
            rx_done_reg <= rx_done_next;
            tick_cnt_reg <= tick_cnt_next;
        end
    end


    assign rx_done=rx_done_reg;
    assign rx_data= rx_out_reg;
    always @(*) begin
        rx_out_next=rx_out_reg;
        rx_next=rx_state;
        data_cnt_next=data_cnt_reg;
        rx_done_next=1'b0;
        tick_cnt_next=tick_cnt_reg;
        case(rx_state)
            IDLE: begin
                rx_done_next=1'b0;
                if (!rx) begin
                    rx_next= START;
                end
            end
            START: begin
                if(tick) begin
                    if(tick_cnt_reg == 8-1) begin
                        tick_cnt_next =0;
                        rx_next=DATA;
                    end else begin
                        tick_cnt_next = tick_cnt_reg+1;
                    end
                end
            end
            DATA: begin
                if (tick) begin
                    if (tick_cnt_reg == 16-1) begin
                        rx_out_next[data_cnt_reg]=rx;
                        tick_cnt_next = 0;
                        if (data_cnt_reg < 8-1) begin
                            data_cnt_next= data_cnt_reg+1;
                            rx_next = DATA;
                        end else begin
                            data_cnt_next =0;
                            rx_next = STOP;
                        end
                    end else begin
                        tick_cnt_next = tick_cnt_reg+1;
                    end
                end
            end
            STOP: begin
                if(tick) begin
                    if(tick_cnt_next == 16-1) begin
                        rx_done_next = 1'b1;
                        tick_cnt_next=0;
                        rx_next=IDLE;
                    end else begin
                        tick_cnt_next=tick_cnt_reg+1;
                        rx_next=STOP;
                    end                
                end
            end
        endcase
    end

endmodule