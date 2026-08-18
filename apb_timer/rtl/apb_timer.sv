module apb_timer #(
    parameter int ADDR_WIDTH = 6,
    parameter int DATA_WIDTH = 32
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
    output logic                  irq_o
);
    localparam logic [ADDR_WIDTH-1:0] REG_CTRL      = 6'h00;
    localparam logic [ADDR_WIDTH-1:0] REG_LOAD      = 6'h04;
    localparam logic [ADDR_WIDTH-1:0] REG_COUNT     = 6'h08;
    localparam logic [ADDR_WIDTH-1:0] REG_COMPARE   = 6'h0C;
    localparam logic [ADDR_WIDTH-1:0] REG_INTEN     = 6'h10;
    localparam logic [ADDR_WIDTH-1:0] REG_INTSTAT   = 6'h14;
    localparam logic [ADDR_WIDTH-1:0] REG_PRESCALER = 6'h18;

    logic [DATA_WIDTH-1:0] reg_ctrl, reg_load, reg_compare;
    logic [DATA_WIDTH-1:0] reg_inten, reg_intstat, reg_prescaler;
    logic [DATA_WIDTH-1:0] counter, prescale_cnt;
    logic tick;
    logic match_now, match_prev;
    logic ctrl_en_prev, ctrl_en_rising;

    assign pready_o  = 1'b1;
    assign pslverr_o = 1'b0;
    assign match_now = (counter >= reg_compare);
    assign ctrl_en_rising = reg_ctrl[0] && !ctrl_en_prev;

    // Track previous enable-bit value, to detect the "just turned on" edge
    always_ff @(posedge pclk_i or negedge presetn_i) begin
        if (!presetn_i) ctrl_en_prev <= 1'b0;
        else            ctrl_en_prev <= reg_ctrl[0];
    end

    always_ff @(posedge pclk_i or negedge presetn_i) begin
        if (!presetn_i) begin
            prescale_cnt <= '0;
            tick <= 1'b0;
        end else if (reg_ctrl[0]) begin
            if (prescale_cnt >= reg_prescaler) begin
                prescale_cnt <= '0;
                tick <= 1'b1;
            end else begin
                prescale_cnt <= prescale_cnt + 1'b1;
                tick <= 1'b0;
            end
        end else begin
            tick <= 1'b0;
        end
    end

    always_ff @(posedge pclk_i or negedge presetn_i) begin
        if (!presetn_i) begin
            counter <= '0;
        end else if (ctrl_en_rising) begin
            counter <= reg_load;              // Fresh restart on enable
        end else if (reg_ctrl[0] && tick) begin
            if (match_now) begin
                if (reg_ctrl[1])
                    counter <= reg_load;
            end else begin
                counter <= counter + 1'b1;
            end
        end
    end

    always_ff @(posedge pclk_i or negedge presetn_i) begin
        if (!presetn_i)
            match_prev <= 1'b0;
        else if (ctrl_en_rising)
            match_prev <= 1'b0;               // Clear stale match state on restart
        else if (reg_ctrl[0] && tick)
            match_prev <= match_now;
    end

    always_ff @(posedge pclk_i or negedge presetn_i) begin
        if (!presetn_i) begin
            reg_ctrl <= '0; reg_load <= '0; reg_compare <= '0;
            reg_inten <= '0; reg_intstat <= '0; reg_prescaler <= '0;
        end else begin
            if (reg_ctrl[0] && tick && match_now && !match_prev)
                reg_intstat[0] <= 1'b1;

            if (psel_i && penable_i && pwrite_i) begin
                case (paddr_i)
                    REG_CTRL:      reg_ctrl      <= pwdata_i;
                    REG_LOAD:      reg_load      <= pwdata_i;
                    REG_COMPARE:   reg_compare   <= pwdata_i;
                    REG_INTEN:     reg_inten     <= pwdata_i;
                    REG_INTSTAT:   reg_intstat   <= reg_intstat & ~pwdata_i;
                    REG_PRESCALER: reg_prescaler <= pwdata_i;
                    default: ;
                endcase
            end
        end
    end

    always_comb begin
        prdata_o = '0;
        if (psel_i && !pwrite_i) begin
            case (paddr_i)
                REG_CTRL:      prdata_o = reg_ctrl;
                REG_LOAD:      prdata_o = reg_load;
                REG_COUNT:     prdata_o = counter;
                REG_COMPARE:   prdata_o = reg_compare;
                REG_INTEN:     prdata_o = reg_inten;
                REG_INTSTAT:   prdata_o = reg_intstat;
                REG_PRESCALER: prdata_o = reg_prescaler;
                default:       prdata_o = '0;
            endcase
        end
    end

    assign irq_o = |(reg_intstat & reg_inten);
endmodule
