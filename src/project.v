/*
 * Copyright (c) 2026 HoaLEO
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Module top cho Tiny Tapeout: CPU RV32E + bộ nhớ SPI ngoài.
//
// Chân uio theo chuẩn QSPI Pmod của Tiny Tapeout (dùng ở chế độ SPI 1 bit):
//   uio[0] CS0  -> flash (chương trình)
//   uio[1] MOSI
//   uio[2] MISO
//   uio[3] SCK
//   uio[6] CS1  -> RAM (dữ liệu)
// uo_out : cổng ra 8 bit (CPU ghi vào địa chỉ 0x0200_0000)
// ui_in  : cổng vào 8 bit (CPU đọc từ địa chỉ 0x0200_0000)
module tt_um_hoaleo_rv32e (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
    wire rst = ~rst_n;

    wire        mem_valid, mem_we, mem_ready;
    wire [31:0] mem_addr, mem_wdata, mem_rdata;
    wire [1:0]  mem_size;

    rv32e_cpu u_cpu (
        .clk      (clk),
        .rst      (rst),
        .mem_valid(mem_valid),
        .mem_we   (mem_we),
        .mem_addr (mem_addr),
        .mem_wdata(mem_wdata),
        .mem_size (mem_size),
        .mem_ready(mem_ready),
        .mem_rdata(mem_rdata)
    );

    wire spi_sck, spi_mosi, cs_flash_n, cs_ram_n;

    memctl u_mem (
        .clk       (clk),
        .rst       (rst),
        .mem_valid (mem_valid),
        .mem_we    (mem_we),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_size  (mem_size),
        .mem_ready (mem_ready),
        .mem_rdata (mem_rdata),
        .gpio_out  (uo_out),
        .gpio_in   (ui_in),
        .spi_sck   (spi_sck),
        .spi_mosi  (spi_mosi),
        .spi_miso  (uio_in[2]),
        .cs_flash_n(cs_flash_n),
        .cs_ram_n  (cs_ram_n)
    );

    assign uio_out = {1'b0, cs_ram_n, 1'b0, 1'b0, spi_sck, 1'b0, spi_mosi, cs_flash_n};
    assign uio_oe  = 8'b0100_1011;

    wire _unused = &{ena, uio_in[7:3], uio_in[1:0], 1'b0};
endmodule
