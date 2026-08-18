module apb_gpio #(
    parameter int ADDR_WIDTH = 6,
    parameter int DATA_WIDTH = 32,
    parameter int NUM_GPIOS  = 32
)(
    input  logic                  pclk_i,
    input  logic                  presetn_i,
    input  logic [ADDR_WIDTH-1:0] paddr_i,
    input  logic                  psel_i,
    input  logic                  penable_i,
    input  logic                  pwrite_i,
    input  logic [DATA_WIDTH-1:0] pwdata_i,
    output logic [DATA_WIDTH-1:0] prdata_o,
    output logic                  pready_o,
    output logic                  pslverr_o,

    input  logic [NUM_GPIOS-1:0]  gpio_in_i,
    output logic [NUM_GPIOS-1:0]  gpio_out_o,
    output logic [NUM_GPIOS-1:0]  gpio_oe_o,
    output logic                  irq_o
);

    // Register Address Offsets
    localparam logic [ADDR_WIDTH-1:0] REG_DIR     = 6'h00;
    localparam logic [ADDR_WIDTH-1:0] REG_DATAOUT = 6'h04;
    localparam logic [ADDR_WIDTH-1:0] REG_DATAIN  = 6'h08;
    localparam logic [ADDR_WIDTH-1:0] REG_INTEN   = 6'h0C;
    localparam logic [ADDR_WIDTH-1:0] REG_INTSTAT = 6'h10;
    localparam logic [ADDR_WIDTH-1:0] REG_INTTYPE = 6'h14;

    // Registers
    logic [NUM_GPIOS-1:0] reg_dir;
    logic [NUM_GPIOS-1:0] reg_dataout;
    logic [NUM_GPIOS-1:0] reg_inten;
    logic [NUM_GPIOS-1:0] reg_intstat;
    logic [NUM_GPIOS-1:0] reg_inttype;

    // Input Synchronization
    logic [NUM_GPIOS-1:0] gpio_in_sync1;
    logic [NUM_GPIOS-1:0] gpio_in_sync2;
    logic [NUM_GPIOS-1:0] gpio_in_prev;

    always_ff @(posedge pclk_i or negedge presetn_i) begin
        if (!presetn_i) begin
            gpio_in_sync1 <= '0;
            gpio_in_sync2 <= '0;
            gpio_in_prev  <= '0;
        end else begin
            gpio_in_sync1 <= gpio_in_i;
            gpio_in_sync2 <= gpio_in_sync1;
            gpio_in_prev  <= gpio_in_sync2;
        end
    end

    // APB Bus Interface
    assign pready_o  = 1'b1;
    assign pslverr_o = 1'b0;

    // APB Write & Interrupt Detection Logic
    always_ff @(posedge pclk_i or negedge presetn_i) begin
        if (!presetn_i) begin
            reg_dir     <= '0;
            reg_dataout <= '0;
            reg_inten   <= '0;
            reg_intstat <= '0;
            reg_inttype <= '0;
        end else begin
            for (int i = 0; i < NUM_GPIOS; i++) begin
                if (reg_inten[i]) begin
                    if (reg_inttype[i]) begin
                        if (gpio_in_sync2[i] && !gpio_in_prev[i])
                            reg_intstat[i] <= 1'b1;
                    end else begin
                        if (gpio_in_sync2[i])
                            reg_intstat[i] <= 1'b1;
                    end
                end
            end

            if (psel_i && penable_i && pwrite_i) begin
                case (paddr_i)
                    REG_DIR:     reg_dir     <= pwdata_i[NUM_GPIOS-1:0];
                    REG_DATAOUT: reg_dataout <= pwdata_i[NUM_GPIOS-1:0];
                    REG_INTEN:   reg_inten   <= pwdata_i[NUM_GPIOS-1:0];
                    REG_INTSTAT: reg_intstat <= reg_intstat & ~pwdata_i[NUM_GPIOS-1:0];
                    REG_INTTYPE: reg_inttype <= pwdata_i[NUM_GPIOS-1:0];
                    default: ;
                endcase
            end
        end
    end

    // APB Read Logic
    always_comb begin
        prdata_o = '0;
        if (psel_i && !pwrite_i) begin
            case (paddr_i)
                REG_DIR:     prdata_o[NUM_GPIOS-1:0] = reg_dir;
                REG_DATAOUT: prdata_o[NUM_GPIOS-1:0] = reg_dataout;
                REG_DATAIN:  prdata_o[NUM_GPIOS-1:0] = gpio_in_sync2;
                REG_INTEN:   prdata_o[NUM_GPIOS-1:0] = reg_inten;
                REG_INTSTAT: prdata_o[NUM_GPIOS-1:0] = reg_intstat;
                REG_INTTYPE: prdata_o[NUM_GPIOS-1:0] = reg_inttype;
                default:     prdata_o                = '0;
            endcase
        end
    end

    assign gpio_out_o = reg_dataout;
    assign gpio_oe_o  = reg_dir;
    assign irq_o      = |reg_intstat;

endmodule