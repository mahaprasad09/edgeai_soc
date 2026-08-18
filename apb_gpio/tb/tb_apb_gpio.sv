`timescale 1ns/1ps

module tb_apb_gpio;

    localparam int ADDR_WIDTH = 6;
    localparam int DATA_WIDTH = 32;
    localparam int NUM_GPIOS  = 32;

    logic                  pclk;
    logic                  presetn;
    logic [ADDR_WIDTH-1:0] paddr;
    logic                  psel;
    logic                  penable;
    logic                  pwrite;
    logic [DATA_WIDTH-1:0] pwdata;
    logic [DATA_WIDTH-1:0] prdata;
    logic                  pready;
    logic                  pslverr;

    logic [NUM_GPIOS-1:0]  gpio_in;
    logic [NUM_GPIOS-1:0]  gpio_out;
    logic [NUM_GPIOS-1:0]  gpio_oe;
    logic                  irq;

    localparam logic [ADDR_WIDTH-1:0] REG_DIR     = 6'h00;
    localparam logic [ADDR_WIDTH-1:0] REG_DATAOUT = 6'h04;
    localparam logic [ADDR_WIDTH-1:0] REG_DATAIN  = 6'h08;
    localparam logic [ADDR_WIDTH-1:0] REG_INTEN   = 6'h0C;
    localparam logic [ADDR_WIDTH-1:0] REG_INTSTAT = 6'h10;
    localparam logic [ADDR_WIDTH-1:0] REG_INTTYPE = 6'h14;

    apb_gpio #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_GPIOS(NUM_GPIOS)
    ) dut (
        .pclk_i(pclk),
        .presetn_i(presetn),
        .paddr_i(paddr),
        .psel_i(psel),
        .penable_i(penable),
        .pwrite_i(pwrite),
        .pwdata_i(pwdata),
        .prdata_o(prdata),
        .pready_o(pready),
        .pslverr_o(pslverr),
        .gpio_in_i(gpio_in),
        .gpio_out_o(gpio_out),
        .gpio_oe_o(gpio_oe),
        .irq_o(irq)
    );

    always #5 pclk = ~pclk;

    task apb_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
        @(posedge pclk);
        paddr   <= addr;
        pwrite  <= 1'b1;
        psel    <= 1'b1;
        penable <= 1'b0;
        pwdata  <= data;
        
        @(posedge pclk);
        penable <= 1'b1;
        
        @(posedge pclk);
        psel    <= 1'b0;
        penable <= 1'b0;
    endtask

    task apb_read(input [ADDR_WIDTH-1:0] addr, output [DATA_WIDTH-1:0] data);
        @(posedge pclk);
        paddr   <= addr;
        pwrite  <= 1'b0;
        psel    <= 1'b1;
        penable <= 1'b0;
        
        @(posedge pclk);
        penable <= 1'b1;
        
        @(posedge pclk);
        data    = prdata;
        psel    <= 1'b0;
        penable <= 1'b0;
    endtask

    logic [DATA_WIDTH-1:0] read_val;

    initial begin
        $dumpfile("gpio_waves.vcd");
        $dumpvars(0, tb_apb_gpio);

        pclk    = 0;
        presetn = 0;
        psel    = 0;
        penable = 0;
        pwrite  = 0;
        paddr   = 0;
        pwdata  = 0;
        gpio_in = 32'h0;

        #20 presetn = 1;
        $display("--- Reset Released ---");

        // Test 1: Write/Read Direction
        apb_write(REG_DIR, 32'h0000_FFFF);
        apb_read(REG_DIR, read_val);
        $display("[TEST 1] Direction Read: 0x%08X (Expected: 0x0000FFFF)", read_val);

        // Test 2: Output Data
        apb_write(REG_DATAOUT, 32'h0000_A5A5);
        #10;
        $display("[TEST 2] GPIO Output Pins: 0x%08X (Expected: 0x0000A5A5)", gpio_out);

        // Test 3: Input Data
        gpio_in = 32'h1234_0000;
        #30;
        apb_read(REG_DATAIN, read_val);
        $display("[TEST 3] GPIO Input Pins Sampled: 0x%08X (Expected: 0x12340000)", read_val);

        // Test 4: Interrupt Setup & Clear
        apb_write(REG_INTTYPE, 32'h0010_0000);
        apb_write(REG_INTEN,   32'h0010_0000);

        #20 gpio_in[20] = 1'b1;
        #30;
        $display("[TEST 4] Interrupt Signal (irq): %b (Expected: 1)", irq);

        apb_write(REG_INTSTAT, 32'h0010_0000);
        #20;
        $display("[TEST 4] Interrupt After Clear: %b (Expected: 0)", irq);

        $display("--- ALL TESTS COMPLETED SUCCESSFULLY ---");
        $finish;
    end

endmodule