// gpio_axi_lite.v
`include "gpio_defines.v"

module gpio_axi_lite #(
  parameter integer ADDR_WIDTH = `GPIO_ADDRHH + 1,  // default = 5
  parameter integer DATA_WIDTH = 32,
  parameter integer GPIO_WIDTH = `GPIO_IOS          // default = 16
)(
  // AXI4-Lite Slave Port
  input  wire                   s_axi_aclk,
  input  wire                   s_axi_aresetn,
  // Write Address Channel
  input  wire [ADDR_WIDTH-1:0]  s_axi_awaddr,
  input  wire                   s_axi_awvalid,
  output reg                    s_axi_awready,
  // Write Data Channel
  input  wire [DATA_WIDTH-1:0]  s_axi_wdata,
  input  wire [DATA_WIDTH/8-1:0] s_axi_wstrb,
  input  wire                   s_axi_wvalid,
  output reg                    s_axi_wready,
  // Write Response Channel
  output reg [1:0]              s_axi_bresp,
  output reg                    s_axi_bvalid,
  input  wire                   s_axi_bready,
  // Read Address Channel
  input  wire [ADDR_WIDTH-1:0]  s_axi_araddr,
  input  wire                   s_axi_arvalid,
  output reg                    s_axi_arready,
  // Read Data Channel
  output reg [DATA_WIDTH-1:0]   s_axi_rdata,
  output reg [1:0]              s_axi_rresp,
  output reg                    s_axi_rvalid,
  input  wire                   s_axi_rready,
  // GPIO pins
  input  wire [GPIO_WIDTH-1:0]  gpio_in,
  output reg  [GPIO_WIDTH-1:0]  gpio_out,
  output reg  [GPIO_WIDTH-1:0]  gpio_oen
);

  localparam REG_IDR = 0;  // 0x00
  localparam REG_ODR = 1;  // 0x04 (word-aligned)

  // Internal handshake signals
  reg aw_en;
  reg [ADDR_WIDTH-1:0] awaddr_reg;
  reg ar_en;
  reg [ADDR_WIDTH-1:0] araddr_reg;
  integer i;

  // ------------------------------
  // Write Address & Data Channels
  // ------------------------------
  always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
      s_axi_awready <= 1'b0;
      aw_en         <= 1'b1;
    end else begin
      // AWREADY logic
      if (~s_axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en) begin
        s_axi_awready <= 1'b1;
        awaddr_reg    <= s_axi_awaddr;
        aw_en         <= 1'b0;
      end else begin
        s_axi_awready <= 1'b0;
        if (s_axi_bready && s_axi_bvalid)
          aw_en <= 1'b1;
      end
    end
  end

  always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn)
      s_axi_wready <= 1'b0;
    else if (~s_axi_wready && s_axi_wvalid && s_axi_awvalid && aw_en)
      s_axi_wready <= 1'b1;
    else
      s_axi_wready <= 1'b0;
  end

  // B channel
  always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
      s_axi_bvalid <= 1'b0;
      s_axi_bresp  <= 2'b00;
    end else if (s_axi_awready && s_axi_awvalid &&
                 s_axi_wready  && s_axi_wvalid  &&
                 ~s_axi_bvalid) begin
      s_axi_bvalid <= 1'b1;
      s_axi_bresp  <= 2'b00;  // OKAY
    end else if (s_axi_bvalid && s_axi_bready) begin
      s_axi_bvalid <= 1'b0;
    end
  end

  // ------------------------------
  // Read Address & Data Channels
  // ------------------------------
  always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
      s_axi_arready <= 1'b0;
      ar_en         <= 1'b1;
    end else begin
      if (~s_axi_arready && s_axi_arvalid && ar_en) begin
        s_axi_arready <= 1'b1;
        araddr_reg    <= s_axi_araddr;
        ar_en         <= 1'b0;
      end else begin
        s_axi_arready <= 1'b0;
        if (s_axi_rvalid && s_axi_rready)
          ar_en <= 1'b1;
      end
    end
  end

  always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
      s_axi_rvalid <= 1'b0;
      s_axi_rresp  <= 2'b00;
      s_axi_rdata  <= {DATA_WIDTH{1'b0}};
    end else if (s_axi_arready && s_axi_arvalid && ~s_axi_rvalid) begin
      s_axi_rvalid <= 1'b1;
      s_axi_rresp  <= 2'b00;
      case (araddr_reg[ADDR_WIDTH-1:2])
        REG_IDR: s_axi_rdata <= {{(DATA_WIDTH-GPIO_WIDTH){1'b0}}, gpio_in};
        REG_ODR: s_axi_rdata <= {{(DATA_WIDTH-GPIO_WIDTH){1'b0}}, gpio_out};
        default: s_axi_rdata <= {DATA_WIDTH{1'b0}};
      endcase
    end else if (s_axi_rvalid && s_axi_rready) begin
      s_axi_rvalid <= 1'b0;
    end
  end

  // ------------------------------
  // GPIO Output Register Write
  // ------------------------------
  always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
      gpio_out <= {GPIO_WIDTH{1'b0}};
      gpio_oen <= {GPIO_WIDTH{1'b0}};
    end else if (s_axi_awready && s_axi_awvalid &&
                 s_axi_wready  && s_axi_wvalid  &&
                 (awaddr_reg[ADDR_WIDTH-1:2] == REG_ODR)) begin
      // Byte-enable update
      for (i = 0; i < DATA_WIDTH/8; i = i+1) begin
        if (s_axi_wstrb[i])
          gpio_out[i*8 +: 8] <= s_axi_wdata[i*8 +: 8];
      end
      gpio_oen <= {GPIO_WIDTH{1'b1}};  // hep çıkış etkin
    end
  end

endmodule
