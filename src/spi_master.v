/*
 * Copyright (c) 2026 HoaLEO
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// SPI master đơn giản (mode 0, 1 bit dữ liệu) cho flash và RAM nối tiếp.
//
// Mỗi giao dịch gồm: lệnh 8 bit, địa chỉ 24 bit, rồi 1..4 byte dữ liệu.
//   - Đọc: lệnh 0x03 (READ), luôn đọc 4 byte.
//   - Ghi: lệnh 0x02 (WRITE), ghi nbytes_m1 + 1 byte, byte thấp của wdata gửi trước.
//
// SCK = clk / 2. MOSI đổi ở cạnh xuống của SCK, MISO được lấy mẫu ở cạnh lên.
// rdata giữ 32 bit nhận cuối cùng, byte đầu tiên nhận được nằm ở bit [31:24].
module spi_master (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire        write,
    input  wire        sel_ram,      // 0: flash (CS0), 1: RAM (CS1)
    input  wire [23:0] addr,
    input  wire [31:0] wdata,
    input  wire [1:0]  nbytes_m1,
    output reg         busy,
    output reg         done,         // lên 1 trong đúng một chu kỳ khi xong
    output reg  [31:0] rdata,
    output reg         spi_sck,
    output wire        spi_mosi,
    input  wire        spi_miso,
    output reg         cs_flash_n,
    output reg         cs_ram_n
);
    reg [63:0] sh;      // thanh ghi dịch dữ liệu gửi đi
    reg [5:0]  cnt;     // số bit còn lại trừ 1

    assign spi_mosi = sh[63];

    // Byte có địa chỉ thấp nhất (wdata[7:0]) được gửi đầu tiên
    wire [31:0] wbytes = {wdata[7:0], wdata[15:8], wdata[23:16], wdata[31:24]};

    always @(posedge clk) begin
        if (rst) begin
            busy       <= 1'b0;
            done       <= 1'b0;
            sh         <= 64'd0;
            cnt        <= 6'd0;
            rdata      <= 32'd0;
            spi_sck    <= 1'b0;
            cs_flash_n <= 1'b1;
            cs_ram_n   <= 1'b1;
        end else begin
            done <= 1'b0;
            if (!busy) begin
                if (start) begin
                    busy       <= 1'b1;
                    sh         <= {(write ? 8'h02 : 8'h03), addr, wbytes};
                    // Tổng số bit = 32 + 8 * (nbytes_m1 + 1)
                    cnt        <= 6'd39 + {1'b0, nbytes_m1, 3'b000};
                    cs_flash_n <= sel_ram;
                    cs_ram_n   <= ~sel_ram;
                end
            end else if (!spi_sck) begin
                // Cạnh lên SCK: lấy mẫu MISO
                spi_sck <= 1'b1;
                rdata   <= {rdata[30:0], spi_miso};
            end else begin
                // Cạnh xuống SCK: đẩy bit kế tiếp ra MOSI
                spi_sck <= 1'b0;
                sh      <= {sh[62:0], 1'b0};
                if (cnt == 6'd0) begin
                    busy       <= 1'b0;
                    done       <= 1'b1;
                    cs_flash_n <= 1'b1;
                    cs_ram_n   <= 1'b1;
                end else begin
                    cnt <= cnt - 6'd1;
                end
            end
        end
    end
endmodule
