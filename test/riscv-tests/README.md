# Official RISC-V tests (rv32ui)

`hex/*.hex` are the `rv32ui` tests from
[riscv-software-src/riscv-tests](https://github.com/riscv-software-src/riscv-tests)
(BSD 3-Clause license), built for RV32E with the minimal environment in `env/`.

- `env/riscv_test.h`: replaces the upstream environment. The chip has no CSRs, so the
  start-up code only copies `.data` from flash to RAM. PASS writes `0x01` to `uo_out`,
  FAIL writes `0x80 | test case number`.
- `env/link.ld`: code in flash at `0x0000_0000`, data in RAM at `0x0100_0000`.
- `build.sh <path to riscv-tests>`: rebuilds the hex files (needs clang, ld.lld, llvm-objcopy).

Skipped: `fence_i` (needs writable instruction memory) and `ma_data` (misaligned access),
which this CPU does not support.

`test/test.py` loads each hex file into the flash model and runs it (RTL simulation only).
