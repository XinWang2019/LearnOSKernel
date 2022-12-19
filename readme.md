# 操作系统真相还原
## 文件说明
* `bochs.txt`: bochs运行需要的硬件设置说明文件.
* `hd60M.img`: bochs运行需要的 60 MB 虚拟硬盘文件.
* `bochs.out`: bochs运行需要的日志输出文件.

## 第二章

编译器NASM的关键字`$`表示当前行的地址.

`$$`表示本section的起始地址.

`vstart=xxxx`用于将当前section的虚拟起始地址制定为`xxxx`. 此时`$`的值是以`xxxx`为起始地址的顺延. 使用了`v_start`关键字后, 可以使用`section.节名.start`来获取本section在文件中的真实偏移.

NASM基本用法: `nasm -f <format> <filename> [-o <output>]`.