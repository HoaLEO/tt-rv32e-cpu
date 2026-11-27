#!/bin/sh
# Bien dich bo test chinh thuc rv32ui (riscv-software-src/riscv-tests) cho RV32E
# va xuat ra hex/<ten>.hex (moi dong mot tu 32 bit, dung cho mo hinh flash).
#
# Can: clang (co target riscv32), ld.lld, llvm-objcopy, python3.
# Dung: ./build.sh /duong/dan/toi/riscv-tests
set -e
SRC=${1:?"Dung: ./build.sh <thu muc riscv-tests>"}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$HERE/hex
TMP=$(mktemp -d)
# fence_i can bo nho lenh ghi duoc, ma_data can truy cap lech dia chi: chip khong ho tro.
SKIP="fence_i ma_data"
mkdir -p "$OUT"; rm -f "$OUT"/*.hex
for f in "$SRC"/isa/rv32ui/*.S; do
  n=$(basename "$f" .S)
  case " $SKIP " in *" $n "*) echo "skip $n"; continue;; esac
  clang --target=riscv32 -march=rv32e -mabi=ilp32e -mno-relax -nostdlib -static \
        -I"$HERE/env" -I"$SRC/isa/macros/scalar" -c "$f" -o "$TMP/$n.o"
  ld.lld -T "$HERE/env/link.ld" "$TMP/$n.o" -o "$TMP/$n.elf"
  llvm-objcopy -O binary "$TMP/$n.elf" "$TMP/$n.bin"
  python3 - "$TMP/$n.bin" "$OUT/$n.hex" <<'PY'
import sys
b = open(sys.argv[1], 'rb').read()
b += b'\0' * (-len(b) % 4)
open(sys.argv[2], 'w').write(''.join('%08x\n' % int.from_bytes(b[i:i+4], 'little') for i in range(0, len(b), 4)))
PY
done
rm -rf "$TMP"
ls "$OUT" | wc -l
