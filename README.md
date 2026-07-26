# Parameterized SPI Module Verilog Implementation

## Overview

This project implements a robust, fully parameterized, and synthesizable SPI (Serial Peripheral Interface) communication system in Verilog. Designed with a modular architecture, it supports all four SPI modes via configurable clock polarity (`CPOL`) and clock phase (`CPHA`), along with precise edge-aligned data transfer and full-duplex communication.
The system demonstrates correct master–slave interaction using an automated producer–responder loopback architecture, enabling continuous verification without external stimulus.

## Architecture & Design
The SPI system is organized around synchronous control logic, edge detection, and safe signal handling:
- Clock Generation & Scaling: A parameterized clock divider generates the SPI clock (`SCLK`) from the system clock, supporting flexible timing configurations.
- Edge-Based Data Transfer: Data shifting and sampling are aligned to leading and trailing edges, dynamically determined by `CPOL` and `CPHA`.
- Full-Duplex Communication: Simultaneous transmission (`MOSI`) and reception (`MISO`) enable continuous bidirectional data exchange.
- Finite State Machine (FSM): The master controller operates through structured states:
<div align="center">`IDLE` -> `SETUP` -> `TRANSFER` -> `DONE`</div>
- Clock Domain Crossing (CDC): Multi-stage synchronizers ensure safe sampling of asynchronous SPI inputs (`SCLK`, `MOSI`, `nCS`).

## Components
The design is modular, consisting of primary building blocks integrated into a complete SPI system:
- `Master.v` (SPI Master Controller): Generates `SCLK`, controls `MOSI`, manages `nCS`, and samples incoming `MISO`. Implements FSM-based transaction control and `CPOL`/`CPHA`-aware edge logic.
- `Slave.v` (SPI Slave Peripheral): Receives serial data via `MOSI`, transmits via `MISO`, and reconstructs parallel data using synchronized clock sampling.
- `Producer.v` (Transaction Generator): Generates a continuous stream of incrementing transmit data and initiates SPI transfers using a `start` signal.
- `Responder.v` (Slave Data Source): Supplies dynamic transmit data to the slave and updates payload after each completed transaction.

## SPI Modes Supported
| Mode | CPOL | CPHA | Operation Description |
| :---: | :---: | :---: | :--- |
| **0** | 0 | 0 | Sample on rising, shift on falling |
| **1** | 0 | 1 | Shift on rising, sample on falling |
| **2** | 1 | 0 | Sample on falling, shift on rising |
| **3** | 1 | 1 | Shift on falling, sample on rising |

# Simulation
The software stack used is:
- Icarus Verilog: Compilation and simulation
- GTKWave: Waveform visualization
## How to Run
```bash
# Compile the design
iverilog -o dsn SPI_tb.v Master.v Slave.v Producer.v Responder.v
# Run simulation
vvp dsn
# View waveform
gtkwave spi.vcd
```

# Waveform analysis
The design’s correctness is verified through GTKWave simulation traces. The system relies on accurate clock edge alignment, proper chip-select control, and synchronized data exchange.

**Figure 1: Full System SPI Transaction Overview**
<img width="1750" height="267" alt="image" src="https://github.com/user-attachments/assets/f89b271c-1d53-453d-959a-8c3ae9c298c4" />
- System Initialization: As observed in the waveform, the system clock (`clk`) and active-low reset (`arst_n`) cleanly initialize internal registers, setting the master state machine to idle and deasserting chip select (`nCS`) high.
- Transaction Framing: The `start` signal pulses high to trigger each transfer, causing chip select (`nCS`) to drop low and frame the active serial communication window over `SCLK`.
- Data Stream & Shifting: Master-out-slave-in (`MOSI`) and master-in-slave-out (`MISO`) shift data bits progressively across serial clock edges, streaming payload bytes sequentially as seen in `tx_data` and `rx_data`.
- Transaction Completion: Once all 8 bits are shifted, chip select (`nCS`) returns high and a `done` completion pulse is generated, safely latching the received byte into the output register.

**Figure 2: Master Transmission (MOSI)**
<img width="1762" height="211" alt="image" src="https://github.com/user-attachments/assets/3fbd8384-45c8-4d13-ba7e-bd63f2774106" />
- Bit Serialization: Data is shifted out MSB-first on `MOSI`, perfectly aligned to the configuration edges defined by `CPHA` and `CPOL`.
- Clock Alignment: `SCLK` toggling strictly follows the low idle configuration defined by `CPOL = 0`, ensuring proper phase relationships with data shifts.
- Control Signals: The active-low chip select (`nCS`) cleanly frames each individual transaction window in synchronization with the internal `bit_cnt` progression from 0 through 8.

**Figure 3: Slave Reception (MISO)**
<img width="1762" height="211" alt="image" src="https://github.com/user-attachments/assets/f0aa2b37-38c0-4dce-aa0a-e8250b6926f8" />
- Bit Serialization: Data is shifted out MSB-first on MOSI, perfectly aligned to the configuration edges defined by CPHA and CPOL.
- Clock Alignment: SCLK toggling strictly follows the low idle configuration defined by CPOL = 0, ensuring proper phase relationships with data shifts.
- Control Signals: The active-low chip select (nCS) cleanly frames each individual transaction window in synchronization with the internal bit_cnt progression from 0 through 8.

# Results
- Correct parameterized SPI master–slave full-duplex communication verified via simulation
- Accurate CPOL/CPHA-based edge alignment across all SPI modes
- Reliable clock domain synchronization and metastability-safe sampling
- Continuous transaction flow achieved using producer–responder architecture
- Clean waveform validation using Icarus Verilog and GTKWave
