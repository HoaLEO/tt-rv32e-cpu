/*
 * Copyright (c) 2026 HoaLEO
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Register file RV32E: 16 thanh ghi x0..x15, mỗi thanh ghi 32 bit.
// 2 cổng đọc (tổ hợp), 1 cổng ghi (đồng bộ theo clk).
// x0 luôn bằng 0 nên không cấp flip-flop cho nó: chỉ lưu x1..x15.
// Chỉ dùng 4 bit thấp của địa chỉ vì RV32E chỉ có 16 thanh ghi.
module regfile (
    input  wire        clk,
    input  wire        we,
    input  wire [3:0]  ra1,
    input  wire [3:0]  ra2,
    input  wire [3:0]  wa,
    input  wire [31:0] wd,
    output wire [31:0] rd1,
    output wire [31:0] rd2
);
    reg [31:0] regs [1:15];

    assign rd1 = (ra1 == 4'd0) ? 32'd0 : regs[ra1];
    assign rd2 = (ra2 == 4'd0) ? 32'd0 : regs[ra2];

    always @(posedge clk) begin
        if (we && wa != 4'd0)
            regs[wa] <= wd;
    end
endmodule
