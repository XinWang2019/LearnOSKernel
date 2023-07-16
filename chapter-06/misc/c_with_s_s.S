section .data
str: db "asm_print says hello world!", 0xa, 0              ; 0xa是换行符, 0是\0 ASCII码
str_len equ $-str

section .text
extern c_print
global _start

_start:
; 调用C代码中的函数c_print ----------------------------------------
    push str
    call c_print
    add esp, 4

; 退出程序 ----------------------------------------------------
mov eax, 1
int 0x80

global asm_print
asm_print:
    push ebp
    mov ebp, esp
    mov eax, 4
    mov ebx, 1                                             ; 此项固定为文件描述符1, 即标准输出(stdout)指向屏幕
    mov ecx, [ebp+8]
    mov edx, [ebp+12]
    int 0x80
    pop ebp
    ret