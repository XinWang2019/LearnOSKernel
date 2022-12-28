%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR

    jmp loader_start

; 构建GDT及其内部的描述符
    GDT_BASE: dd 0x0000_0000
              dd 0x0000_0000

    CODE_DESC: dd 0x0000_ffff
               dd DESC_CODE_HIGH4

    DATA_STACK_DESC: dd 0x0000_ffff
                     dd DESC_DATA_HIGH4

    VIDEO_DESC: dd 0x8000_0007  ; limit=(0xbffff-0xb8000)/4K = 0x7, 对应文本模式显示适配器的显存范围
                dd DESC_VIDEO_HIGH4 ; 此时dpl=0

    GDT_SIZE equ $ - GDT_BASE
    GDT_LIMIT equ GDT_SIZE - 1
    times 60 dq 0 ; 此处预留60个描述符的空位

; 定义段选择子
    SELECTOR_CODE  equ (0x0001<<3) + TI_GDT + RPL0 ;    代码段段选择子
    SELECTOR_DATA  equ (0x0002<<3) + TI_GDT + RPL0 ;    数据段段选择子
    SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0 ;    显存段段选择子

; 以下是GDT的指针, 前两字节是gdt的大小, 后四字节是gdt的起始地址
    gdt_ptr dw GDT_LIMIT
            dd GDT_BASE

    loadermsg db '2 loader in real.'

loader_start:
;----------------------------------------------------------
; INT 0x10 功能号: 013 功能描述: 打印字符串
;----------------------------------------------------------
; 输入:
; AH 子功能号=13H
; BH = 页码
; BL = 属性 (若AL=00H或者01H)
; CX = 字符串长度
; (DH, DL) = 坐标(行, 列)
; ES:BP = 字符串地址
; AL = 显示输出方式
;   0-字符串中只含显示字符, 显示属性在BL中, 显示后, 光标位置不变
;   1-字符串中只含显示字符, 显示属性在BL中, 显示后, 光标位置改变
;   2-字符串中包含显示字符和显示属性, 显示后, 光标位置不变
;   3-字符串中包含显示字符和显示属性, 显示后, 光标位置改变
; 无返回值
    mov ax, 0
    mov es, ax
    mov bp, loadermsg
    mov cx, 17
    mov ax, 0x1301
    mov bx, 0x001f
    mov dx, 0x1800
    int 0x10

;----------------------------------------------------------
; 准备进入保护模式
;----------------------------------------------------------

;- 打开A20 --------------------------------------------------
    in al, 0x92
    or al, 0000_0010B
    out 0x92, al

;- 加载GDT --------------------------------------------------
    lgdt [gdt_ptr]

;- 开启保护模式 -------------------------------------------------
    mov eax, cr0
    or eax, 0x0000_0001
    mov cr0, eax

    jmp dword SELECTOR_CODE:p_mode_start

[bits 32]
p_mode_start:
    mov ax, SELECTOR_DATA
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, LOADER_STACK_TOP
    mov ax, SELECTOR_VIDEO
    mov gs, ax

    mov byte [gs:160], 'P'

    jmp $