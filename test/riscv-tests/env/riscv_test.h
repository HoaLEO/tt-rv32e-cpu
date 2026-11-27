// Moi truong toi gian de chay bo riscv-tests (rv32ui) tren chip tt_um_hoaleo_rv32e.
// Chip khong co CSR, nen bo qua toan bo phan khoi tao che do may cua moi truong goc.
//
// Ket qua duoc ghi ra cong I/O (uo_out) tai 0x02000000:
//   0x01              : PASS
//   0x80 | so_test    : FAIL o test case so "so_test" (TESTNUM nam trong gp)
#ifndef _ENV_TT_RV32E_H
#define _ENV_TT_RV32E_H

#define RVTEST_RV32U
#define RVTEST_RV64U
#define TESTNUM gp

// Khoi dong: chep .data tu flash sang RAM (giong crt0 cua he nhung), roi vao test.
#define RVTEST_CODE_BEGIN                                               \
        .section .text.init;                                            \
        .globl _start;                                                  \
_start: la   a0, _data_lma;                                             \
        la   a1, _data_start;                                           \
        la   a2, _data_end;                                             \
1:      bgeu a1, a2, 2f;                                                \
        lw   a3, 0(a0);                                                 \
        sw   a3, 0(a1);                                                 \
        addi a0, a0, 4;                                                 \
        addi a1, a1, 4;                                                 \
        j    1b;                                                        \
2:      li   a0, 0; li a1, 0; li a2, 0; li a3, 0; li TESTNUM, 0;

#define RVTEST_CODE_END

#define RVTEST_PASS                                                     \
        li   a0, 1;                                                     \
        li   a1, 0x02000000;                                            \
        sb   a0, 0(a1);                                                 \
1:      j    1b;

#define RVTEST_FAIL                                                     \
        ori  a0, TESTNUM, 0x80;                                         \
        li   a1, 0x02000000;                                            \
        sb   a0, 0(a1);                                                 \
1:      j    1b;

#define RVTEST_DATA_BEGIN .align 4;
#define RVTEST_DATA_END   .align 4;

#endif
