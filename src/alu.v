// ALU tiết kiệm diện tích.
// op = {funct7[5], funct3} của lệnh RISC-V.
//
// So với bản đầu tiên:
//  - Chỉ có MỘT bộ cộng 33 bit dùng chung cho ADD, SUB, SLT, SLTU và so sánh rẽ nhánh.
//  - Chỉ có MỘT bộ dịch phải. Dịch trái (SLL) = đảo thứ tự bit, dịch phải, đảo lại.
//  - Xuất thêm cờ eq / lt / ltu để khối core dùng cho lệnh rẽ nhánh,
//    thay vì xây bộ so sánh riêng.
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  op,
    output reg  [31:0] y,
    output wire        eq,    // a == b   (đúng khi op là phép trừ)
    output wire        lt,    // a <  b, có dấu
    output wire        ltu    // a <  b, không dấu
);
    // ---------------- Bộ cộng / trừ dùng chung ----------------
    // Trừ khi: SUB (1000), SLT (x010), SLTU (x011).
    // Khối control cũng đặt op = 1000 cho lệnh rẽ nhánh.
    wire        sub   = (op == 4'b1000) || (op[2:1] == 2'b01);
    wire [31:0] b_eff = sub ? ~b : b;
    wire [32:0] sum   = {1'b0, a} + {1'b0, b_eff} + {32'd0, sub};

    // Với phép trừ a - b: bit nhớ ra (sum[32]) = 1 khi a >= b (không dấu)
    assign ltu = ~sum[32];
    assign lt  = (a[31] == b[31]) ? ltu : a[31];
    assign eq  = (sum[31:0] == 32'd0);

    // ---------------- Bộ dịch dùng chung ----------------
    function [31:0] rev32(input [31:0] x);
        integer i;
        begin
            for (i = 0; i < 32; i = i + 1) rev32[i] = x[31 - i];
        end
    endfunction

    wire        shl     = (op[2:0] == 3'b001);                 // SLL
    wire [31:0] sh_in   = shl ? rev32(a) : a;
    wire        fill    = op[3] & a[31] & ~shl;                // SRA thì điền bit dấu
    wire [32:0] sh_ext  = $signed({fill, sh_in}) >>> b[4:0];
    wire [31:0] sh_r    = sh_ext[31:0];
    wire [31:0] sh_out  = shl ? rev32(sh_r) : sh_r;

    // ---------------- Chọn kết quả ----------------
    always @* begin
        case (op[2:0])
            3'b000:  y = sum[31:0];                // ADD / SUB
            3'b001:  y = sh_out;                   // SLL
            3'b010:  y = {31'd0, lt};              // SLT
            3'b011:  y = {31'd0, ltu};             // SLTU
            3'b100:  y = a ^ b;                    // XOR
            3'b101:  y = sh_out;                   // SRL / SRA
            3'b110:  y = a | b;                    // OR
            default: y = a & b;                    // AND
        endcase
    end
endmodule
