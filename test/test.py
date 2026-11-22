# SPDX-FileCopyrightText: © 2026 HoaLEO
# SPDX-License-Identifier: Apache-2.0
#
# Chạy chương trình thử (program.hex) trên CPU RV32E.
# Chương trình tự kiểm tra từng lệnh, rồi ghi 0x01 (PASS) hoặc 0xFF (FAIL) ra uo_out.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

PASS_CODE = 0x01
FAIL_CODE = 0xFF
MAX_CYCLES = 200_000
CHECK_EVERY = 1_000


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
    assert result == PASS_CODE, f"Chuong trinh bao FAIL hoac het gio (uo_out = 0x{result:02x})"

    # Kiểm tra thêm nội dung RAM do chương trình ghi
    assert ram_word(dut, 0) == 55, f"RAM[0] = {ram_word(dut, 0)}, mong doi 55"
    assert ram_word(dut, 4) == 0x12345678, f"RAM[4] = 0x{ram_word(dut, 4):08x}, mong doi 0x12345678"
