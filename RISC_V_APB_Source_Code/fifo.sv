`timescale 1ns / 1ps

module fifo (
    input  logic       clk,
    input  logic       reset,
    input  logic       we,
    input  logic       re,
    input  logic [7:0] wdata,
    output logic [7:0] rdata,
    output logic empty,
    output logic full
);
    logic [1:0] wptr, rptr;

    fifo_ram U_FIFO_RAM (
        .clk  (clk),
        .we   (!full & we),
        .wdata(wdata),
        .waddr(wptr),
        .raddr(rptr),
        .rdata(rdata)
    );
    fifo_CU U_FIFO_CU (.*);


endmodule

module fifo_ram (
    input  logic       clk,
    input  logic       we,
    input  logic [7:0] wdata,
    input  logic [1:0] waddr,
    input  logic [1:0] raddr,
    output logic [7:0] rdata
);

    logic [7:0] mem[0:3];

    always_ff @(posedge clk) begin
        if (we) begin
            mem[waddr] <= wdata;
        end
    end

    assign rdata = mem[raddr];

endmodule


module fifo_CU (
    input  logic       clk,
    input  logic       reset,
    input  logic       we,
    input  logic       re,
    output logic       empty,
    output logic       full,
    output logic [1:0] rptr,
    output logic [1:0] wptr
);

    logic [1:0] wptr_reg, wptr_next;
    logic [1:0] rptr_reg, rptr_next;
    logic empty_reg, empty_next;
    logic full_reg, full_next;

    assign wptr  = wptr_reg;
    assign rptr  = rptr_reg;

    assign empty = empty_reg;
    assign full  = full_reg;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            wptr_reg  <= 0;
            rptr_reg  <= 0;
            empty_reg <= 1'b1;
            full_reg  <= 0;
        end else begin
            wptr_reg  <= wptr_next;
            rptr_reg  <= rptr_next;
            empty_reg <= empty_next;
            full_reg  <= full_next;
        end
    end

    logic [1:0] fifo_state;
    assign fifo_state = {we, re};

    localparam READ = 2'b01, WRITE = 2'b10, READ_WRITE = 2'b11;

    always_comb begin
        wptr_next  = wptr_reg;
        rptr_next  = rptr_reg;
        empty_next = empty_reg;
        full_next  = full_reg;

        case (fifo_state)
            READ: begin
                if (!empty_reg) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                    if (wptr_next == rptr_next) begin
                        empty_next = 1'b1;
                    end
                end
            end
            WRITE: begin
                if (!full_reg) begin
                    wptr_next  = wptr_reg + 1;
                    empty_next = 1'b0;
                    if (wptr_next == rptr_next) begin
                        full_next = 1'b1;
                    end
                end
            end
            READ_WRITE: begin
                if (full_reg) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                end else if (empty_reg) begin
                    wptr_next  = wptr_reg + 1;
                    empty_next = 1'b0;
                end else begin
                    rptr_next = rptr_reg + 1;
                    wptr_next = wptr_reg + 1;

                end
            end
        endcase
    end

endmodule