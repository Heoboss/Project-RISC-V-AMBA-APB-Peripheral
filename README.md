# RV32I 기반 Multi-Cycle CPU 및 AMBA APB Peripheral 설계

---

## 📜 목차

1. [**프로젝트 목표**](#-프로젝트-목표)
2. [**사용 기술 및 환경**](#-사용-기술-및-환경)
3. [**시스템 아키텍처**](#-시스템-아키텍처)
4. [**주요 기능 및 검증**](#-주요-기능-및-검증)
5. [**트러블슈팅**](#-트러블슈팅)
6. [**고찰**](#-고찰)

---

## 🚀 프로젝트 목표
본 프로젝트는 **RISC-V RV32I ISA**를 기반으로 **Multi-Cycle CPU Core**를 구현하고, **AMBA APB BUS**에 **UART Peripheral**을 연동하여 PC와 FPGA 보드 간의 양방향 통신을 구현하는 것을 목표로 합니다.

- **기본 목표**: 명령어 인출(Fetch), 해독(Decode), 실행(Execute), 메모리 접근(Access), 쓰기(Write back)의 5단계를 갖는 Multi-Cycle Datapath 및 FSM 기반 Control Unit 설계
- **연동 목표**: 표준 버스 프로토콜인 AMBA APB를 학습하고, 직접 설계한 UART 모듈을 APB Slave로 연결하여 시스템 확장성 확보
- **최종 목표**: C언어로 작성된 테스트 코드를 CPU에서 실행하여, PC와 UART 통신이 정상적으로 동작함을 FPGA 보드(Basys3)에서 검증

---
## 🔨 사용 기술 및 환경

- **하드웨어**: Xilinx Basys3 (Artix-7 FPGA)
- **설계 언어**: SystemVerilog
- **개발 도구**: Xilinx Vivado, Visual Studio Code
- **기반 아키텍처**: RISC-V (RV32I)
- **버스 프로토콜**: AMBA APB (Advancded Peripheral Bus)

---

## 🔧 시스템 아키텍처

### 1.RV32I Multi-Cycle CPU
기존의 Single-Cycle 구조를 **5단계(Fetch, Decode, Execute, Memory, Writeback)** 로 분리하고, 각 단계 사이에 **플립플롭(파이프라인 레지스터)** 을 추가하여 Multi-Cycle 구조로 변경하였습니다. 제어 유닛은 각 단계에 맞는 제어 신호를 clk에 동기화하여 생성하기 위해 **FSM(Finite State Machine) 구조**로 설계되었습니다.

### **Multi-Cycle Datapath**
<img width="1122" height="765" alt="image" src="https://github.com/user-attachments/assets/6c653e88-c1b2-454b-b7c4-4ef365924696" />

### **Control Unit FSM**
<img width="1660" height="700" alt="image" src="https://github.com/user-attachments/assets/c469e0da-3e47-4588-8917-472d0a97794b" />

### 2. AMBA APB (Advanced Peripheral Bus)

SoC 설계에서 각 기능 블록을 효율적으로 연결하고 재사용성을 높이기 위해 표준 버스인 AMBA APB를 도입했습니다. APB는 저속의 간단한 Peripheral을 연결하기에 적합합니다.
### **APB State Diagram**
<img width="577" height="637" alt="image" src="https://github.com/user-attachments/assets/2927631c-9f6c-41fe-8aff-7369ee91d57a" />


### 3. UART Peripheral

APB Bus에 Slave로 연결되는 UART 모듈을 설계했습니다. CPU(Master)는 APB 버스를 통해 UART의 레지스터(FSR_TX, FSR_RX, FWD, FRD)에 접근하여 데이터를 송수신합니다.

### **UART Peripheral 블록 다이어그램**
<img width="1471" height="851" alt="image" src="https://github.com/user-attachments/assets/2defb83f-2871-480e-a633-5cfa1924e259" />


### **UART 레지스터 맵**
<img width="1556" height="324" alt="image" src="https://github.com/user-attachments/assets/c9e4f8ca-8887-4621-b5bf-0dc1ab85d7a3" />

---

## ✨ 주요 기능 및 검증

### 1. Multi-Cycle CPU 명령어 검증
- R-Type: `add`, `sub`, `sll`, `srl`, `sra`, `slt`, `sltu`, `xor`, `or`, `and`
- I-Type: `addi`, `slti`, `sltiu`, `xori`, `ori`, `andi`, `slli`, `srli`, `srai`
- Load (I): `lw`, `lb`, `lh`, `lbu`, `lhu` (Sign/Zero Extension 검증)
- S-Type: `sw`, `sh`, `sb` (메모리 쓰기 검증)
- B-Type: `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu` (분기 조건 및 PC 변경 검증)
- U/J-Type: `lui`, `auipc`, `jal`, `jalr` (점프 및 Link Register 저장 검증)

Vivado 시뮬레이션을 통해 Multi-Cycle 구조에서 각 명령어 타입이 정확한 단계(Cycle)를 거쳐 실행되고, 레지스터 파일과 데이터 메모리에 올바른 결과가 저장됨을 확인했습니다.

### 2. UART Peripheral 검증 (Loopback Test)
SystemVerilog Class 기반 Testbench를 작성하여 UART 모듈의 송수신 기능을 검증했습니다.
- **테스트 시나리오**:
  - Testbench(PC 역할)가 `0x00`부터 `0xFF`까지의 데이터를 UART `rx` 핀으로 1바이트씩 전송합니다.
  - Testbench(CPU 역할)가 APB 버스를 통해 UART의 `FSR_RX` 레지스터를 폴링(Polling)하여 수신을 확인합니다.
  - `FRD` 레지스터에서 수신된 데이터를 읽습니다.
  - `FSR_TX` 레지스터를 폴링하여 송신 FIFO가 비어있는지 확인합니다.
  - `FWD` 레지스터에 읽은 데이터를 그대로 다시 씁니다.
  - Monitor가 UART `tx` 핀으로 해당 데이터가 동일하게 출력되는지 비교합니다.
- **검증 결과**: 총 256 바이트의 모든 데이터 케이스에 대해 **PASS (100% Coverage)** 함을 확인했습니다.

### 3. C언어 기반 FPGA 동작 검증
C언어로 UART 송수신 및 LED 제어 프로그램을 작성하여 실제 FPGA 보드에서 동작을 검증했습니다.
- PC의 터미널 프로그램에서 'R' 또는 'L' 커맨드를 입력받습니다.
- CPU는 UART로 커맨드를 수신하여 LED의 쉬프트 방향을 제어합니다.
- 동시에 현재 LED의 쉬프트 방향("left", "right")을 주기적으로 PC에 UART로 전송합니다.
- Reset 입력 시 "System Start" 문자열을 PC로 전송합니다.

---

## 🔧 트러블슈팅
프로젝트 진행 중 발생했던 주요 문제 및 해결 과정은 다음과 같습니다.
- **UART 송신 데이터 누락**
  - 문제: "System Start"와 같이 여러 문자를 연속으로 `uart_put_char` 함수로 전송 시, 일부 문자가 누락되는 현상이 발생했습니다.
  - 원인: CPU가 TX FIFO에 데이터를 PUSH하는 속도(APB Bus 속도)가 UART가 데이터를 POP하여 직렬화하는 속도(Baud Rate)보다 빨랐습니다. `FSR_TX`의 FULL 비트를 확인하는 로직이 있었음에도, FIFO가 채워지는 속도가 더 빨라 데이터가 덮어씌워졌습니다.
  - 해결: `uart_put_char` 함수 내부에 데이터를 FWD 레지스터에 쓴 직후, 짧은 `delay`를 추가하여 FIFO가 처리할 시간을 확보함으로써 문제를 해결했습니다.

- **C언어 문자열 포인터 접근 문제**
  - 문제: `uart_put_string(char *s)`와 같이 문자열 포인터를 받아 char 단위로 접근하려 했으나, 의도대로 동작하지 않았습니다.
  - 원인: 설계된 CPU의 Data Memory (RAM)가 `lw`, `sw` 등 Word(32-bit) 단위의 Load/Store만 지원하고, `lb`, `sb`와 같은 Byte 단위 접근을 구현하지 않았기 때문입니다.
  - 한계: BitStream 생성에 있어서 시간상 제약으로 Byte 단위 Load/Store를 추가 구현하지 못하고, `uart_put_char('S');`, `uart_put_char('y');` ... 와 같이 한 글자씩 하드코딩하는 방식으로 우회했습니다.

---

## 🤔 고찰
 - `uart_put_char` 함수를 여러 번 호출하는 대신, `uart_put_string` 함수를 구현하여 `main` 코드를 더 깔끔하게 개선할 수 있었을 것입니다. (Byte 단위 메모리 접근이 선행되어야 함)
 - APB BUS 기반으로 시스템을 구축하고 UART Peripheral을 연동하면서, 표준화된 버스 인터페이스가 시스템의 확장성과 IP의 **재사용성** 측면에서 왜 중요한지 체감할 수 있었습니다.
- SystemVerilog의 Class와 Task를 이용한 Testbench를 작성하며, 명확한 Naming과 모듈화된 검증 로직이 코드의 가독성과 디버깅 효율을 크게 향상시킨다는 것을 깨달았습니다.

---

## 📺 발표 영상

[![RISC-V CPU & AMBA APB Peripheral Presentation](https://img.youtube.com/vi/mBd83rz3Lf8/0.jpg)](https://youtu.be/mBd83rz3Lf8?si=aWIPSF7jeECav-37)

> **[251027 RISC V CPU 설계 및 AMBA APB Peripheral 설계 발표영상 보러가기](https://youtu.be/mBd83rz3Lf8?si=aWIPSF7jeECav-37)**

---

- **Author**: 허현강 (Harman 2기)
