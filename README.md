# Edge AI SoC - AMBA 3 APB Peripheral Subsystem

## Overview

This repository contains the SystemVerilog RTL design, simulation, and integration of GPIO and Timer peripheral IP cores using the AMBA 3 Advanced Peripheral Bus (APB) interface. Developed as part of an Edge AI SoC project, the work focuses on reusable peripheral design, register-based control, and functional verification.

The GPIO peripheral provides programmable digital input and output control, while the Timer peripheral supports programmable timing and interrupt generation. Both peripherals are connected through an APB subsystem wrapper that decodes incoming addresses, selects the appropriate peripheral, and routes its response to the bus master.

The development workflow includes individual IP implementation, testbench development, simulation, waveform analysis, and subsystem integration. Icarus Verilog is used to compile and simulate the SystemVerilog source files, and GTKWave is used to inspect signal activity and debug bus transactions.

### Project Objectives

* Implement GPIO and Timer peripherals with an APB register interface.
* Verify peripheral behavior through simulation and directed test cases.
* Examine reset behavior, register accesses, timer operation, and interrupt handling.
* Integrate both peripherals into a shared APB address space.
* Document the design and simulation results to support review and further development.

## Project Structure

The repository is organized by peripheral and integration level, allowing each IP core to be reviewed independently before examining the complete subsystem.

| Directory / File | Purpose                                                                                                                                  |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `apb_gpio/`      | GPIO peripheral RTL and associated design files for digital input/output control through APB register accesses.                          |
| `apb_timer/`     | Timer peripheral RTL and associated design and verification files for programmable timing and interrupt behavior.                        |
| `apb_subsystem/` | Subsystem integration files, including the top-level wrapper and testbench for connecting and exercising the GPIO and Timer peripherals. |
| `documentation/` | Intended location for supporting reports, waveform captures, and design explanations.                                                    |
| `README.md`      | Project introduction, repository organization, and guidance for navigating the implementation.                                           |

### How the Modules Work Together

The APB subsystem wrapper receives bus transactions and uses address decoding to select either the GPIO or Timer peripheral. The selected peripheral processes the register access, and the wrapper routes its read data and response signals back to the master.

This organization separates peripheral functionality from integration logic, making the design easier to understand, debug, and extend with additional APB peripherals.

### Suggested Review Order

1. Review `apb_gpio/` to understand the GPIO implementation.
2. Review `apb_timer/` to understand timer operation and its verification.
3. Review `apb_subsystem/` to examine address decoding and peripheral integration.
4. Consult available material in `documentation/` for simulation results and supporting explanations.
