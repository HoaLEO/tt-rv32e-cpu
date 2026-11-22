#!/usr/bin/env python3
"""Mini assembler RV32I/RV32E + mô hình tham chiếu (golden model) bằng Python.

- Dịch chương trình assembly bên dưới thành program.hex cho $readmemh.
- Chạy chương trình bằng mô hình Python để chắc chắn kết quả mong đợi đúng
  (uo_out == 0x01, RAM[0] == 55) trước khi đem so với CPU Verilog.

Sửa biến PROGRAM rồi chạy:  python3 make_hex.py
"""
import re
import sys

PROGRAM = """
        lui  x3, 0x1000         # x3 = 0x01000000: dia chi dau RAM (giu nguyen ca chuong trinh)
# ---- Vong lap tinh 1 + 2 + ... + 10 = 55 ----
        addi x1, x0, 0          # sum = 0
        addi x2, x0, 1          # i = 1
        addi x5, x0, 11         # limit = 11
loop:   add  x1, x1, x2         # sum += i
        addi x2, x2, 1          # i++
        blt  x2, x5, loop       # while (i < 11)
        sw   x1, 0(x3)          # mem[0] = 55
        lw   x4, 0(x3)
        addi x5, x0, 55
        bne  x4, x5, fail
# ---- LUI, SW, LB ----
        lui  x6, 0x12345
        addi x6, x6, 0x678      # x6 = 0x12345678
        sw   x6, 4(x3)          # mem[1] = 0x12345678
        lb   x7, 5(x3)          # byte 1 = 0x56
        addi x8, x0, 0x56
        bne  x7, x8, fail
# ---- LHU, SH, LH ----
        lhu  x7, 6(x3)          # nua tren cua mem[1] = 0x1234
        lui  x8, 0x1
        addi x8, x8, 0x234      # 0x1234
        bne  x7, x8, fail
        addi x9, x0, -2
        sh   x9, 8(x3)          # mem[2] nua duoi = 0xFFFE
        lh   x7, 8(x3)          # mo rong dau -> -2
        bne  x7, x9, fail
        lhu  x7, 8(x3)          # khong dau -> 0xFFFE
        lui  x8, 0x10
        addi x8, x8, -2         # 0x0000FFFE
        bne  x7, x8, fail
# ---- SB, LB, LBU ----
        addi x9, x0, -1
        sb   x9, 12(x3)         # mem[3] byte 0 = 0xFF
        lb   x11, 12(x3)        # -1
        bne  x11, x9, fail
        lbu  x12, 12(x3)        # 255
        addi x13, x0, 255
        bne  x12, x13, fail
# ---- Dich voi so tuc thoi ----
        slli x14, x13, 4        # 255 << 4
        srli x14, x14, 4        # >> 4 -> 255
        bne  x14, x13, fail
        addi x7, x0, -16
        srai x8, x7, 2          # -16 >> 2 (dich so hoc) = -4
        addi x11, x0, -4
        bne  x8, x11, fail
        srli x8, x7, 28         # 0xFFFFFFF0 >> 28 = 15
        addi x11, x0, 15
        bne  x8, x11, fail
# ---- Dich voi thanh ghi ----
        addi x15, x0, 3
        sll  x8, x13, x15       # 255 << 3 = 2040
        addi x11, x0, 2040
        bne  x8, x11, fail
        sra  x8, x7, x15        # -16 >> 3 = -2
        addi x11, x0, -2
        bne  x8, x11, fail
        srl  x8, x9, x15        # 0xFFFFFFFF >> 3 = 0x1FFFFFFF
        lui  x11, 0x20000
        addi x11, x11, -1
        bne  x8, x11, fail
# ---- Logic ----
        addi x7, x0, 0x5A5
        addi x8, x0, 0x0FF
        xor  x11, x7, x8        # 0x55A
        addi x12, x0, 0x55A
        bne  x11, x12, fail
        xori x11, x7, 0x0FF
        bne  x11, x12, fail
        or   x11, x7, x8        # 0x5FF
        addi x12, x0, 0x5FF
        bne  x11, x12, fail
        ori  x11, x7, 0x0FF
        bne  x11, x12, fail
        and  x11, x7, x8        # 0x0A5
        addi x12, x0, 0x0A5
        bne  x11, x12, fail
        andi x11, x7, 0x0FF
        bne  x11, x12, fail
# ---- SUB ----
        sub  x11, x8, x7        # 255 - 1445 = -1190
        addi x12, x0, -1190
        bne  x11, x12, fail
# ---- So sanh ----
        addi x12, x0, 1
        slt  x11, x9, x0        # -1 < 0 (co dau) -> 1
        bne  x11, x12, fail
        sltu x11, x9, x0        # 0xFFFFFFFF < 0 (khong dau) -> 0
        bne  x11, x0, fail
        slti x11, x9, 0         # -1 < 0 -> 1
        bne  x11, x12, fail
        sltiu x11, x0, -1       # 0 < 0xFFFFFFFF -> 1
        bne  x11, x12, fail
# ---- Re nhanh: ca truong hop nhay va khong nhay ----
        beq  x9, x0, fail       # khong nhay
        beq  x12, x12, b1       # nhay
        jal  x0, fail
b1:     bge  x0, x9, b2         # 0 >= -1 (co dau) -> nhay
        jal  x0, fail
b2:     bgeu x0, x9, fail       # 0 >= 0xFFFFFFFF (khong dau) -> khong nhay
        bltu x0, x9, b3         # nhay
        jal  x0, fail
b3:     blt  x9, x0, b4         # -1 < 0 -> nhay
        jal  x0, fail
b4:     bge  x9, x0, fail       # khong nhay
# ---- JAL, AUIPC, JALR ----
        jal  x13, here          # x13 = dia chi cua 'here'
here:   auipc x14, 0            # x14 = dia chi cua 'here'
        bne  x13, x14, fail
        jal  x15, func          # goi ham
        addi x12, x0, 7
        bne  x11, x12, fail
        lui  x4, 0x2000         # x4 = 0x02000000: cong I/O
        addi x10, x0, 1         # PASS: ghi 0x01 ra uo_out
        sb   x10, 0(x4)
done:   jal  x0, done
fail:   lui  x4, 0x2000
        addi x10, x0, 255       # FAIL: ghi 0xFF ra uo_out
        sb   x10, 0(x4)
fhalt:  jal  x0, fhalt
func:   addi x11, x0, 7
        jalr x0, 0(x15)         # tro ve
"""

