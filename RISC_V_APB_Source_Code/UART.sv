`timescale 1ns / 1ps

module UART_Periph (
    // global signal
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,

    input logic rx,
    output logic tx
);

    logic empty_TX, full_TX;
    logic empty_RX, full_RX;
    logic we_TX, re_RX;
    logic tick;
    logic [7:0] wdata_TX, rdata_TX;
    logic [7:0] wdata_RX, rdata_RX;
    logic rx_done;
    logic o_tx_done;

    uart_SlaveIntf U_uart_Intf (
        .*,
        .FSR_TX({full_TX, empty_TX}),
        .FSR_RX({full_RX, empty_RX}),
        .FWD(wdata_TX),
        .FRD(rdata_RX)
        );

    fifo fifo_tx (
        .clk(PCLK),
        .reset(PRESET),
        .we(we_TX),
        .re(!empty_TX & !o_tx_done),
        .wdata(wdata_TX),
        .rdata(rdata_TX),
        .empty(empty_TX),
        .full(full_TX)
    );

    fifo fifo_rx (
        .clk(PCLK),
        .reset(PRESET),
        .we(rx_done),
        .re(re_RX),
        .wdata(wdata_RX),
        .rdata(rdata_RX),
        .empty(empty_RX),
        .full(full_RX)
    );
    rx RX(
        .*,
        .clk(PCLK),
        .rst(PRESET),
        .rx_data(wdata_RX)
    );

    tx TX(
        .*,
        .clk(PCLK),
        .rst(PRESET),
        .i_data(rdata_TX),
        .tx_start(!empty_TX)
    );

    baud_tick_gen U_BAUD_TICK_GEN(
        .clk(PCLK),
        .rst(PRESET),
        .baud_tick(tick)
    );
endmodule

module uart_SlaveIntf (
    // global signal
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // internal signals
    input  logic [ 1:0] FSR_TX,
    input  logic [ 1:0] FSR_RX,
    output logic [ 7:0] FWD,
    input  logic [ 7:0] FRD,
    output logic        we_TX,
    output logic        re_RX
);
    logic [31:0] slv_reg0, slv_reg1, slv_reg2, slv_reg3;
    logic [31:0] slv_reg2_next;


    logic we_reg, we_next;
    logic re_reg, re_next;
    logic [31:0] PRDATA_reg, PRDATA_next;
    logic PREADY_reg, PREADY_next;

    assign we_TX = we_reg;
    assign re_RX = re_reg;

    typedef enum {
        IDLE,
        READ,
        WRITE,
        HOLD
    } state_e;

    state_e state_reg, state_next;

    assign slv_reg0[1:0] = FSR_TX;
    assign slv_reg1[1:0] = FSR_RX;
    assign FWD = slv_reg2[7:0];
    assign slv_reg3[7:0] = FRD; 

    assign PRDATA = PRDATA_reg;
    assign PREADY = PREADY_reg;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            slv_reg0[31:2] <=0; //FSR_TX 
            slv_reg1[31:2] <=0; //FSR_RX
            slv_reg3[31:8] <=0;
            slv_reg2 <=0;
            state_reg <= IDLE;
            we_reg    <= 0;
            re_reg    <= 0;
            PRDATA_reg <= 32'bx;
            PREADY_reg <= 1'b0;
        end else begin
            slv_reg2  <= slv_reg2_next;
            state_reg <= state_next;
            we_reg    <= we_next;
            re_reg    <= re_next;
            PRDATA_reg <= PRDATA_next;
            PREADY_reg <= PREADY_next;
        end
    end


    always_comb begin
        state_next = state_reg;
        slv_reg2_next = slv_reg2;
        we_next = we_reg;
        re_next = re_reg;
        PRDATA_next = PRDATA_reg;
        PREADY_next = PREADY_reg;

        case (state_reg)
            IDLE: begin
                PREADY_next = 1'b0;
                if (PSEL && PENABLE) begin
                    if (PWRITE) begin
                        state_next= WRITE;
                        we_next = 1'b1;
                        re_next = 1'b0;
                        PREADY_next = 1'b1;
                        case (PADDR[3:2])
                            2'd0: ;
                            2'd1: ;
                            2'd2: begin
                                slv_reg2_next = PWDATA;
                            end
                            2'd2: ;
                        endcase
                    end else begin
                        state_next= READ;
                        PREADY_next = 1'b1;
                        we_next = 1'b0;
                        case (PADDR[3:2])
                            2'd0: begin
                                PRDATA_next = slv_reg0;
                                re_next = 1'b0;
                            end
                            2'd1: begin
                                PRDATA_next = slv_reg1;
                                re_next = 1'b0;
                            end
                            2'd2: begin
                                PRDATA_next = slv_reg2;
                                re_next = 1'b0;
                            end
                            2'd3: begin
                                PRDATA_next = slv_reg3;
                                re_next = 1'b1;
                            end
                        endcase
                    end
                end
            end

            READ: begin
                re_next = 1'b0;
                we_next = 1'b0;
                PREADY_next = 1'b0;
                state_next = HOLD; 
            end
            WRITE: begin
                we_next =1'b0;
                re_next = 1'b0;
                state_next = HOLD;
                PREADY_next = 1'b0;
            end
            HOLD: begin
                we_next =1'b0;
                re_next = 1'b0;
                state_next = IDLE;
                PREADY_next = 1'b0; 
            end
        endcase
    end
endmodule