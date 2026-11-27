/* Ban do bo nho cua chip: flash (chuong trinh) tai 0, RAM tai 0x01000000. */
OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
  FLASH (rx) : ORIGIN = 0x00000000, LENGTH = 16K
  RAM   (rw) : ORIGIN = 0x01000000, LENGTH = 4K
}
SECTIONS {
  .text : { *(.text.init) *(.text*) *(.rodata*) . = ALIGN(4); } > FLASH
  .data : {
    _data_start = .;
    *(.data*) *(.sdata*) *(.bss*) *(.sbss*)
    . = ALIGN(4);
    _data_end = .;
  } > RAM AT > FLASH
  _data_lma = LOADADDR(.data);
  /DISCARD/ : { *(.riscv.attributes) *(.comment) *(.note*) }
}
