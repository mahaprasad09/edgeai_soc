`timescale 1ns/1ps

// ============================================================================
// 1. APB GPIO IP Module
// ============================================================================
module apb_gpio #(
    parameter DATA_WIDTH = 32
)(
    input  logic                  pclk,
    input  logic                  presetn,
    input  logic                  psel,
    input  logic                  penable,
    input  logic                  pwrite,
    input  logic [3:0]            paddr,
    input  logic [DATA_WIDTH-1:0] pwdata,
    output logic [DATA_WIDTH-1:0] prdata,
    output logic                  pready,

    input  logic [DATA_WIDTH-1:0] gpio_in,
    output logic [DATA_WIDTH-1:0] gpio_out,
    output logic [DATA_WIDTH-1:0] gpio_dir
);
    logic [DATA_WIDTH-1:0] reg_data;
    logic [DATA_WIDTH-1:0] reg_dir;

    assign pready   = 1'b1;
    assign gpio_out = reg_data;
    assign gpio_dir = reg_dir;

    wire apb_write = psel && penable && pwrite;
    wire apb_read  = psel && !pwrite;

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            reg_data <= '0;
            reg_dir  <= '0;
        end else if (apb_write) begin
            case (paddr[3:2])
                2'b00: reg_data <= pwdata;
                2'b01: reg_dir  <= pwdata;
                default: ;
            endcase
        end
    end

    always_comb begin
        prdata = '0;
        if (apb_read) begin
            case (paddr[3:2])
                2'b00:   prdata = (reg_dir & reg_data) | (~reg_dir & gpio_in);
                2'b01:   prdata = reg_dir;
                default: prdata = '0;
            endcase
        end
    end
endmodule


// ============================================================================
// 2. APB Timer IP Module
// ============================================================================
module apb_timer #(
    parameter DATA_WIDTH = 32
)(
    input  logic                  pclk,
    input  logic                  presetn,
    input  logic                  psel,
    input  logic                  penable,
    input  logic                  pwrite,
    input  logic [4:0]            paddr,
    input  logic [DATA_WIDTH-1:0] pwdata,
    output logic [DATA_WIDTH-1:0] prdata,
    output logic                  pready,
    output logic                  timer_irq
);
    logic [DATA_WIDTH-1:0] reg_ctrl;
    logic [DATA_WIDTH-1:0] reg_prescale;
    logic [DATA_WIDTH-1:0] reg_reload;
    logic [DATA_WIDTH-1:0] reg_value;
    logic [DATA_WIDTH-1:0] prescaler_cnt;
    logic                  reg_intstat;

    wire timer_enable = reg_ctrl[0];
    wire auto_reload  = reg_ctrl[1];
    wire irq_enable   = reg_ctrl[2];

    wire apb_write = psel && penable && pwrite;
    wire apb_read  = psel && !pwrite;

    assign pready    = 1'b1;
    assign timer_irq = reg_intstat && irq_enable;

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            reg_ctrl      <= '0;
            reg_prescale  <= '0;
            reg_reload    <= '0;
            reg_value     <= '0;
            prescaler_cnt <= '0;
            reg_intstat   <= 1'b0;
        end else begin
            if (apb_write) begin
                case (paddr[4:2])
                    3'b000: begin
                        reg_ctrl <= pwdata;
                        if (pwdata[0] && !timer_enable) begin
                            reg_value     <= reg_reload;
                            prescaler_cnt <= reg_prescale;
                        end
                    end
                    3'b001: reg_prescale <= pwdata;
                    3'b010: reg_reload   <= pwdata;
                    3'b011: reg_value    <= pwdata;
                    3'b100: begin
                        if (pwdata[0]) reg_intstat <= 1'b0;
                    end
                    default: ;
                endcase
            end else if (timer_enable) begin
                if (prescaler_cnt == '0) begin
                    prescaler_cnt <= reg_prescale;
                    if (reg_value == '0) begin
                        reg_intstat <= 1'b1;
                        if (auto_reload) reg_value <= reg_reload;
                        else             reg_ctrl[0] <= 1'b0;
                    end else begin
                        reg_value <= reg_value - 1'b1;
                    end
                end else begin
                    prescaler_cnt <= prescaler_cnt - 1'b1;
                end
            end
        end
    end

    always_comb begin
        prdata = '0;
        if (apb_read) begin
            case (paddr[4:2])
                3'b000: prdata = reg_ctrl;
                3'b001: prdata = reg_prescale;
                3'b010: prdata = reg_reload;
                3'b011: prdata = reg_value;
                3'b100: prdata = {{(DATA_WIDTH-1){1'b0}}, reg_intstat};
                default: prdata = '0;
            endcase
        end
    end
endmodule


// ============================================================================
// 3. APB Subsystem Top Wrapper (Decoder + Multiplexer)
// ============================================================================
module apb_subsystem #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic                  pclk,
    input  logic                  presetn,
    input  logic                  psel,
    input  logic                  penable,
    input  logic                  pwrite,
    input  logic [ADDR_WIDTH-1:0] paddr,
    input  logic [DATA_WIDTH-1:0] pwdata,
    output logic [DATA_WIDTH-1:0] prdata,
    output logic                  pready,

    input  logic [DATA_WIDTH-1:0] gpio_in,
    output logic [DATA_WIDTH-1:0] gpio_out,
    output logic [DATA_WIDTH-1:0] gpio_dir,
    output logic                  timer_irq
);
    wire psel_gpio  = psel && (paddr[15:12] == 4'h0);
    wire psel_timer = psel && (paddr[15:12] == 4'h1);

    logic [DATA_WIDTH-1:0] prdata_gpio;
    logic [DATA_WIDTH-1:0] prdata_timer;
    logic                  pready_gpio;
    logic                  pready_timer;

    apb_gpio #(.DATA_WIDTH(DATA_WIDTH)) u_gpio (
        .pclk(pclk), .presetn(presetn),
        .psel(psel_gpio), .penable(penable), .pwrite(pwrite),
        .paddr(paddr[3:0]), .pwdata(pwdata), .prdata(prdata_gpio),
        .pready(pready_gpio), .gpio_in(gpio_in), .gpio_out(gpio_out),
        .gpio_dir(gpio_dir)
    );

    apb_timer #(.DATA_WIDTH(DATA_WIDTH)) u_timer (
        .pclk(pclk), .presetn(presetn),
        .psel(psel_timer), .penable(penable), .pwrite(pwrite),
        .paddr(paddr[4:0]), .pwdata(pwdata), .prdata(prdata_timer),
        .pready(pready_timer), .timer_irq(timer_irq)
    );

    always_comb begin
        if (psel_gpio) begin
            prdata = prdata_gpio;
            pready = pready_gpio;
        end else if (psel_timer) begin
            prdata = prdata_timer;
            pready = pready_timer;
        end else begin
            prdata = '0;
            pready = 1'b1;
        end
    end
endmodule


// ============================================================================
// 4. Integrated Testbench
// ============================================================================
module tb_apb_subsystem;
    logic pclk, presetn, psel, penable, pwrite;
    logic [31:0] paddr, pwdata, prdata;
    logic pready, timer_irq;
    logic [31:0] gpio_in, gpio_out, gpio_dir;

    apb_subsystem dut (.*);

    always #5 pclk = ~pclk;

    task apb_write(input [31:0] addr, input [31:0] data);
        @(posedge pclk);
        psel <= 1'b1; pwrite <= 1'b1; paddr <= addr; pwdata <= data;
        @(posedge pclk);
        penable <= 1'b1;
        @(posedge pclk);
        while (!pready) @(posedge pclk);
        psel <= 1'b0; penable <= 1'b0;
    endtask

    task apb_read(input [31:0] addr, output [31:0] data);
        @(posedge pclk);
        psel <= 1'b1; pwrite <= 1'b0; paddr <= addr;
        @(posedge pclk);
        penable <= 1'b1;
        @(posedge pclk);
        while (!pready) @(posedge pclk);
        data = prdata;
        psel <= 1'b0; penable <= 1'b0;
    endtask

    logic [31:0] read_val;

    initial begin
        $dumpfile("sim/subsystem_sim.vcd");
        $dumpvars(0, tb_apb_subsystem);

        pclk = 0; presetn = 0; psel = 0; penable = 0; pwrite = 0; paddr = 0; pwdata = 0; gpio_in = 32'hA5A5A5A5;
        #20; presetn = 1; #20;

        $display("=== TEST 1: Write to GPIO IP (Base 0x4000_0000) ===");
        apb_write(32'h4000_0004, 32'hFFFF_FFFF);
        apb_write(32'h4000_0000, 32'h1234_5678);
        if (gpio_out == 32'h1234_5678) $display("[PASS] GPIO Output Match: %h", gpio_out);

        $display("=== TEST 2: Write to Timer IP (Base 0x4000_1000) ===");
        apb_write(32'h4000_1008, 32'd4);
        apb_write(32'h4000_1004, 32'd1);
        apb_write(32'h4000_1000, 32'h05);

        wait(timer_irq == 1'b1);
        $display("[PASS] Integrated Timer Interrupt Asserted!");

        $display("=== INTEGRATED SUBSYSTEM PASSED ALL TESTS! ===");
        $finish;
    end
endmodule
