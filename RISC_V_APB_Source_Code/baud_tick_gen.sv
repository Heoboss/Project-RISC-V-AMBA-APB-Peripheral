`timescale 1ns / 1ps

module baud_tick_gen(
    input clk,
    input rst,
    output baud_tick
    );
    
    parameter BAUD_RATE = 9600; //BAUD_RATE_19200=19200;
    
    //sampling rate를 16배로 올려보자
    localparam BAUD_COUNT = 100_000_000/(BAUD_RATE*16); //16배 baud tick 속도 상승
    
    
    
    reg [$clog2(BAUD_COUNT)-1:0] count_reg, count_next;
    reg tick_reg, tick_next;

    assign baud_tick = tick_reg;
    
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            tick_reg <=0;
            count_reg <=0;
        end else begin
            tick_reg <= tick_next;
            count_reg <= count_next;
        end
    end

    //100MHz 1 tick을 9600bps로 만듬
    always @(*) begin
        tick_next = 1'b0;
        count_next = count_reg;
        if(count_next == BAUD_COUNT -1) begin
            tick_next = 1'b1;
            count_next = 0;
        end else begin
            tick_next= 1'b0;
            count_next=count_reg +1;
        end
    end

endmodule