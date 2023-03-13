#!/bin/bash
path=~/codesrc/lib/kernel
path2=~/bochs
nasm -f elf -o ${path}/print.o  ${path}/print.S
gcc -m32 -I ${path}/ -c -o ${path}/main.o ${path}/main.c
ld -m elf_i386 -Ttext 0xc0001500 -e main -o ${path}/kernel.bin \
${path}/main.o ${path}/print.o
dd if=${path}/kernel.bin of=${path2}/hd60M.img bs=512 count=200 seek=9 \
conv=notrunc
