
`timescale 1ns/1ps
`include "gpio_defines.v"

module tb_gpio_axi;
  // AXI4-Lite signals
  reg            aclk    = 0;
  reg            aresetn = 0;

  // Write Address channel
  reg  [4:0]     awaddr  = 0;
  reg            awvalid = 0;
  wire           awready;

  // Write Data channel
  reg  [15:0]    wdata   = 0;
  reg            wvalid  = 0;
  reg  [3:0]     wstrb   = 4'h0;
  wire           wready;

  // Write Resp channel
  wire [1:0]     bresp;
  wire           bvalid;
  reg            bready  = 0;

  // Read Address channel
  reg  [4:0]     araddr  = 0;
  reg            arvalid = 0;
  wire           arready;

  // Read Data channel
  wire [15:0]    rdata;
  wire           rvalid;
  reg            rready  = 0;
  wire [1:0]     rresp;

  // GPIO pins
  reg  [15:0]    gpio_in  = 16'h0000;
  wire [15:0]    gpio_out, gpio_oen;

  // Clock gen
  always #5 aclk = ~aclk;

  // DUT instantiation
  gpio_axi_lite #(
    .ADDR_WIDTH (5),
    .DATA_WIDTH (32),
    .GPIO_WIDTH (16)
  ) dut (
    .s_axi_aclk    (aclk),
    .s_axi_aresetn (aresetn),

    .s_axi_awaddr  (awaddr),
    .s_axi_awvalid (awvalid),
    .s_axi_awready (awready),

    .s_axi_wdata   (wdata),
    .s_axi_wstrb   (wstrb),
    .s_axi_wvalid  (wvalid),
    .s_axi_wready  (wready),

    .s_axi_bresp   (bresp),
    .s_axi_bvalid  (bvalid),
    .s_axi_bready  (bready),

    .s_axi_araddr  (araddr),
    .s_axi_arvalid (arvalid),
    .s_axi_arready (arready),

    .s_axi_rdata   (rdata),
    .s_axi_rresp   (rresp),
    .s_axi_rvalid  (rvalid),
    .s_axi_rready  (rready),

    .gpio_in       (gpio_in),
    .gpio_out      (gpio_out),
    .gpio_oen      (gpio_oen)
  );

  // ---------- AXI4-Lite write task ----------
  task axi_write(input [4:0] addr, input [15:0] data);
    begin
      // Drive AW & W valid
      @(posedge aclk);
      awaddr  <= addr;
      awvalid <= 1;
      wdata   <= data;
      wstrb   <= 4'hF;
      wvalid  <= 1;
      bready  <= 0;
      // Wait for handshake
      wait(awready && wready);
      @(posedge aclk);
      awvalid <= 0;
      wvalid  <= 0;
      // Accept write response
      bready  <= 1;
      wait(bvalid);
      @(posedge aclk);
      bready <= 0;
    end
  endtask

  // ---------- AXI4-Lite read task ----------
  task axi_read(input  [4:0] addr,
                output [15:0] data);
    begin
      // Drive AR valid
      @(posedge aclk);
      araddr  <= addr;
      arvalid <= 1;
      rready  <= 0;
      // Wait for ARREADY
      wait(arready);
      @(posedge aclk);
      arvalid <= 0;
      // Accept read data
      rready  <= 1;
      wait(rvalid);
      data    <= rdata;
      @(posedge aclk);
      rready <= 0;
    end
  endtask

  // ---------- Test sequence ----------
  integer rd;
  initial begin
    // 1) Reset
    aresetn = 0;
    #20 aresetn = 1;

    // 2) Pre-load GPIO inputs
    gpio_in = 16'h5A5A;

    // 3) Read IDR @ 0x00
    axi_read(5'd0, rd);
    $display("IDR = 0x%h (expected 5A5A)", rd[15:0]);

    // 4) Write ODR @ 0x04
    axi_write(5'd4, 16'hDEAD);
    #10;
    $display("GPIO_OUT = 0x%h (expected CAFE)", gpio_out);

    // 5) Read back ODR @ 0x04
    axi_read(5'd4, rd);
    $display("ODR Readback = 0x%h (expected CAFE)", rd[15:0]);

    #50 $finish;
  end

endmodule