M = 0xFFFFFFFF

R_T = {"add": (0x00, 0), "sub": (0x20, 0), "sll": (0x00, 1), "slt": (0x00, 2),
       "sltu": (0x00, 3), "xor": (0x00, 4), "srl": (0x00, 5), "sra": (0x20, 5),
       "or": (0x00, 6), "and": (0x00, 7)}
I_ALU = {"addi": 0, "slti": 2, "sltiu": 3, "xori": 4, "ori": 6, "andi": 7}
I_SHIFT = {"slli": (0x00, 1), "srli": (0x00, 5), "srai": (0x20, 5)}
LOAD = {"lb": 0, "lh": 1, "lw": 2, "lbu": 4, "lhu": 5}
STORE = {"sb": 0, "sh": 1, "sw": 2}
BRANCH = {"beq": 0, "bne": 1, "blt": 4, "bge": 5, "bltu": 6, "bgeu": 7}


def enc_r(f7, rs2, rs1, f3, rd, op):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_i(imm, rs1, f3, rd, op):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_s(imm, rs2, rs1, f3):
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | 0x23


def enc_b(imm, rs2, rs1, f3):
    imm &= 0x1FFF
    return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) \
        | (f3 << 12) | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | 0x63


def enc_u(imm20, rd, op):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | op


def enc_j(imm, rd):
    imm &= 0x1FFFFF
    return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | (((imm >> 11) & 1) << 20) \
        | (((imm >> 12) & 0xFF) << 12) | (rd << 7) | 0x6F


def operands(text):
    out = []
    for tok in (t.strip() for t in text.split(",")):
        m = re.fullmatch(r"(-?\w+)\((x\d+)\)", tok)
        out += [m.group(1), m.group(2)] if m else [tok]
    return out


def encode(mn, a, pc, labels):
    def reg(t):
        n = int(t[1:])
        if n > 15:
            raise ValueError(f"RV32E chi co x0..x15, khong dung duoc {t}")
        return n
    num = lambda t: int(t, 0)
    target = lambda t: (labels[t] - pc) if t in labels else num(t)
    if mn in R_T:
        f7, f3 = R_T[mn]
        return enc_r(f7, reg(a[2]), reg(a[1]), f3, reg(a[0]), 0x33)
    if mn in I_ALU:
        return enc_i(num(a[2]), reg(a[1]), I_ALU[mn], reg(a[0]), 0x13)
    if mn in I_SHIFT:
        f7, f3 = I_SHIFT[mn]
        return enc_i((f7 << 5) | (num(a[2]) & 31), reg(a[1]), f3, reg(a[0]), 0x13)
    if mn in LOAD:
        return enc_i(num(a[1]), reg(a[2]), LOAD[mn], reg(a[0]), 0x03)
    if mn in STORE:
        return enc_s(num(a[1]), reg(a[0]), reg(a[2]), STORE[mn])
    if mn in BRANCH:
        return enc_b(target(a[2]), reg(a[1]), reg(a[0]), BRANCH[mn])
    if mn == "lui":
        return enc_u(num(a[1]), reg(a[0]), 0x37)
    if mn == "auipc":
        return enc_u(num(a[1]), reg(a[0]), 0x17)
    if mn == "jal":
        return enc_j(target(a[1]), reg(a[0]))
    if mn == "jalr":
        return enc_i(num(a[1]), reg(a[2]), 0, reg(a[0]), 0x67)
    raise ValueError(f"lenh khong ho tro: {mn}")


