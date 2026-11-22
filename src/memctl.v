/*
 * Copyright (c) 2026 HoaLEO
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Bộ điều khiển bộ nhớ: nhận yêu cầu từ CPU và chuyển tới đúng nơi.
//
// Bản đồ bộ nhớ:
//   0x0000_0000 - 0x00FF_FFFF : flash SPI (CS0)  - chứa chương trình, chỉ đọc
//   0x0100_0000 - 0x01FF_FFFF : RAM SPI   (CS1)  - dữ liệu, đọc/ghi
//   0x0200_0000 - ...         : cổng I/O
//        ghi : byte thấp được chốt ra 8 chân uo_out
//        đọc : trả về giá trị 8 chân ui_in
// Ghi vào vùng flash bị bỏ qua.
module memctl (
    input  wire        clk,
    input  wire        rst,
    // Phía CPU
    input  wire        mem_valid,
    input  wire        mem_we,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [1:0]  mem_size,
    output wire        mem_ready,
    output wire [31:0] mem_rdata,
    // Cổng I/O
    output reg  [7:0]  gpio_out,
    input  wire [7:0]  gpio_in,
    // Chân SPI
    output wire        spi_sck,
    output wire        spi_mosi,
    input  wire        spi_miso,
    output wire        cs_flash_n,
    output wire        cs_ram_n
);
    wire is_io      = mem_addr[25];
    wire is_ram     = mem_addr[24] & ~is_io;
    wire flash_wr   = mem_we & ~is_io & ~is_ram;   // ghi vào flash: bỏ qua
    wire fast       = is_io | flash_wr;            // xong ngay, không cần SPI

    wire        spi_busy, spi_done;
    wire [31:0] spi_rdata;

    // Đọc luôn lấy cả từ 32 bit tại địa chỉ đã căn 4 byte
    wire [23:0] spi_addr  = mem_we ? mem_addr[23:0] : {mem_addr[23:2], 2'b00};
    wire [1:0]  nbytes_m1 = (mem_size == 2'd2) ? 2'd3 : mem_size;

    spi_master u_spi (
        .clk       (clk),
        .rst       (rst),
        .start     (mem_valid & ~fast & ~spi_busy & ~spi_done),
        .write     (mem_we),
        .sel_ram   (is_ram),
        .addr      (spi_addr),
        .wdata     (mem_wdata),
        .nbytes_m1 (nbytes_m1),
        .busy      (spi_busy),
        .done      (spi_done),
        .rdata     (spi_rdata),
        .spi_sck   (spi_sck),
        .spi_mosi  (spi_mosi),
        .spi_miso  (spi_miso),
        .cs_flash_n(cs_flash_n),
        .cs_ram_n  (cs_ram_n)
    );

    // Truy cập nhanh (I/O hoặc ghi flash) xong sau 1 chu kỳ
    reg fast_done;
    always @(posedge clk) begin
        if (rst) begin
            fast_done <= 1'b0;
            gpio_out  <= 8'd0;
        end else begin
            fast_done <= mem_valid & fast & ~fast_done;
            if (mem_valid & is_io & mem_we & ~fast_done)
                gpio_out <= mem_wdata[7:0];
        end
    end

    assign mem_ready = spi_done | fast_done;

    // Byte đầu tiên nhận qua SPI là byte có địa chỉ thấp nhất -> đảo thành little-endian
    wire [31:0] spi_word = {spi_rdata[7:0], spi_rdata[15:8], spi_rdata[23:16], spi_rdata[31:24]};
    assign mem_rdata = is_io ? {24'd0, gpio_in} : spi_word;

    wire _unused = &{mem_addr[31:26], 1'b0};
endmodule
