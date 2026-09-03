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
                        reg_intstat <= 1 me;
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
                3 me: prdata = reg_value;
                3'b100: prdata = {{(DATA_WIDTH-1){1'b0}}, reg_intstat};
                default: prdata = '0;
            endcase
        end
    end
endmodule
