/*
 * Copyright (c) 2026 HoaLEO
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// CPU RV32E nhiều chu kỳ (multi-cycle).
//
// Khác với bản một chu kỳ, bộ nhớ nằm ngoài chip và đọc qua SPI nên mất
// hàng trăm chu kỳ clock. CPU dùng một máy trạng thái 3 bước:
//
//   FETCH : gửi yêu cầu đọc lệnh tại PC, chờ mem_ready, chốt lệnh vào thanh ghi instr
//   EXEC  : giải mã + ALU (tổ hợp). Lệnh thường: ghi thanh ghi, cập nhật PC, quay về FETCH.
//           Lệnh load/store: chuyển sang MEM.
//   MEM   : gửi yêu cầu đọc/ghi dữ liệu, chờ mem_ready. Load thì ghi kết quả vào thanh ghi.
//
// Giao tiếp bộ nhớ đơn giản: mem_valid giữ mức 1 cho đến khi mem_ready lên 1 trong một chu kỳ.
// Với lệnh đọc, mem_rdata là từ 32 bit (little-endian) tại địa chỉ đã căn theo 4 byte.
module rv32e_cpu (
    input  wire        clk,
    input  wire        rst,
    output wire        mem_valid,
    output wire        mem_we,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire [1:0]  mem_size,    // 0: byte, 1: half-word, 2: word
    input  wire        mem_ready,
    input  wire [31:0] mem_rdata
);
    localparam S_FETCH = 2'd0;
    localparam S_EXEC  = 2'd1;
    localparam S_MEM   = 2'd2;

    reg  [1:0]  state;
    reg  [31:0] pc;
    reg  [31:0] instr;

    wire [2:0] funct3 = instr[14:12];

    // ---------------------------------------------------------------
    // Giải mã
    // ---------------------------------------------------------------
    wire       reg_write, alu_a_pc, alu_b_imm, mem_write, branch, jal, jalr;
    wire [3:0] alu_op;
    wire [1:0] wb_sel;

    control u_ctrl (
        .opcode   (instr[6:0]),
        .funct3   (funct3),
        .funct7_5 (instr[30]),
        .reg_write(reg_write),
        .alu_a_pc (alu_a_pc),
        .alu_b_imm(alu_b_imm),
        .alu_op   (alu_op),
        .mem_write(mem_write),
        .wb_sel   (wb_sel),
        .branch   (branch),
        .jal      (jal),
        .jalr     (jalr)
    );

    wire is_load  = (instr[6:0] == 7'b0000011);
    wire is_store = mem_write;

    wire [31:0] imm;
    imm_gen u_imm (.instr(instr), .imm(imm));

    // ---------------------------------------------------------------
    // Register file
    // ---------------------------------------------------------------
    wire [31:0] rs1_data, rs2_data;
    reg  [31:0] wb_data;
    wire        rf_we = reg_write &&
                        (((state == S_EXEC) && !is_load) ||
                         ((state == S_MEM)  &&  is_load && mem_ready));

    regfile u_rf (
        .clk(clk),
        .we (rf_we),
        .ra1(instr[18:15]),
        .ra2(instr[23:20]),
        .wa (instr[10:7]),
        .wd (wb_data),
        .rd1(rs1_data),
        .rd2(rs2_data)
    );

    // ---------------------------------------------------------------
    // ALU và so sánh rẽ nhánh
    // ---------------------------------------------------------------
    wire [31:0] alu_a = alu_a_pc  ? pc  : rs1_data;
    wire [31:0] alu_b = alu_b_imm ? imm : rs2_data;
    wire [31:0] alu_y;
    wire        eq, lt, ltu;

    alu u_alu (
        .a  (alu_a),
        .b  (alu_b),
        .op (alu_op),
        .y  (alu_y),
        .eq (eq),
        .lt (lt),
        .ltu(ltu)
    );

    reg take;
    always @* begin
        case (funct3)
            3'b000:  take = eq;     // BEQ
            3'b001:  take = ~eq;    // BNE
            3'b100:  take = lt;     // BLT
            3'b101:  take = ~lt;    // BGE
            3'b110:  take = ltu;    // BLTU
            3'b111:  take = ~ltu;   // BGEU
            default: take = 1'b0;
        endcase
    end

    // ---------------------------------------------------------------
    // Giao tiếp bộ nhớ
    // ---------------------------------------------------------------
    assign mem_valid = (state == S_FETCH) || (state == S_MEM);
    assign mem_we    = (state == S_MEM) && is_store;
    assign mem_addr  = (state == S_FETCH) ? pc : alu_y;
    assign mem_wdata = rs2_data;
    assign mem_size  = (state == S_FETCH) ? 2'd2 : funct3[1:0];

    // Dữ liệu load: lấy đúng byte / half-word trong từ 32 bit vừa đọc
    wire [1:0]  byte_off   = alu_y[1:0];
    wire [31:0] ld_shifted = mem_rdata >> {byte_off, 3'b000};
    reg  [31:0] ld_data;
    always @* begin
        case (funct3)
            3'b000:  ld_data = {{24{ld_shifted[7]}},  ld_shifted[7:0]};   // LB
            3'b001:  ld_data = {{16{ld_shifted[15]}}, ld_shifted[15:0]};  // LH
            3'b100:  ld_data = {24'b0, ld_shifted[7:0]};                  // LBU
            3'b101:  ld_data = {16'b0, ld_shifted[15:0]};                 // LHU
            default: ld_data = mem_rdata;                                 // LW
        endcase
    end

    // ---------------------------------------------------------------
    // Write-back và PC kế tiếp
    // ---------------------------------------------------------------
    wire [31:0] pc_plus4    = pc + 32'd4;
    wire [31:0] pc_plus_imm = pc + imm;

    always @* begin
        case (wb_sel)
            2'd0:    wb_data = alu_y;
            2'd1:    wb_data = ld_data;
            2'd2:    wb_data = pc_plus4;
            default: wb_data = imm;
        endcase
    end

    reg [31:0] pc_next;
    always @* begin
        if (jalr)                         pc_next = alu_y & 32'hFFFF_FFFE;
        else if (jal || (branch && take)) pc_next = pc_plus_imm;
        else                              pc_next = pc_plus4;
    end

    // ---------------------------------------------------------------
    // Máy trạng thái
    // ---------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state <= S_FETCH;
            pc    <= 32'd0;
            instr <= 32'h0000_0013;     // NOP
        end else begin
            case (state)
                S_FETCH: if (mem_ready) begin
                    instr <= mem_rdata;
                    state <= S_EXEC;
                end
                S_EXEC: begin
                    if (is_load || is_store) begin
                        state <= S_MEM;
                    end else begin
                        pc    <= pc_next;
                        state <= S_FETCH;
                    end
                end
                S_MEM: if (mem_ready) begin
                    pc    <= pc_next;
                    state <= S_FETCH;
                end
                default: state <= S_FETCH;
            endcase
        end
    end

    // Các bit lệnh không dùng tới (RV32E chỉ dùng 4 bit địa chỉ thanh ghi)
    wire _unused = &{instr[24], instr[19], instr[11], 1'b0};
endmodule
