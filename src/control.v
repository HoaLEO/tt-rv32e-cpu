// Control unit: giải mã opcode thành các tín hiệu điều khiển datapath.
module control (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire       funct7_5,     // instr[30]
    output reg        reg_write,    // ghi kết quả vào thanh ghi rd
    output reg        alu_a_pc,     // 1: toán hạng A của ALU là PC, 0: rs1
    output reg        alu_b_imm,    // 1: toán hạng B của ALU là immediate, 0: rs2
    output reg  [3:0] alu_op,
    output reg        mem_write,    // lệnh store
    output reg  [1:0] wb_sel,       // nguồn dữ liệu ghi về thanh ghi
    output reg        branch,       // lệnh rẽ nhánh có điều kiện
    output reg        jal,
    output reg        jalr
);
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_IMM    = 7'b0010011;
    localparam OP_REG    = 7'b0110011;

    localparam WB_ALU = 2'd0;   // kết quả ALU
    localparam WB_MEM = 2'd1;   // dữ liệu đọc từ bộ nhớ
    localparam WB_PC4 = 2'd2;   // PC + 4 (địa chỉ trả về của JAL/JALR)
    localparam WB_IMM = 2'd3;   // immediate (LUI)

    always @* begin
        // Giá trị mặc định: lệnh không hợp lệ hoặc FENCE/ECALL sẽ chạy như NOP
        reg_write = 1'b0;
        alu_a_pc  = 1'b0;
        alu_b_imm = 1'b0;
        alu_op    = 4'b0000;
        mem_write = 1'b0;
        wb_sel    = WB_ALU;
        branch    = 1'b0;
        jal       = 1'b0;
        jalr      = 1'b0;

        case (opcode)
            OP_LUI: begin
                reg_write = 1'b1;
                wb_sel    = WB_IMM;
            end
            OP_AUIPC: begin
                reg_write = 1'b1;
                alu_a_pc  = 1'b1;       // PC + imm
                alu_b_imm = 1'b1;
            end
            OP_JAL: begin
                reg_write = 1'b1;
                jal       = 1'b1;
                wb_sel    = WB_PC4;
            end
            OP_JALR: begin
                reg_write = 1'b1;
                jalr      = 1'b1;
                alu_b_imm = 1'b1;       // rs1 + imm
                wb_sel    = WB_PC4;
            end
            OP_BRANCH: begin
                branch    = 1'b1;
                alu_op    = 4'b1000;    // ALU tính rs1 - rs2 để lấy cờ eq / lt / ltu
            end
            OP_LOAD: begin
                reg_write = 1'b1;
                alu_b_imm = 1'b1;       // địa chỉ = rs1 + imm
                wb_sel    = WB_MEM;
            end
            OP_STORE: begin
                mem_write = 1'b1;
                alu_b_imm = 1'b1;       // địa chỉ = rs1 + imm
            end
            OP_IMM: begin
                reg_write = 1'b1;
                alu_b_imm = 1'b1;
                // Chỉ lệnh dịch phải (funct3 = 101) mới dùng bit funct7 để phân biệt SRLI/SRAI
                alu_op    = (funct3 == 3'b101) ? {funct7_5, funct3} : {1'b0, funct3};
            end
            OP_REG: begin
                reg_write = 1'b1;
                alu_op    = {funct7_5, funct3};
            end
            default: ;
        endcase
    end
endmodule
