`timescale 1ns/1ps
module tb_timer_axi_lite_top;
  //-----------------------------------------------------------------------------
  //  Parametreler
  //-----------------------------------------------------------------------------
  parameter ADDR_BITS = 5;
  parameter DATA_BITS = 32;

  //-----------------------------------------------------------------------------
  //  Clock & Reset
  //-----------------------------------------------------------------------------
  reg clk;
  reg rst_n;
  initial begin
    clk   = 0;
    rst_n = 0;
    #100 rst_n = 1;
  end
  always #5 clk = ~clk;

  //-----------------------------------------------------------------------------
  //  AXI-Lite Master ↔ Slave Sinyalleri
  //-----------------------------------------------------------------------------
  // ... Bu bölüm tamamen aynı kalıyor ...
  reg  [ADDR_BITS-1:0]   s_axi_awaddr; reg s_axi_awvalid; wire s_axi_awready;
  reg  [DATA_BITS-1:0]   s_axi_wdata;  reg [DATA_BITS/8-1:0] s_axi_wstrb; reg s_axi_wvalid; wire s_axi_wready;
  wire [1:0]             s_axi_bresp;  wire s_axi_bvalid;    reg s_axi_bready;
  reg  [ADDR_BITS-1:0]   s_axi_araddr; reg s_axi_arvalid; wire s_axi_arready;
  wire [DATA_BITS-1:0]   s_axi_rdata;  wire [1:0] s_axi_rresp; wire s_axi_rvalid; reg s_axi_rready;
  wire irq_out;

  //-----------------------------------------------------------------------------
  //  Device Under Test
  //-----------------------------------------------------------------------------
  // ... Bu bölüm de tamamen aynı kalıyor ...
  timer_axi_lite_top #(
    .ADDR_BITS(ADDR_BITS), .DATA_BITS(DATA_BITS)
  ) dut (
    .aclk(clk), .aresetn(rst_n), .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready), .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready), .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready), .s_axi_araddr(s_axi_araddr),
    .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready), .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
    .irq_out(irq_out)
  );

  //-----------------------------------------------------------------------------
  //  İç sayaç ve event sayaç değerlerini görmek için hiyerarşi <-- DEĞİŞİKLİK
  //-----------------------------------------------------------------------------
  wire [DATA_BITS-1:0] timer_cnt = dut.u_core.count; // Bu isim aynı kaldı
  wire [DATA_BITS-1:0] timer_evn = dut.u_core.evn;   // timer_evt -> timer_evn oldu

  //-----------------------------------------------------------------------------
  //  VCD Dump
  //-----------------------------------------------------------------------------
  initial begin
    $dumpfile("tb_timer.vcd");
    $dumpvars(0, tb_timer_axi_lite_top);
  end

  //-----------------------------------------------------------------------------
  //  AXI-Lite WRITE Task (Aynı kalıyor)
  //-----------------------------------------------------------------------------
  task axi_write;
    input [ADDR_BITS-1:0] addr; input [DATA_BITS-1:0] data;
    begin
      @(posedge clk);
      s_axi_awaddr <= addr; s_axi_awvalid <= 1; s_axi_wdata <= data;
      s_axi_wstrb <= {DATA_BITS/8{1'b1}}; s_axi_wvalid <= 1;
      wait (s_axi_awready && s_axi_wready); @(posedge clk);
      s_axi_awvalid <= 0; s_axi_wvalid <= 0; s_axi_bready <= 1;
      wait (s_axi_bvalid); @(posedge clk);
      s_axi_bready <= 0;
    end
  endtask

  //-----------------------------------------------------------------------------
  //  AXI-Lite READ Task (Aynı kalıyor)
  //-----------------------------------------------------------------------------
  task axi_read;
    input  [ADDR_BITS-1:0] addr; output [DATA_BITS-1:0] data; output [1:0] resp;
    begin
      @(posedge clk);
      s_axi_araddr <= addr; s_axi_arvalid <= 1;
      wait (s_axi_arready); @(posedge clk);
      s_axi_arvalid <= 0; s_axi_rready <= 1;
      wait (s_axi_rvalid);
      data = s_axi_rdata; resp = s_axi_rresp;
      @(posedge clk);
      s_axi_rready <= 0;
    end
  endtask

  //-----------------------------------------------------------------------------  
  //  Test Senaryosu (Yorumlar ve display'ler güncellendi) <-- DEĞİŞİKLİK
  //-----------------------------------------------------------------------------
  reg [DATA_BITS-1:0] read_data;
  reg [1:0]           read_resp;

  initial begin
    s_axi_awaddr  = 0; s_axi_awvalid = 0; s_axi_wdata = 0; s_axi_wstrb  = 0; s_axi_wvalid = 0;
    s_axi_bready  = 0; s_axi_araddr  = 0; s_axi_arvalid = 0; s_axi_rready = 0;

    wait (rst_n == 1);

    // -----------------------------------------
    // 1) Timer register'larını yaz
    // -----------------------------------------
    axi_write(5'h00, 32'd1);   // TIM_PRE = 1
    axi_write(5'h04, 32'd5);   // TIM_ARE = 5
    axi_write(5'h10, 32'd1);   // TIM_MOD = 1 (up-count)
    axi_write(5'h0C, 32'd1);   // TIM_ENA = 1 (başlat)

    // -----------------------------------------
    // 2) Bir süre saydır (20 clock)
    // -----------------------------------------
    repeat (20) @(posedge clk);
    $display("[%0t] After RUN:  count = %0d, evn = %0d, irq = %b",
              $time, timer_cnt, timer_evn, irq_out);

    // -----------------------------------------
    // 3) Disable et, sabit kalmasını kontrol et
    // -----------------------------------------
    axi_write(5'h0C, 32'd0);   // TIM_ENA = 0
    repeat (10) @(posedge clk);
    $display("[%0t] After DISABLE: count = %0d, evn = %0d",
              $time, timer_cnt, timer_evn);

    // -----------------------------------------
    // 4) Clear pulse gönder, sıfırlanmayı kontrol et
    // -----------------------------------------
    axi_write(5'h08, 32'd1);   // TIM_CLR = 1
    @(posedge clk);
    axi_write(5'h08, 32'd0);   // pulse'ı geri çekmek teknik olarak gereksiz, reg_if zaten temizliyor
    @(posedge clk);
    $display("[%0t] After CLEAR:   count = %0d, evn = %0d",
              $time, timer_cnt, timer_evn);

    // -----------------------------------------
    // 5) Register'ları back-read et ve yazdır
    // -----------------------------------------
    axi_read(5'h14, read_data, read_resp);  // TIM_CNT
    $display("[%0t] READ TIM_CNT = %0d (resp=%0b)",
              $time, read_data, read_resp);

    axi_read(5'h18, read_data, read_resp);  // TIM_EVN
    $display("[%0t] READ TIM_EVN = %0d (resp=%0b)",
              $time, read_data, read_resp);
              
    // -----------------------------------------
    // 6) Event counter'ı (TIM_EVN) temizle ve oku
    // -----------------------------------------
    axi_write(5'h1C, 32'd1); // TIM_EVC = 1 (temizle)
    @(posedge clk); // Değişikliğin etkili olması için bir cycle bekle
    axi_read(5'h18, read_data, read_resp); // TIM_EVN'i tekrar oku
    $display("[%0t] READ TIM_EVN after clear = %0d (resp=%0b)",
              $time, read_data, read_resp);

    #50 $finish;
  end

endmodule