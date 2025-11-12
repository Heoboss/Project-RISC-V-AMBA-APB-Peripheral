`timescale 1ns / 1ps
module tx (
    input clk,
    input rst,
    input [7:0] i_data,
    input tick,
    input tx_start,
    output tx,
    output o_tx_done
);
    parameter IDLE = 4'h0, SEND = 4'h1, START = 4'h2, DATA = 4'h3, STOP = 4'h4;

    reg [2:0] state, next;
    reg tx_reg, tx_next;
    reg tx_done_reg, tx_done_next;
    reg [3:0] bit_count_reg, bit_count_next;
    reg [3:0] tick_count_reg, tick_count_next;
    reg [7:0] temp_data_reg, temp_data_next;

    assign tx = tx_reg;
    assign o_tx_done = tx_done_reg;
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state <= 0;
            tx_reg <= 1'b1; //uart tx line을 초기에 항상 1로 만들기 위함.
            tx_done_reg <= 0;
            bit_count_reg <= 0;  // 데이터 수를 세기위함(==cnt)
            tick_count_reg <= 0; //속도를 16배 해서 틱의 개수를 세기 위함
            temp_data_reg <=0;
        end else begin
            state <= next;
            tx_reg <= tx_next;
            tx_done_reg <= tx_done_next;
            bit_count_reg <= bit_count_next;
            tick_count_reg <= tick_count_next;
            temp_data_reg <= temp_data_next;
        end
    end

    always @(*) begin
        next = state;
        tx_next = tx_reg;
        tx_done_next = tx_done_reg;
        bit_count_next = bit_count_reg;
        tick_count_next = tick_count_reg;
        temp_data_next = temp_data_reg;
        case (state)
            IDLE: begin
                tx_next = 1'b1;
                tx_done_next = 1'b0;
                if (tx_start) begin
                    next = SEND;
                    temp_data_next=i_data;
                end
            end
            SEND: begin  //첫번째 틱을 잡기 위함 START 가기 전
                if (tick == 1'b1) begin
                    next = START;
                end
            end
            START: begin
                tx_done_next = 1'b1;
                tx_next = 1'b0;
                if (tick == 1'b1) begin
                    if (tick_count_reg == 15) begin
                        bit_count_next = 1'b0; //state 넘어가기 전에 데이터 세는 거 초기화 필요
                        tick_count_next = 1'b0;
                        next = DATA;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = temp_data_reg[bit_count_reg];
                //tx_next = i_data[bit_count_reg];
                if (tick == 1'b1) begin
                    if (tick_count_reg == 15) begin
                        tick_count_next = 0;
                        if (bit_count_reg == 7) begin
                            next = STOP;
                        end else begin
                            next = DATA;
                            bit_count_next = bit_count_reg + 1;
                        end
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1'b1;
                if (tick == 1'b1) begin
                    if (tick_count_reg == 15) begin
                        next = IDLE;
                        tick_count_next = 0;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule
