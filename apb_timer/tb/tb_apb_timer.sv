module tb_apb_timer;
    localparam int ADDR_WIDTH = 6, DATA_WIDTH = 32;
    logic pclk, presetn, psel, penable, pwrite, irq;
    logic [ADDR_WIDTH-1:0] paddr;
    logic [DATA_WIDTH-1:0] pwdata, prdata;
    logic pready, pslverr;

    localparam logic [ADDR_WIDTH-1:0]
        REG_CTRL=6'h00, REG_LOAD=6'h04, REG_COUNT=6'h08, REG_COMPARE=6'h0C,
        REG_INTEN=6'h10, REG_INTSTAT=6'h14, REG_PRESCALER=6'h18;

    apb_timer #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) dut (
        .pclk_i(pclk), .presetn_i(presetn), .paddr_i(paddr), .psel_i(psel),
        .penable_i(penable), .pwrite_i(pwrite), .pwdata_i(pwdata),
        .prdata_o(prdata), .pready_o(pready), .pslverr_o(pslverr), .irq_o(irq)
    );

    always #5 pclk = ~pclk;   // 100MHz clock

    task apb_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
        @(posedge pclk); paddr<=addr; pwrite<=1'b1; psel<=1'b1; penable<=1'b0; pwdata<=data;
        @(posedge pclk); penable<=1'b1;
        @(posedge pclk); psel<=1'b0; penable<=1'b0;
    endtask

    task apb_read(input [ADDR_WIDTH-1:0] addr, output [DATA_WIDTH-1:0] data);
        @(posedge pclk); paddr<=addr; pwrite<=1'b0; psel<=1'b1; penable<=1'b0;
        @(posedge pclk); penable<=1'b1;
        @(posedge pclk); data=prdata; psel<=1'b0; penable<=1'b0;
    endtask

    logic [DATA_WIDTH-1:0] read_val;
    initial begin
        $dumpfile("timer_waves.vcd"); $dumpvars(0, tb_apb_timer);
        pclk=0; presetn=0; psel=0; penable=0; pwrite=0; paddr=0; pwdata=0;
        #20 presetn = 1;
        $display("--- Reset Released ---");

        // TEST 1: Basic count-up (no prescaler, compare = 10, one-shot)
        apb_write(REG_PRESCALER, 32'd0);
        apb_write(REG_COMPARE,   32'd10);
        apb_write(REG_LOAD,      32'd0);
        apb_write(REG_CTRL,      32'b01);   // Enable=1, Auto-reload=0
        #200;
        apb_read(REG_COUNT, read_val);
        $display("[TEST 1] Counter after run (one-shot, expect stuck at 10): %0d", read_val);

        // TEST 2: Interrupt on compare match
        apb_write(REG_INTEN, 32'b1);
        #50;
        $display("[TEST 2] IRQ after enabling INTEN post-match: %b (Expected: 1)", irq);
        apb_write(REG_INTSTAT, 32'b1);
        #20;
        $display("[TEST 2] IRQ after W1C clear: %b (Expected: 0)", irq);

        // TEST 3: Auto-reload mode
        apb_write(REG_CTRL, 32'b00);        // Disable first
        apb_write(REG_COMPARE, 32'd5);
        apb_write(REG_LOAD, 32'd0);
        apb_write(REG_CTRL, 32'b11);        // Enable=1, Auto-reload=1
        #150;
        apb_read(REG_COUNT, read_val);
        $display("[TEST 3] Counter in auto-reload mode (should be cycling, not stuck): %0d", read_val);

        // TEST 4: Prescaler check (divide by 4)
        apb_write(REG_CTRL, 32'b00);
        apb_write(REG_PRESCALER, 32'd3);    // Tick every 4 cycles
        apb_write(REG_COMPARE, 32'd2);
        apb_write(REG_LOAD, 32'd0);
        apb_write(REG_CTRL, 32'b01);
        #100;
        apb_read(REG_COUNT, read_val);
        $display("[TEST 4] Counter with prescaler=3 (should be slower to reach compare): %0d", read_val);

        // CORNER CASE: compare = 0 (interrupt should fire almost immediately)
        apb_write(REG_CTRL, 32'b00);
        apb_write(REG_PRESCALER, 32'd0);
        apb_write(REG_COMPARE, 32'd0);
        apb_write(REG_LOAD, 32'd0);
        apb_write(REG_INTSTAT, 32'hFFFFFFFF); // clear any pending
        apb_write(REG_CTRL, 32'b01);
        #30;
        $display("[CORNER] IRQ with compare=0 (Expected: 1 almost immediately): %b", irq);

        $display("--- ALL TIMER TESTS COMPLETED ---");
        $finish;
    end
endmodule
