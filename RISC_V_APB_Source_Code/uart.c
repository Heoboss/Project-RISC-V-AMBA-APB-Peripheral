#include <stdint.h>
#define __IO    volatile

// --- 구조체 정의 ---
typedef struct {
    __IO uint32_t MODER; // Offset 0x00
    __IO uint32_t ODR;   // Offset 0x04
} GPO_TypeDef;

typedef struct {
    __IO uint32_t MODER; // Offset 0x00
    __IO uint32_t ODR;   // Offset 0x04
    __IO uint32_t IDR;   // Offset 0x04
} GPIO_TypeDef;

typedef struct {
    __IO uint32_t FSR_TX; // Offset 0x00, {tx_full, tx_empty } Full(1), Not Full(0)
    __IO uint32_t FSR_RX; // Offset 0x04, {rx_full, rx_empty}  Not Empty(0), Empty(1)
    __IO uint32_t FWD;    // Offset 0x08 (Write Data)
    __IO uint32_t FRD;    // Offset 0x0C (Read Data)
} FIFO_TypeDef;

// --- 메모리 맵 정의 ---
#define APB_BASEADDR   0x10000000
#define GPO_BASEADDR   (APB_BASEADDR + 0x1000)
#define GPI_BASEADDR   (APB_BASEADDR + 0x2000)
#define GPIO_BASEADDR  (APB_BASEADDR + 0x3000)
#define FIFO_BASEADDR  (APB_BASEADDR + 0x4000) // UART/FIFO 주소

// --- 주변장치 포인터 정의 ---
#define GPO             ((GPO_TypeDef  *) GPO_BASEADDR)
#define GPIO            ((GPIO_TypeDef *) GPIO_BASEADDR)
#define FIFO            ((FIFO_TypeDef *) FIFO_BASEADDR)

// --- UART 상태 비트 마스크 (Verilog Uart_SlaveIntf 기준) ---
// FSR (RX Status) 레지스터 (Offset 0x00)
#define UART_FSR_RX_EMPTY   (1 << 0) // Bit 0: 1=Empty, 0=Not Empty
#define UART_FSR_RX_FULL    (1 << 1) // Bit 1: 1=Full,  0=Not Full
// FSR (TX Status) 레지스터 (Offset 0x04)
#define UART_FSR_TX_EMPTY   (1 << 0) // Bit 0: 1=Empty, 0=Not Empty
#define UART_FSR_TX_FULL    (1 << 1) // Bit 1: 1=Full,  0=Not Full

// --- 함수 원형 선언 ---
void delay(uint32_t n);
void System_init();
void uart_put_char(char c);
void send_uart_string(char* str, uint32_t length);
void print_cur_dir(int);
void print_change_dir(int);
uint32_t FIFO_RX_writeCheck(FIFO_TypeDef* fifo); // RX 상태 읽기
uint32_t FIFO_TX_writeCheck(FIFO_TypeDef* fifo); // TX 상태 읽기
uint32_t FIFO_readData(FIFO_TypeDef* fifo);    // RX 데이터 읽기
//uint32_t my_strlen(const char *str);

int main()
{
    uint32_t led_pattern = 0x01; // LED 패턴 제일 오른쪽부터 시작
    int shift_direction = 1;    // 쉬프트 방향 (1: 왼쪽 <<, 0: 오른쪽 >>)
    uint32_t one = 1;
    char received_char;

    uint32_t timer_count = 0;
    uint32_t TIMER_5_SECONDS_LOOPS = 50; // 값 조정 필요!

    System_init();
    GPO->ODR = led_pattern; // 초기 패턴 출력

    //send_uart_string(msg_start, 13);

    while (1) {
        // --- 1. UART 수신 확인 및 방향 제어 ---
        // 가정: FSR_RX의 Bit 0 = Not Empty(0), Empty(1)
        if ((FIFO_RX_writeCheck(FIFO) & one) == 0) { // 데이터가 있으면 (Not Empty)
            received_char = (char)(FIFO_readData(FIFO) & 0xFF); // 데이터 읽기 (FIFO에서 제거됨)

            if (received_char == 'L' || received_char == 'l') {
                if (shift_direction == 0) {
                    print_change_dir(shift_direction);
                }
                shift_direction = 1; // 왼쪽으로 쉬프트
            }
            else if (received_char == 'R' || received_char == 'r') {
                if (shift_direction == 1) {
                    print_change_dir(shift_direction);
                }
                shift_direction = 0; // 오른쪽으로 쉬프트
            }
        }

        // --- 2. LED 패턴 업데이트 ---
        if (shift_direction == 1) { // 왼쪽 쉬프트
            // 왼쪽 시프트 (<<)
            if (led_pattern == 0x80) { // 맨 왼쪽(LED7)에 도달하면
                led_pattern = 0x01;     // 맨 오른쪽(LED0)으로 순환
            }
            else {
                led_pattern = led_pattern << 1; // 왼쪽으로 한 칸 이동
            }
        }
        else { // 오른쪽 쉬프트
            // 오른쪽 시프트 (>>)
            if (led_pattern == 0x01) { // 맨 오른쪽(LED0)에 도달하면
                led_pattern = 0x80;     // 맨 왼쪽(LED7)으로 순환
            }
            else {
                led_pattern = led_pattern >> 1; // 오른쪽으로 한 칸 이동
            }
        }

        // --- 3. GPO 출력 업데이트 ---
        GPO->ODR = led_pattern;

        // --- 4. 5초 타이머 및 상태 전송 ---
        timer_count++;
        if (timer_count >= TIMER_5_SECONDS_LOOPS) {
            timer_count = 0; // 카운터 리셋
            if (shift_direction == 1) {
                print_cur_dir(shift_direction);
            }
            else {
                print_cur_dir(shift_direction);
            }
        }

        // --- 4. 딜레이 (쉬프트 속도 조절) ---
        delay(200); // 값 조정 필요

    }
    return 0; // 도달하지 않음
};


