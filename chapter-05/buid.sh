nasm -I include/ loader.S -o loader.bin
nasm -I include/ mbr.S -o mbr.bin
dd if=mbr.bin of=../hd60M.img bs=512 count=1 conv=notrunc
dd if=loader.bin of=../hd60M.img bs=512 count=4 seek=2 conv=notrunc