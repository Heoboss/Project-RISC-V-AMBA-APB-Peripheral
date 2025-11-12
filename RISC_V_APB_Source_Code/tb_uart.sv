`timescale 1ns / 1ps

// --- 1. DUT와 연결될 모든 신호를 포함하는 인터페이스 ---
interface uart_if;
    logic        PCLK;
    logic        PRESET;
    logic [ 3:0] PADDR;
    logic [31:0] PWDATA;
    logic        PWRITE;
    logic        PENABLE;
    logic        PSEL;
    logic [31:0] PRDATA;
    logic        PREADY;
    logic        rx;
    logic        tx;
endinterface


// --- 2. 모든 테스트 로직(Task)을 포함하는 클래스 ---
class UartTester;

    // 가상 인터페이스 핸들
    virtual uart_if vif;

    // 테스트 결과 집계를 위한 멤버 변수
    int pass_count = 0;
    int fail_count = 0;

    // 레지스터 맵 (클래스 내부 상수로 이동)
    localparam logic [3:0] TX_STATUS_ADDR = 4'h0; // slv_reg0 (USR)
    localparam logic [3:0] RX_STATUS_ADDR = 4'h4; // slv_reg1 (ULS)
    localparam logic [3:0] TX_DATA_ADDR   = 4'h8; // slv_reg2 (UWD)
    localparam logic [3:0] RX_DATA_ADDR   = 4'hC; // slv_reg3 (URD)
    localparam int RX_FIFO_EMPTY_BIT = 0; // ULS[0] = empty_RX (1=Empty)
    localparam int TX_FIFO_FULL_BIT  = 1; // USR[1] = full_TX  (1=Full)
    
    parameter BAUD_RATE     = 9600;
    parameter BIT_PERIOD    = (1000_000_000 / BAUD_RATE);

    // 생성자 (Constructor): 인터페이스 핸들을 외부에서 받아와 연결
    function new(virtual uart_if vif);
        this.vif = vif;
    endfunction

    // --- APB 쓰기 태스크 ---
    task automatic apb_write(input logic [3:0] addr, input logic [31:0] data);
        @(posedge vif.PCLK);
        // SETUP
        vif.PSEL   <= 1'b1;
        vif.PWRITE <= 1'b1;
        vif.PADDR  <= addr;
        vif.PWDATA <= data;
        vif.PENABLE<= 1'b0;
        @(posedge vif.PCLK);
        // ACCESS
        vif.PENABLE<= 1'b1;
        wait (vif.PREADY == 1'b1);
        @(posedge vif.PCLK);
        // IDLE
        vif.PSEL   <= 1'b0;
        vif.PENABLE<= 1'b0;
    endtask

    // --- APB 읽기 태스크 ---
    task automatic apb_read(input logic [3:0] addr, output logic [31:0] data);
        logic [31:0] read_value;
        @(posedge vif.PCLK);
        // SETUP
        vif.PSEL   <= 1'b1;
        vif.PWRITE <= 1'b0;
        vif.PADDR  <= addr;
        vif.PENABLE<= 1'b0;
        @(posedge vif.PCLK);
        // ACCESS
        vif.PENABLE<= 1'b1;
        wait (vif.PREADY == 1'b1); // FSM=READ
        @(posedge vif.PCLK); // FSM=HOLD
        read_value = vif.PRDATA; // T4 사이클에서 읽기
        @(posedge vif.PCLK);
        // IDLE
        vif.PSEL   <= 1'b0;
        vif.PENABLE<= 1'b0;
        data = read_value;
    endtask

    // --- UART 바이트 직렬 전송 태스크 ---
    task automatic send_uart_byte(input bit [7:0] data_to_send);
        #(BIT_PERIOD);
        vif.rx <= 1'b0; // Start bit
        #(BIT_PERIOD);
        for (int i = 0; i < 8; i++) begin
            vif.rx <= data_to_send[i]; // LSB first
            #(BIT_PERIOD);
        end
        vif.rx <= 1'b1; // Stop bit
        #(BIT_PERIOD);
        vif.rx <= 1'b1; // Back to Idle
    endtask

    // --- UART 바이트 직렬 수신 태스크 ---
    task automatic receive_uart_byte(output bit [7:0] received_data);
        bit [7:0] data_buffer;
        wait (vif.tx == 1'b0); // Start 비트 대기
        #(BIT_PERIOD / 2); // Start 비트 중간으로 이동
        #(BIT_PERIOD);     // D0 중간으로 이동
        for (int i = 0; i < 8; i++) begin
            data_buffer[i] = vif.tx; // Sample
            #(BIT_PERIOD); // 다음 비트 중간으로 이동
        end
        if (vif.tx != 1'b1) $warning("Monitor: Stop bit not 1!");
        received_data = data_buffer;
    endtask

    // --- UART 루프백 테스트 태스크 ---
    task automatic run_loopback_test(input int test_id, 
                                     input bit [7:0] data_to_send,
                                     output bit test_passed);
        bit [7:0] data_from_rx_fifo;
        bit [7:0] data_from_tx_pin;
        logic [31:0] apb_read_data;
        logic [31:0] status_reg_rx, status_reg_tx;
        
        $display("[%0t ns] TEST %d: Sending (0x%h) to rx pin...", $time, test_id, data_to_send);
        
        // 1. PC 역할:
        fork
            send_uart_byte(data_to_send);
        join_none

        // 2. CPU 역할: RX FIFO 폴링
        $display("[%0t ns] CPU Sim (Test %d): Polling RX status...", $time, test_id);
        do begin
            apb_read(RX_STATUS_ADDR, status_reg_rx);
            @(posedge vif.PCLK);
        end while (status_reg_rx[RX_FIFO_EMPTY_BIT] == 1);
        $display("[%0t ns] CPU Sim (Test %d): RX FIFO Not Empty (ULS=0x%h)", $time, test_id, status_reg_rx);

        // 3. CPU 역할: RX FIFO 읽기
        apb_read(RX_DATA_ADDR, apb_read_data);
        data_from_rx_fifo = apb_read_data[7:0];
        $display("[%0t ns] CPU Sim (Test %d): Read 0x%h from RX Data (URD)", $time, test_id, data_from_rx_fifo);

        // 4. CPU 역할: TX FIFO 폴링
        $display("[%0t ns] CPU Sim (Test %d): Polling TX status...", $time, test_id);
        do begin
            apb_read(TX_STATUS_ADDR, status_reg_tx);
            @(posedge vif.PCLK);
        end while (status_reg_tx[TX_FIFO_FULL_BIT] == 1);
        $display("[%0t ns] CPU Sim (Test %d): TX FIFO Not Full (USR=0x%h)", $time, test_id, status_reg_tx);

        // 5. CPU 역할: TX FIFO 쓰기
        apb_write(TX_DATA_ADDR, {24'b0, data_from_rx_fifo});
        $display("[%0t ns] CPU Sim (Test %d): Wrote 0x%h to TX Data (UWD)", $time, test_id, data_from_rx_fifo);

        // 6. Monitor 역할: tx 핀 수신
        $display("[%0t ns] Monitor (Test %d): Waiting for data on tx pin...", $time, test_id);
        receive_uart_byte(data_from_tx_pin);
        $display("[%0t ns] Monitor (Test %d): Received 0x%h from tx pin", $time, test_id, data_from_tx_pin);

        // 7. Scoreboard 역할: 검증
        if (data_to_send == data_from_rx_fifo && data_to_send == data_from_tx_pin) begin
            $display("********* TEST %d (0x%h) PASS *********", test_id, data_to_send);
            test_passed = 1'b1;
        end else begin
            $error("********* TEST %d (0x%h) FAIL ********* Sent: 0x%h, RX_FIFO: 0x%h, TX_PIN: 0x%h",
                   test_id, data_to_send, data_to_send, data_from_rx_fifo, data_from_tx_pin);
            test_passed = 1'b0;
        end
    endtask

    // --- 전체 테스트를 실행하고 요약하는 최상위 태스크 ---
    task automatic run_all_tests();
        bit test_status;
        
        $display("[%0t ns] Test Runner: Waiting for reset release...", $time);
        @(negedge vif.PRESET);
        @(posedge vif.PCLK);
        $display("[%0t ns] Test Runner: Reset Released. Starting 256 tests.", $time);

        // 256회 루프
        for(int i = 0; i < 256; i++) begin
            run_loopback_test(i, i[7:0], test_status);
            
            // 결과 집계
            if (test_status == 1'b1) begin
                pass_count++;
            end else begin
                fail_count++;
            end
        end

        // 테스트 요약 (커버리지)
        $display("======================================================");
        $display("               UART 테스트 요약 (COVERAGE)");
        $display("======================================================");
        $display("  총 테스트 수 : %0d", pass_count + fail_count);
        $display("  PASS (성공)  : %0d", pass_count);
        $display("  FAIL (실패)  : %0d", fail_count);
        $display("======================================================");
    endtask

endclass


// --- 3. 최상위 테스트벤치 모듈 ---
module tb_uart_class ();

    parameter CLK_PERIOD_NS = 10;
   
    // 인터페이스 인스턴스화
    uart_if if_inst();

    // DUT를 인터페이스에 연결
    UART_Periph dut (
        .PCLK   (if_inst.PCLK),
        .PRESET (if_inst.PRESET),
        .PADDR  (if_inst.PADDR),
        .PWDATA (if_inst.PWDATA),
        .PWRITE (if_inst.PWRITE),
        .PENABLE(if_inst.PENABLE),
        .PSEL   (if_inst.PSEL),
        .PRDATA (if_inst.PRDATA),
        .PREADY (if_inst.PREADY),
        .rx     (if_inst.rx),
        .tx     (if_inst.tx)
    );

    // Clock 드라이버 (인터페이스 구동)
    always #(CLK_PERIOD_NS/2) if_inst.PCLK = ~if_inst.PCLK;

    // Reset 및 초기 신호 드라이버 (인터페이스 구동)
    initial begin
        if_inst.PCLK   = 0;
        if_inst.PRESET = 1;
        if_inst.rx     = 1'b1;
        if_inst.PSEL   = 1'b0;
        if_inst.PENABLE= 1'b0;
        if_inst.PWRITE = 1'b0;
        if_inst.PADDR  = 4'h0;
        if_inst.PWDATA = 32'h0;
        #10 if_inst.PRESET = 0;
    end

    // 테스트 실행기
    initial begin
        // 1. UartTester 클래스 객체 생성 (인터페이스 전달)
        UartTester tester = new(if_inst);
        
        // 2. 테스트 실행
        tester.run_all_tests();
        
        // 3. 종료
        #1000ns;
        $display("[%0t ns] Testbench: Finished.", $time);
        $finish;
    end

endmodule