// --- UART 문자 전송 함수 ---
void uart_put_char(char c) {
    while (FIFO->FSR_TX & UART_FSR_TX_FULL); // TX FIFO가 Full(1)이면 대기
    FIFO->FWD = (uint32_t)c; // 데이터 쓰기
    delay(10);
}

// --- UART 문자열 전송 함수 ---
// 인자로 (문자열 포인터, 문자열 길이)를 받음
void send_uart_string(char* str, uint32_t length) {
    for (uint32_t i = 0; i < length; i++) {
        uart_put_char(str[i]); // str[i]로 해당 문자 접근
    }
}

uint32_t FIFO_RX_writeCheck(FIFO_TypeDef* fifo) { return fifo->FSR_RX; }
uint32_t FIFO_TX_writeCheck(FIFO_TypeDef* fifo) { return fifo->FSR_TX; }
uint32_t FIFO_readData(FIFO_TypeDef* fifo) { return fifo->FRD; }

// --- Delay 함수 (volatile 추가됨) ---
void delay(uint32_t n) {
    volatile uint32_t temp = 0;
    for (uint32_t i = 0; i < n; i++) {
        for (uint32_t j = 0; j < 1000; j++) {
            temp++;
        }
    }
};

void System_init() {
    GPO->MODER = 0xff;
    GPIO->MODER = 0x0f;
    uart_put_char('S');
    uart_put_char('y');
    uart_put_char('s');
    uart_put_char('t');
    uart_put_char('e');
    uart_put_char('m');
    uart_put_char(' ');
    uart_put_char('S');
    uart_put_char('t');
    uart_put_char('a');
    uart_put_char('r');
    uart_put_char('t');
    uart_put_char('\n');
}

void print_cur_dir(int dir) {
    uart_put_char('C');
    uart_put_char('u');
    uart_put_char('r');
    uart_put_char('r');
    uart_put_char('e');
    uart_put_char('n');
    uart_put_char('t');
    uart_put_char(' ');
    uart_put_char('D');
    uart_put_char('i');
    uart_put_char('r');
    uart_put_char('e');
    uart_put_char('c');
    uart_put_char('t');
    uart_put_char('i');
    uart_put_char('o');
    uart_put_char('n');
    uart_put_char(' ');
    uart_put_char(':');
    uart_put_char(' ');
    if (dir == 1) {
        uart_put_char('L');
        uart_put_char('e');
        uart_put_char('f');
        uart_put_char('t');
    }
    else {
        uart_put_char('R');
        uart_put_char('i');
        uart_put_char('g');
        uart_put_char('h');
        uart_put_char('t');
    }

    uart_put_char('\n');
}

void print_change_dir(int dir) {
    uart_put_char('C');
    uart_put_char('h');
    uart_put_char('a');
    uart_put_char('n');
    uart_put_char('g');
    uart_put_char('e');
    uart_put_char(' ');
    uart_put_char('D');
    uart_put_char('i');
    uart_put_char('r');
    uart_put_char('e');
    uart_put_char('c');
    uart_put_char('t');
    uart_put_char('i');
    uart_put_char('o');
    uart_put_char('n');
    uart_put_char(' ');
    uart_put_char('t');
    uart_put_char('o');
    uart_put_char(' ');
    if (dir == 0) {
        uart_put_char('L');
        uart_put_char('e');
        uart_put_char('f');
        uart_put_char('t');
    }
    else {
        uart_put_char('R');
        uart_put_char('i');
        uart_put_char('g');
        uart_put_char('h');
        uart_put_char('t');
    }
    uart_put_char('\n');
}