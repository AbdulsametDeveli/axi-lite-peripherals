# AXI-Lite Peripheral IPs

Verilog ile yazılmış, AXI4-Lite arayüzlü üç temel çevre birimi tasarımı:

- **GPIO** — yapılandırılabilir genişlikte giriş/çıkış ve output-enable denetimi
- **I2C** — AXI-Lite master ve slave bloklarını aynı I2C hattında birleştiren örnek sistem
- **Timer** — prescaler, auto-reload, sayaç ve kesme çıkışına sahip AXI-Lite timer

> Bu depo bir eğitim/deneysel HDL çalışmasıdır. FPGA kartı, sentez kısıt dosyaları ve zamanlama kapanışı bu kapsamda değildir.

## Dizin yapısı

```text
.
├── GPIO/
│   ├── gpio_axi_lite.v       # GPIO AXI4-Lite slave
│   ├── gpio_defines.v        # GPIO parametreleri ve sabitleri
│   └── tb_gpio_axi.v         # GPIO testbench
├── i2C/
│   ├── i2c_top_system.v      # Master + slave örnek top-level
│   ├── i2c_master*.v         # I2C master ve AXI-Lite sarmalayıcısı
│   ├── i2c_slave*.v          # I2C slave ve AXI-Lite sarmalayıcısı
│   └── tb.v                  # I2C sistem testbench'i
└── Timer/
    ├── timer_axi_lite_top.v  # Timer top-level
    ├── timer_core.v          # Timer çekirdeği
    ├── axi_reg_if.v          # AXI-Lite register arayüzü
    └── tb_timer_axi_lite_top.v
```

## Gereksinimler

Simülasyon için [Icarus Verilog](https://steveicarus.github.io/iverilog/) (veya Verilog-2001 destekleyen başka bir simülatör) gerekir.

## Simülasyon

Komutları depo kök dizininde çalıştırın.

### GPIO

```powershell
iverilog -g2012 -I GPIO -s tb_gpio_axi -o build/gpio_tb GPIO/gpio_axi_lite.v GPIO/tb_gpio_axi.v
vvp build/gpio_tb
```

### I2C sistemi

```powershell
iverilog -g2012 -s tb -o build/i2c_tb i2C/i2c_master.v i2C/i2c_master_axil.v i2C/i2c_slave.v i2C/i2c_slave_axil.v i2C/i2c_top_system.v i2C/tb.v
vvp build/i2c_tb
```

### Timer

```powershell
iverilog -g2012 -s tb_timer_axi_lite_top -o build/timer_tb Timer/axi_reg_if.v Timer/timer_core.v Timer/timer_axi_lite_top.v Timer/tb_timer_axi_lite_top.v
vvp build/timer_tb
```

Testbench'ler dalga biçimi için `.vcd` dosyaları üretir. Bunları GTKWave ile açabilirsiniz:

```powershell
gtkwave tb_timer.vcd
```

## Çevrimiçi doğrulama sonucu

Timer çekirdeği, 8 Ekim 2026 tarihinde [OneCompiler Verilog](https://onecompiler.com/verilog) üzerinde Icarus Verilog ile bağımsız bir testbench kullanılarak çalıştırıldı. Aşağıdaki kontroller geçti:

| Kontrol | Sonuç |
| --- | --- |
| Yukarı sayım, rollover ve olay sayacı | PASS |
| `TIM_ENA` devre dışıyken sayacın sabit kalması | PASS |
| `TIM_CLR` ile ana sayacın sıfırlanması | PASS |
| `TIM_EVC` ile olay sayacının sıfırlanması | PASS |

Bu çevrimiçi kontrol `Timer/timer_core.v` davranışını kapsar; GPIO, I2C ve AXI-Lite sarmalayıcılarının tam sistem simülasyonunun yerine geçmez.

## Notlar

- Simülasyon çıktıları (`.vcd`, derleme çıktıları) `.gitignore` tarafından depoya alınmaz.
- Lisans eklemek istiyorsanız, kodun paylaşım koşullarına uygun bir `LICENSE` dosyası seçip ekleyin. Başkalarının kodu varsa lisansı izin almadan değiştirmeyin.
