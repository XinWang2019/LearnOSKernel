#!/bin/bash
echo "Start creating virtual hard disk..."
echo yes | bximage -q -func=create -hd=60M  -sectsize=512 -imgmode="flat" ../hd60M.img

echo "Start compiling the MBR, loader and kernel..."
# 编译MBR
nasm -I include/ mbr.S -o mbr.bin
# 编译内核加载器
nasm -I include/ loader.S -o loader.bin
# 编译内核: 32位x86 elf格式
gcc -m32 -c -o kernel/main.o kernel/main.c && ld -m elf_i386 kernel/main.o -Ttext 0xc0001500 -e main -o kernel/kernel.bin 

echo "Start updating MBR, loader and kernel into the virtual hard disk..."
# 更新硬盘内容
dd if=mbr.bin of=../hd60M.img bs=512 count=1 conv=notrunc
dd if=loader.bin of=../hd60M.img bs=512 count=4 seek=2 conv=notrunc
dd if=kernel/kernel.bin of=../hd60M.img bs=512 count=200 seek=9 conv=notrunc

cd ../ && bochs -f ./bochs.txt