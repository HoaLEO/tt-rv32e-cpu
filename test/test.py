# SPDX-FileCopyrightText: © 2026 HoaLEO
# SPDX-License-Identifier: Apache-2.0
#
# Hai nhóm test cho CPU RV32E:
#   1. test_program: chương trình tự viết (program.hex), kèm bản ghi lệnh khi lỗi.
#   2. test_riscv:   bộ test chính thức rv32ui của RISC-V (riscv-tests/hex/*.hex),
#                    mỗi file là một test cho một lệnh. Chỉ chạy ở mô phỏng RTL.
# Mỗi chương trình ghi 0x01 ra uo_out khi PASS, hoặc một giá trị có bit 7 bằng 1 khi FAIL.

import os
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

PASS_CODE = 0x01
FAIL_CODE = 0xFF
MAX_CYCLES = 200_000
CHECK_EVERY = 1_000


async def trace_cpu(dut, log, depth=24):
    """Ghi lại các lệnh CPU vừa thực thi (chỉ dùng ở mô phỏng RTL)."""
    cpu = dut.user_project.u_cpu
    while True:
        await RisingEdge(dut.clk)
        if cpu.state.value.is_resolvable and int(cpu.state.value) == 1:   # S_EXEC
            pc = int(cpu.pc.value)
            ins = int(cpu.instr.value)
            log.append(f"pc={pc:08x} instr={ins:08x} rs1={cpu.rs1_data.value} rs2={cpu.rs2_data.value} alu_y={cpu.alu_y.value}")
            del log[:-depth]


def ram_word(dut, addr):
    """Đọc một từ 32 bit (little-endian) từ mô hình RAM."""
    mem = dut.ram.mem
    return sum(int(mem[addr + i].value) << (8 * i) for i in range(4))


@cocotb.test()
async def test_program(dut):
    dut._log.info("Start")

    # Clock 10 us (100 kHz) như mẫu Tiny Tapeout
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    trace = []
    try:
        dut.user_project.u_cpu.state  # chỉ có ở mô phỏng RTL, không có ở gate-level
        cocotb.start_soon(trace_cpu(dut, trace))
    except AttributeError:
        pass

    dut._log.info("Chay chuong trinh thu")
    result = 0
    cycles = 0
    while cycles < MAX_CYCLES:
        await ClockCycles(dut.clk, CHECK_EVERY)
        cycles += CHECK_EVERY
        out = dut.uo_out.value
        if out.is_resolvable and int(out) in (PASS_CODE, FAIL_CODE):
            result = int(out)
            break

    dut._log.info(f"uo_out = 0x{result:02x} sau khoang {cycles} chu ky")
    if result != PASS_CODE:
        dut._log.info("Cac lenh cuoi cung da thuc thi:\n" + "\n".join(trace))
    assert result == PASS_CODE, f"Chuong trinh bao FAIL hoac het gio (uo_out = 0x{result:02x})"

    # Kiểm tra thêm nội dung RAM do chương trình ghi
    assert ram_word(dut, 0) == 55, f"RAM[0] = {ram_word(dut, 0)}, mong doi 55"
    assert ram_word(dut, 4) == 0x12345678, f"RAM[4] = 0x{ram_word(dut, 4):08x}, mong doi 0x12345678"


# ---------------------------------------------------------------------------
# Bộ test chính thức rv32ui (riscv-software-src/riscv-tests), biên dịch cho RV32E
# bằng riscv-tests/build.sh. Nạp từng chương trình vào mô hình flash rồi chạy.
# ---------------------------------------------------------------------------
RISCV_DIR = Path(__file__).resolve().parent / "riscv-tests" / "hex"
RISCV_TESTS = sorted(p.stem for p in RISCV_DIR.glob("*.hex"))
GATE_LEVEL = os.environ.get("GATES") == "yes"
RISCV_MAX_CYCLES = 400_000
RAM_BYTES = 4096
_flash_used = [None]    # số byte flash mà test trước đã ghi (None: chưa biết, xóa hết)


def load_flash(dut, name):
    """Ghi chương trình vào mô hình flash (little-endian), phần còn lại là NOP."""
    words = [int(line, 16) for line in (RISCV_DIR / f"{name}.hex").read_text().split()]
    mem = dut.flash.mem
    size = len(mem)
    assert 4 * len(words) <= size, f"{name}: chuong trinh lon hon flash mo phong"
    end = size if _flash_used[0] is None else max(_flash_used[0], 4 * len(words))
    for i in range(0, end, 4):
        w = words[i // 4] if i // 4 < len(words) else 0x00000013
        for k in range(4):
            mem[i + k].value = (w >> (8 * k)) & 0xFF
    _flash_used[0] = 4 * len(words)


@cocotb.test(skip=GATE_LEVEL or not RISCV_TESTS)
@cocotb.parametrize(name=RISCV_TESTS or ["none"])
async def test_riscv(dut, name):
    dut.dump_on.value = 0       # không ghi dạng sóng cho nhóm test này (file sẽ rất lớn)
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    load_flash(dut, name)
    for i in range(RAM_BYTES):
        dut.ram.mem[i].value = 0
    await ClockCycles(dut.clk, 8)
    dut.rst_n.value = 1

    result = 0
    cycles = 0
    while cycles < RISCV_MAX_CYCLES:
        await ClockCycles(dut.clk, CHECK_EVERY)
        cycles += CHECK_EVERY
        out = dut.uo_out.value
        if out.is_resolvable and int(out) != 0:
            result = int(out)
            break

    dut._log.info(f"rv32ui-{name}: uo_out = 0x{result:02x} sau khoang {cycles} chu ky")
    assert result != 0, f"rv32ui-{name}: het gio"
    assert result == PASS_CODE, f"rv32ui-{name}: FAIL o test case so {result & 0x7F}"
