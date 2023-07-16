section .data
str_c_lib: db "c library says: hello world!", 0xa ; 0xa为LF ASCII码
str_c_lib_len equ $-str_c_lib

str_syscall: db "syscall says: hello world!", 0xa
str_syscall_len equ $-str_syscall

section .text
global _start
_start:
; 方式1: 模拟C语言中系统调用库函数write ---------------------------------
    push str_c_lib_len                                         ; 按照C调用约定压入参数
    push str_c_lib
    push 1

    call simu_write
    add esp, 12                                                ; 回收栈空间

; 方式2: 跨过库函数, 直接进行系统调用 ------------------------------------
    mov eax, 4                                                 ; 第4号子功能是write系统调用 (不是C库函数write)
    mov ebx, 1
    mov ecx, str_syscall
    mov edx, str_c_lib_len
    int 0x80                                                   ; 发起中断, 通知Linux完成请求的功能

; 退出程序 ----------------------------------------------------
    mov eax, 1                                                 ; 第1号子功能是exit
    int 0x80                                                   ; 发起中断, 通知Linux完成请求的功能

; 下面自定义的simu_write用来模拟C库中系统调用函数write ----------------------
simu_write:
    push ebp
    mov ebp, esp
    mov eax, 4
    mov ebx, [ebp + 8]                                     ; 第1个参数
    mov ecx, [ebp + 12]                                    ; 第2个参数
    mov edx, [ebp + 16]                                    ; 第3个参数
    int 0x80
    pop ebp
    ret