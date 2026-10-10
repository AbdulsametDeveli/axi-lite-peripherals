module timer_axi_lite_top #(
  parameter ADDR_BITS = 5,
  parameter DATA_BITS = 32
)(
  // Global clock & reset
  input  wire                  aclk,
  input  wire                  aresetn,
  // AXI4-Lite Slave Interface... (Port listesi aynı)
  input  wire [ADDR_BITS-1:0]  s_axi_awaddr,
  input  wire                  s_axi_awvalid,
  output wire                  s_axi_awready,
  input  wire [DATA_BITS-1:0]  s_axi_wdata,
  input  wire [DATA_BITS/8-1:0] s_axi_wstrb,
  input  wire                  s_axi_wvalid,
  output wire                  s_axi_wready,
  output wire [1:0]            s_axi_bresp,
  output wire                  s_axi_bvalid,
  input  wire                  s_axi_bready,
  input  wire [ADDR_BITS-1:0]  s_axi_araddr,
  input  wire                  s_axi_arvalid,
  output wire                  s_axi_arready,
  output wire [DATA_BITS-1:0]  s_axi_rdata,
  output wire [1:0]            s_axi_rresp,
  output wire                  s_axi_rvalid,
  input  wire                  s_axi_rready,
  output wire                  irq_out
);

  // Wire tanımlamaları (Şartnameye uygun isimler) <-- DEĞİŞİKLİK
  wire [DATA_BITS-1:0] timer_pre;
  wire [DATA_BITS-1:0] timer_ar;
  wire                timer_clr;
  wire                timer_ena;
  wire                timer_mod;
  wire                timer_evc;
  wire [DATA_BITS-1:0] timer_cnt;
  wire [DATA_BITS-1:0] timer_evn;

  // AXI↔Reg (Bağlantılar güncellendi) <-- DEĞİŞİKLİK
  axi_reg_if #(
    .ADDR_BITS(ADDR_BITS),
    .DATA_BITS(DATA_BITS)
  ) u_reg_if (
    .clk        (aclk),
    .rst_n      (aresetn),
    // ... AXI portları ...
    .s_awaddr(s_axi_awaddr),.s_awvalid(s_axi_awvalid),.s_awready(s_axi_awready),
    .s_wdata(s_axi_wdata),.s_wstrb(s_axi_wstrb),.s_wvalid(s_axi_wvalid),.s_wready(s_axi_wready),
    .s_bresp(s_axi_bresp),.s_bvalid(s_axi_bvalid),.s_bready(s_axi_bready),
    .s_araddr(s_axi_araddr),.s_arvalid(s_axi_arvalid),.s_arready(s_axi_arready),
    .s_rdata(s_axi_rdata),.s_rresp(s_axi_rresp),.s_rvalid(s_axi_rvalid),.s_rready(s_axi_rready),
    // ... Register portları (yeni isimlerle)...
    .reg_pre    (timer_pre),
    .reg_ar     (timer_ar),
    .reg_clr    (timer_clr),
    .reg_ena    (timer_ena),
    .reg_mod    (timer_mod),
    .reg_evc    (timer_evc),
    .reg_cnt    (timer_cnt),
    .reg_evn    (timer_evn)
  );

  // Timer Core (Bağlantılar güncellendi) <-- DEĞİŞİKLİK
  timer_core u_core (
    .clk         (aclk),
    .rst_n       (aresetn),
    .prescale    (timer_pre),
    .auto_reload (timer_ar),
    .clear       (timer_clr),
    .ena         (timer_ena),
    .mode_up     (timer_mod),
    .evc         (timer_evc),
    .count       (timer_cnt),
    .evn         (timer_evn),
    .irq_out     (irq_out)
  );

endmodule