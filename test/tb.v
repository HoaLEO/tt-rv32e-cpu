`default_nettype none
`timescale 1ns / 1ps

/* Testbench: CPU tt_um_hoaleo_rv32e nối với hai chip nhớ SPI mô phỏng
   (flash chứa program.hex và RAM dữ liệu). cocotb (test.py) lo clock và reset,
   rồi chờ chương trình ghi kết quả ra uo_out: 0x01 = PASS, 0xFF = FAIL.
*/
module tb ();

  // Dump the signals to a FST file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  // cocotb đặt dump_on = 0 để ngừng ghi dạng sóng khi chạy bộ test dài
  reg dump_on = 1'b1;
  always @(negedge dump_on) $dumpoff;

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  wire [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  tt_um_hoaleo_rv32e user_project (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

  // ---------------- Bộ nhớ SPI mô phỏng ----------------
  wire cs_flash_n = uio_out[0];
  wire spi_mosi   = uio_out[1];
  wire spi_sck    = uio_out[3];
  wire cs_ram_n   = uio_out[6];
  wire flash_miso, ram_miso;

  spi_mem_model #(.BYTES(16384), .LOAD_HEX(1), .HEX_FILE("program.hex")) flash (
      .cs_n(cs_flash_n), .sck(spi_sck), .mosi(spi_mosi), .miso(flash_miso)
  );

  spi_mem_model #(.BYTES(4096), .LOAD_HEX(0)) ram (
      .cs_n(cs_ram_n), .sck(spi_sck), .mosi(spi_mosi), .miso(ram_miso)
  );

  // MISO đi chung một dây: chip nào đang được chọn thì lái dây đó
  wire spi_miso = !cs_flash_n ? flash_miso : (!cs_ram_n ? ram_miso : 1'b0);
  assign uio_in = {5'b0, spi_miso, 2'b0};

endmodule
