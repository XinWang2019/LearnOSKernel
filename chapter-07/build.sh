#!/bin/bash
# 执行出错时, 停止执行
set -e

echo "Start creating virtual hard disk..."
echo yes | bximage -q -func=create -hd=60M  -sectsize=512 -imgmode="flat" ../hd60M.img

echo "Start compiling the MBR, loader and kernel..."
# 编译MBR
nasm -I boot/include/ boot/mbr.S -o build/mbr.bin
# 编译内核加载器
nasm -I boot/include/ boot/loader.S -o build/loader.bin
# 编译内核: 32位x86 elf格式
mkdir -p build/lib/kernel/
nasm -f elf -o build/lib/kernel/print.o a/lib/kernel/print.S
nasm -f elf -o build/kernel.o a/kernel/kernel.S
gcc -I a/lib/kernel/ -I a/kernel -m32 -c -fno-builtin -fno-stack-protector -o build/interrupt.o a/kernel/interrupt.c
gcc -I a/lib/kernel/ -I a/kernel -m32 -c -fno-builtin -o build/init.o a/kernel/init.c
gcc -I a/lib/kernel -m32 -c -fno-builtin -o build/lib/kernel/main.o a/kernel/main.c && ld -m elf_i386 build/lib/kernel/main.o build/lib/kernel/print.o build/init.o build/interrupt.o build/kernel.o -Ttext 0xc0001500 -e main -o build/kernel.bin 

echo "Start updating MBR, loader and kernel into the virtual hard disk..."
# 更新硬盘内容
dd if=build/mbr.bin of=../hd60M.img bs=512 count=1 conv=notrunc
dd if=build/loader.bin of=../hd60M.img bs=512 count=4 seek=2 conv=notrunc
dd if=build/kernel.bin of=../hd60M.img bs=512 count=200 seek=9 conv=notrunc

cd ../ && bochs -f ./bochs.txt