def assemble(src):
    lines, labels, pc = [], {}, 0
    for raw in src.splitlines():
        text = raw.split("#")[0].strip()
        if not text:
            continue
        while ":" in text:
            name, text = text.split(":", 1)
            labels[name.strip()] = pc
            text = text.strip()
        if text:
            lines.append((pc, text))
            pc += 4
    words = []
    for pc, text in lines:
        parts = text.split(None, 1)
        words.append((pc, text, encode(parts[0], operands(parts[1]) if len(parts) > 1 else [], pc, labels)))
    return words


# ----------------------------------------------------------------------
# Mô hình tham chiếu RV32I (giải mã từ mã máy, độc lập với bộ mã hoá ở trên)
# ----------------------------------------------------------------------
def s32(x):
    x &= M
    return x - (1 << 32) if x >> 31 else x


def alu(f3, x, y, alt):
    x &= M
    y &= M
    if f3 == 0: return x - y if alt else x + y
    if f3 == 1: return x << (y & 31)
    if f3 == 2: return int(s32(x) < s32(y))
    if f3 == 3: return int(x < y)
    if f3 == 4: return x ^ y
    if f3 == 5: return (s32(x) >> (y & 31)) if alt else (x >> (y & 31))
    if f3 == 6: return x | y
    return x & y


def run_model(words):
    code = [w for _, _, w in words]
    R = [0] * 32
    mem = bytearray(65536)
    io = {"out": 0}
    pc = 0
    for _ in range(20000):
        w = code[pc >> 2]
        op, rd, f3 = w & 0x7F, (w >> 7) & 31, (w >> 12) & 7
        r1, r2, f7 = (w >> 15) & 31, (w >> 20) & 31, w >> 25
        a, b = R[r1], R[r2]
        neg = -1 if w >> 31 else 0
        imm_i = s32(w) >> 20
        imm_s = ((s32(w) >> 25) << 5) | ((w >> 7) & 0x1F)
        imm_b = (neg << 12) | (((w >> 7) & 1) << 11) | (((w >> 25) & 0x3F) << 5) | (((w >> 8) & 0xF) << 1)
        imm_u = w & 0xFFFFF000
        imm_j = (neg << 20) | (((w >> 12) & 0xFF) << 12) | (((w >> 20) & 1) << 11) | (((w >> 21) & 0x3FF) << 1)
        npc, res = pc + 4, None

        if op == 0x37:
            res = imm_u
        elif op == 0x17:
            res = pc + imm_u
        elif op == 0x6F:
            res, npc = pc + 4, pc + imm_j
        elif op == 0x67:
            res, npc = pc + 4, (a + imm_i) & ~1
        elif op == 0x63:
            take = {0: a == b, 1: a != b, 4: s32(a) < s32(b), 5: s32(a) >= s32(b),
                    6: a < b, 7: a >= b}[f3]
            if take:
                npc = pc + imm_b
        elif op == 0x03:
            addr = (a + imm_i) & M
            n = {0: 1, 1: 2, 2: 4, 4: 1, 5: 2}[f3]
            if addr & 0x02000000:
                v = 0                                  # ui_in = 0 trong mo phong
            else:
                addr &= 0xFFFF
                v = int.from_bytes(mem[addr:addr + n], "little")
            if f3 in (0, 1):
                v = v - (1 << (8 * n)) if v >> (8 * n - 1) else v
            res = v
        elif op == 0x23:
            addr = (a + imm_s) & M
            n = {0: 1, 1: 2, 2: 4}[f3]
            if addr & 0x02000000:
                io["out"] = b & 0xFF                   # cong ra uo_out
            elif addr & 0x01000000:
                addr &= 0xFFFF
                mem[addr:addr + n] = (b & ((1 << (8 * n)) - 1)).to_bytes(n, "little")
        elif op == 0x13:
            alt = f3 == 5 and (w >> 30) & 1
            res = alu(f3, a, imm_i, alt)
        elif op == 0x33:
            res = alu(f3, a, b, f7 == 0x20)

        if res is not None and rd != 0:
            R[rd] = res & M
        if npc == pc:       # jal x0, chính nó -> dừng
            break
        pc = npc & M
    return R, mem, io


def main():
    words = assemble(PROGRAM)

    with open("program.hex", "w") as f:
        for pc, text, w in words:
            f.write(f"{w:08x} // {pc:04x}: {text}\n")
    print(f"Da ghi program.hex ({len(words)} lenh)")

    R, mem, io = run_model(words)
    mem0 = int.from_bytes(mem[0:4], "little")
    mem1 = int.from_bytes(mem[4:8], "little")
    print(f"Mo hinh tham chieu: uo_out=0x{io['out']:02x}, x1={R[1]}, RAM[0]={mem0}, RAM[4]={mem1:#x}")
    ok = io["out"] == 1 and R[1] == 55 and mem0 == 55 and mem1 == 0x12345678
    print("Mo hinh tham chieu: PASS" if ok else "Mo hinh tham chieu: FAIL")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
