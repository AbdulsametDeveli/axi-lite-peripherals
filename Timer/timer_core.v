module timer_core ( 
  input  wire        clk,
  input  wire        rst_n,
  input  wire [31:0] prescale,    // TIM_PRE
  input  wire [31:0] auto_reload, // TIM_ARE
  input  wire        clear,       // TIM_CLR
  input  wire        ena,         // TIM_ENA <-- DEĞİŞİKLİK
  input  wire        mode_up,     // TIM_MOD
  input  wire        evc,         // TIM_EVC <-- DEĞİŞİKLİK
  output reg  [31:0] count,       // TIM_CNT
  output reg  [31:0] evn,         // TIM_EVN <-- DEĞİŞİKLİK
  output wire        irq_out
);
  //------------------------------------------------------------------------
  //  Prescaler
  //------------------------------------------------------------------------
  reg [31:0] presc_cnt;
  wire       tick = (presc_cnt == prescale);

  always @(posedge clk) begin
    if (!rst_n || clear) begin
      presc_cnt <= 32'd0;
    end
    else if (tick) begin
      presc_cnt <= 32'd0;
    end
    else if (ena) begin // <-- DEĞİŞİKLİK
      presc_cnt <= presc_cnt + 1;
    end
  end

  //------------------------------------------------------------------------
  //  Main counter
  //------------------------------------------------------------------------
  wire roll_pulse = ena && tick && !clear && ((mode_up && count == auto_reload) || (!mode_up  && count == 0)); // <-- DEĞİŞİKLİK

  always @(posedge clk) begin
    if (!rst_n || clear) begin
      count <= 32'd0;
    end
    else if (ena && tick) begin // <-- DEĞİŞİKLİK
      if (mode_up) begin
        count <= (count == auto_reload) ? 32'd0 : count + 1;
      end else begin
        count <= (count == 32'd0) ? auto_reload : count - 1;
      end
    end
  end

  //------------------------------------------------------------------------
  //  Event counter
  //------------------------------------------------------------------------
  always @(posedge clk) begin
    if (!rst_n || evc) begin // <-- DEĞİŞİKLİK
      evn <= 32'd0;          // <-- DEĞİŞİKLİK
    end
    else if (roll_pulse) begin
      evn <= evn + 1;        // <-- DEĞİŞİKLİK
    end
  end

  //------------------------------------------------------------------------
  //  IRQ output = rollover pulse
  //------------------------------------------------------------------------
  assign irq_out = roll_pulse;

endmodule