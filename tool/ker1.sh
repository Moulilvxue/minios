#!/bin/bash
path=~/codesrc/lib/kernel
path2=~/bochs
nasm -f elf -o ${path}/build/print.o  ${path}/print.S
nasm -f elf -o ${path}/build/kernel.o ${path}/kernel.S
gcc -m32 -I ${path}/ -I ~/codesrc/lib/ -c -fno-builtin -o ${path}/build/main.o ${path}/main.c \
-fno-stack-protector
gcc -m32 -I ${path}/ -I ~/codesrc/lib/ -c -fno-builtin -o ${path}/build/init.o ${path}/init.c \
-fno-stack-protector
gcc -m32 -I ${path}/ -I ~/codesrc/lib/ -c -fno-builtin -o ${path}/build/interrupt.o ${path}/interrupt.c \
-fno-stack-protector

ld -m elf_i386 -Ttext 0xc0001500 -e main -o ${path}/build/kernel.bin \
${path}/build/main.o ${path}/build/init.o ${path}/build/interrupt.o ${path}/build/print.o \
${path}/build/kernel.o
dd if=${path}/build/kernel.bin of=${path2}/hd60M.img bs=512 count=200 seek=9 \
conv=notrunc
