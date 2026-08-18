# APB Timer IP — Register Map

| Offset | Register      | Access      | Reset | Description                              |
|--------|----------------|-------------|-------|-------------------------------------------|
| 0x00   | REG_CTRL       | R/W         | 0x0   | bit0=Enable, bit1=Auto-reload             |
| 0x04   | REG_LOAD       | R/W         | 0x0   | Value loaded into counter on start/reload |
| 0x08   | REG_COUNT      | Read-Only   | 0x0   | Live counter value                        |
| 0x0C   | REG_COMPARE    | R/W         | 0x0   | Match value that triggers interrupt       |
| 0x10   | REG_INTEN      | R/W         | 0x0   | Interrupt enable (bit0)                   |
| 0x14   | REG_INTSTAT    | Read/W1C    | 0x0   | Interrupt status, write-1-to-clear        |
| 0x18   | REG_PRESCALER  | R/W         | 0x0   | Clock divide ratio before counting        |
