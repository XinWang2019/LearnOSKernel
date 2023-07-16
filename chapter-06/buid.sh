#!/bin/bash
set -e
echo "Start creating virtual hard disk..."
echo yes | bximage -q -func=create -hd=60M  -sectsize=512 -imgmode="flat" ../hd60M.img

echo "Start compiling the MBR, loader and kernel..."
# 编译MBR
nasm -I boot/include/ boot/mbr.S -o mbr.bin
# 编译内核加载器
nasm -I boot/include/ boot/loader.S -o loader.bin
# 编译内核: 32位x86 elf格式
nasm -f elf -o a/lib/kernel/print.o a/lib/kernel/print.S
gcc -I a/lib/kernel -m32 -c -o a/lib/kernel/main.o a/lib/kernel/main.c && ld -m elf_i386 a/lib/kernel/main.o a/lib/kernel/print.o -Ttext 0xc0001500 -e main -o kernel.bin 

echo "Start updating MBR, loader and kernel into the virtual hard disk..."
# 更新硬盘内容
dd if=mbr.bin of=../hd60M.img bs=512 count=1 conv=notrunc
dd if=loader.bin of=../hd60M.img bs=512 count=4 seek=2 conv=notrunc
dd if=kernel.bin of=../hd60M.img bs=512 count=200 seek=9 conv=notrunc

cd ../ && bochs -f ./bochs.txt