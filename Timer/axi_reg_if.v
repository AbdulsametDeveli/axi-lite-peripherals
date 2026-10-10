module axi_reg_if #(
  parameter ADDR_BITS = 5,
  parameter DATA_BITS = 32
)(
  // Global
  input  wire                  clk,
  input  wire                  rst_n,
  // Write address channel
  input  wire [ADDR_BITS-1:0]  s_awaddr,
  input  wire                  s_awvalid,
  output reg                   s_awready,
  // Write data channel
  input  wire [DATA_BITS-1:0]  s_wdata,
  input  wire [DATA_BITS/8-1:0] s_wstrb,
  input  wire                  s_wvalid,
  output reg                   s_wready,
  // Write response channel
  output reg  [1:0]            s_bresp,
  output reg                   s_bvalid,
  input  wire                  s_bready,
  // Read address channel
  input  wire [ADDR_BITS-1:0]  s_araddr,
  input  wire                  s_arvalid,
  output reg                   s_arready,
  // Read data channel
  output reg  [DATA_BITS-1:0]  s_rdata,
  output reg  [1:0]            s_rresp,
  output reg                   s_rvalid,
  input  wire                  s_rready,

  // Register interface (İSİMLER ŞARTNAMEYE GÖRE GÜNCELLENDİ)
  output reg  [DATA_BITS-1:0]  reg_pre,    // TIM_PRE
  output reg  [DATA_BITS-1:0]  reg_ar,     // TIM_ARE
  output reg                   reg_clr,    // TIM_CLR
  output reg                   reg_ena,    // TIM_ENA <-- DEĞİŞİKLİK
  output reg                   reg_mod,    // TIM_MOD
  output reg                   reg_evc,    // TIM_EVC
  input  wire [DATA_BITS-1:0]  reg_cnt,    // timer_core.count
  input  wire [DATA_BITS-1:0]  reg_evn     // timer_core.evt_count <-- DEĞİŞİKLİK
);
  //------------------------------------------------------------------------
  //  Address slicing: byte-address → word-index
  //------------------------------------------------------------------------
  localparam ADDR_LSB      = $clog2(DATA_BITS/8);
  localparam REG_ADDR_BITS = ADDR_BITS-ADDR_LSB;

  //------------------------------------------------------------------------
  //  Write FSM & Decode (Write tarafında sorun yoktu)
  //------------------------------------------------------------------------
  reg                   aw_en, w_en;
  wire                  write_fire = aw_en & w_en;
  reg  [REG_ADDR_BITS-1:0] awaddr_reg;

  always @(posedge clk) begin
    if (!rst_n) begin
      aw_en     <= 1'b0; w_en      <= 1'b0; s_awready <= 1'b1; s_wready  <= 1'b1; s_bvalid  <= 1'b0; s_bresp   <= 2'b00;
    end else begin
      if (s_awvalid && s_awready) begin
        aw_en        <= 1'b1; awaddr_reg   <= s_awaddr[ADDR_BITS-1:ADDR_LSB]; s_awready    <= 1'b0;
      end else if (s_bvalid && s_bready) begin
        aw_en        <= 1'b0; s_awready    <= 1'b1;
      end

      if (s_wvalid && s_wready) begin
        w_en       <= 1'b1; s_wready   <= 1'b0;
      end else if (s_bvalid && s_bready) begin
        w_en       <= 1'b0; s_wready   <= 1'b1;
      end

      if (write_fire) begin
        s_bvalid <= 1'b1; s_bresp  <= 2'b00;
      end else if (s_bvalid && s_bready) begin
        s_bvalid <= 1'b0;
      end
    end
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      reg_pre <= {DATA_BITS{1'b0}}; reg_ar  <= {DATA_BITS{1'b0}}; reg_clr <= 1'b0;
      reg_ena <= 1'b0;              reg_mod <= 1'b0;              reg_evc <= 1'b0; // <-- DEĞİŞİKLİK: reg_en -> reg_ena
    end
    else if (write_fire) begin
      case(awaddr_reg)
        3'h0: if (s_wstrb == 4'hF) reg_pre <= s_wdata;           // TIM_PRE
        3'h1: if (s_wstrb == 4'hF) reg_ar  <= s_wdata;           // TIM_ARE
        3'h2: if (s_wstrb[0])      reg_clr <= s_wdata[0];         // TIM_CLR
        3'h3: if (s_wstrb[0])      reg_ena <= s_wdata[0];         // TIM_ENA <-- DEĞİŞİKLİK: reg_en -> reg_ena
        3'h4: if (s_wstrb[0])      reg_mod <= s_wdata[0];         // TIM_MOD
        3'h7: if (s_wstrb[0])      reg_evc <= s_wdata[0];         // TIM_EVC
        default:;
      endcase
    end else begin
      reg_clr <= 1'b0;
      reg_evc <= 1'b0;
    end
  end

  //------------------------------------------------------------------------
  //  Read FSM & Decode (TÜM MANTIK DÜZELTİLDİ)
  //------------------------------------------------------------------------
  // <-- DÜZELTME BAŞLANGICI
  reg                   ar_en;
  reg  [REG_ADDR_BITS-1:0] araddr_reg;

  // --- Read FSM (AR/R channels) - Hatasız Versiyon ---
  always @(posedge clk) begin
    if (!rst_n) begin
      ar_en     <= 1'b0;
      s_arready <= 1'b1;
      s_rvalid  <= 1'b0;
      s_rresp   <= 2'b00;
    end else begin
      // Adres kanalı yönetimi
      if (s_arvalid && s_arready) begin
        s_arready  <= 1'b0;
        ar_en      <= 1'b1;
        araddr_reg <= s_araddr[ADDR_BITS-1:ADDR_LSB];
      end

      // Veri kanalı yönetimi
      if (ar_en) begin
        s_rvalid <= 1'b1;
        // Eğer Master datayı aldıysa (handshake bittiyse) FSM'i sıfırla
        if (s_rvalid && s_rready) begin
          ar_en     <= 1'b0;
          s_rvalid  <= 1'b0;
          s_arready <= 1'b1; // Bir sonraki okumaya hazır ol
        end
      end
    end
  end
  // <-- DÜZELTME SONU

  // --- Read Decode (mux out) - RW uyumluluğu sağlandı ---
  always @(*) begin
    case(araddr_reg)
      3'h0:  s_rdata = reg_pre;               // TIM_PRE
      3'h1:  s_rdata = reg_ar;                // TIM_ARE
      3'h2:  s_rdata = {31'd0, reg_clr};      // TIM_CLR <-- DEĞİŞİKLİK: RW Uyumlu
      3'h3:  s_rdata = {31'd0, reg_ena};      // TIM_ENA <-- DEĞİŞİKLİK: reg_en -> reg_ena
      3'h4:  s_rdata = {31'd0, reg_mod};      // TIM_MOD
      3'h5:  s_rdata = reg_cnt;               // TIM_CNT (RO)
      3'h6:  s_rdata = reg_evn;               // TIM_EVN (RO) <-- DEĞİŞİKLİK
      3'h7:  s_rdata = {31'd0, reg_evc};      // TIM_EVC <-- DEĞİŞİKLİK: RW Uyumlu
      default: s_rdata = 32'd0;
    endcase
  end

endmodule