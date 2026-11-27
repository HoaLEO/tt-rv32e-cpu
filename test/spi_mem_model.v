`default_nettype none
`timescale 1ns / 1ps

// Mô hình hành vi của một chip nhớ SPI (chỉ dùng cho mô phỏng).
// Hỗ trợ lệnh 0x03 (READ) và 0x02 (WRITE) với địa chỉ 24 bit, SPI mode 0.
// Dùng cho cả flash chứa chương trình (nạp từ file hex) và RAM dữ liệu.
module spi_mem_model #(
    parameter BYTES    = 4096,          // dung lượng, phải là lũy thừa của 2
    parameter LOAD_HEX = 0,             // 1: nạp HEX_FILE (mỗi dòng một từ 32 bit)
    parameter HEX_FILE = "program.hex"
) (
    input  wire cs_n,
    input  wire sck,
    input  wire mosi,
    output reg  miso
);
    reg [7:0]  mem [0:BYTES-1];
    reg [31:0] words [0:BYTES/4-1];

    reg [31:0] hdr;         // lệnh + địa chỉ
    reg [7:0]  cmd;
    reg [23:0] addr;
    reg [7:0]  in_byte;
    reg [7:0]  out_byte;
    integer    bitcnt;      // số bit đã nhận kể từ khi CS xuống
    integer    obit;
    integer    i;

    initial begin
        miso = 1'b0;
        for (i = 0; i < BYTES; i = i + 1) mem[i] = 8'h00;
        if (LOAD_HEX) begin
            for (i = 0; i < BYTES/4; i = i + 1) words[i] = 32'h0000_0013;   // NOP
            $readmemh(HEX_FILE, words);
            for (i = 0; i < BYTES/4; i = i + 1) begin                       // little-endian
                mem[4*i]     = words[i][7:0];
                mem[4*i + 1] = words[i][15:8];
                mem[4*i + 2] = words[i][23:16];
                mem[4*i + 3] = words[i][31:24];
            end
        end
    end

    always @(negedge cs_n) begin
        bitcnt = 0;
        obit   = 0;
        cmd    = 8'h00;
    end

    // Cạnh lên SCK: nhận bit từ MOSI
    always @(posedge sck) begin
        if (!cs_n) begin
            bitcnt = bitcnt + 1;
            if (bitcnt <= 32) begin
                hdr = {hdr[30:0], mosi};
                if (bitcnt == 32) begin
                    cmd      = hdr[31:24];
                    addr     = hdr[23:0];
                    out_byte = mem[addr & (BYTES - 1)];
                    obit     = 0;
                end
            end else if (cmd == 8'h02) begin
                in_byte = {in_byte[6:0], mosi};
                if (((bitcnt - 32) % 8) == 0) begin
                    mem[addr & (BYTES - 1)] = in_byte;
                    addr = addr + 24'd1;
                end
            end
        end
    end

    // Cạnh xuống SCK: đẩy bit dữ liệu ra MISO khi đang đọc
    always @(negedge sck) begin
        if (!cs_n && bitcnt >= 32 && cmd == 8'h03) begin
            miso     = out_byte[7];
            out_byte = {out_byte[6:0], 1'b0};
            obit     = obit + 1;
            if (obit == 8) begin
                obit     = 0;
                addr     = addr + 24'd1;
                out_byte = mem[addr & (BYTES - 1)];
            end
        end
    end
endmodule
