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

