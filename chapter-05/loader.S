%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR

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

; total_mem_bytes用于保存内存容量, 以字节为单位, 当前偏移loader.bin文件头0x200字节
; loader.bin的加载地址是0x900
; 因此total_mem_bytes内存中的地址是0xb00
; 将来在内核中会引用此地址
    total_mem_bytes dd 0
    
; 以下是GDT的指针, 前两字节是gdt的大小, 后四字节是gdt的起始地址
    gdt_ptr dw GDT_LIMIT
            dd GDT_BASE

; 人工对齐: total_mem_bytes4+gdt_ptr6+ards_buf244+ards_nr2， 共256字节
    ards_buf times 244 db 0
    ards_nr dw 0                                 ; 用于记录ARDS (Address Range Descriptor Structure) 结构体数量

loader_start:
; int 15h eax=0000E820, edx = 534D4150h ('SMAP') 获取内存布局 -------------------------------------------
    xor ebx, ebx             ; 将ebx清零
    mov edx, 0x534d4150      ; edx只赋值一次, 循环体中不会改变
    mov di, ards_buf         ; ards结构缓冲区
.e820_mem_get_loop:
    mov eax, 0x0000_e820     ; 执行int 0x15后, eax值变为0x534d4150, 因此每次执行int前都需要更新为子功能号
    mov ecx, 20
    int 0x15
    jc .e820_failed_so_try_0e81 ; cf位为1则有错误发生, 尝试0xe801子功能
    add di, cx               ; 使di增加20字节指向缓冲区中新的ARDS结构位置
    inc word [ards_nr]       ; 记录ARDS数量
    cmp ebx, 0               ; 若ebx为0且cf位不为1, 则说明ards全部返回, 当前已是最后一个
    jnz .e820_mem_get_loop

; 在所有ards结构中找出(base_addr_low + length_low)的最大值, 即内存的容量
    mov cx, [ards_nr]       ; 循环次数是ARDS的数量
    mov ebx, ards_buf
    xor edx, edx            ; edx用于存放最大的内存容量
.find_max_mem_area:
; 无需判断type是否为1, 最大的内存块一定是可被使用的
    mov eax, [ebx]          ; base_add_low
    add eax, [ebx+8]        ; length_low
    add ebx, 20             ; 指向缓冲区中下一个ARDS结构
    cmp edx, eax
    jge .next_ards
    mov edx, eax
.next_ards:
    loop .find_max_mem_area
    jmp .mem_get_ok

; int 15h ax=E801h获取内存大小, 最大支持4G ------------------------------------------------------------------
; 返回后, ax cx 值一样, 以KB为单位, bx dx值一样, 以64KB为单位
; 在ax和cx寄存器中为低16MB, 在bx和dx寄存器中为16MB到4GB
.e820_failed_so_try_0e81:
    mov ax, 0xe801
    int 0x15
    jc .e801_failed_so_try88 ; 若当前0xe801方法失败, 则尝试0x88方法

; 1 先算出低15MB的内存
; ax和cx中是以KB为单位的内存数量, 将其转换为以byte为单位
    mov cx, 0x400
    mul cx
    shl edx, 16              ; 积的高16为在dx， 低16位在ax
    and eax, 0x0000_ffff
    or edx, eax
    add edx, 0x10_0000       ; ax只是低15MB, 因此要加上1MB
    mov esi, edx             ; 先把低15MB的内存容量存入esi寄存器备份

; 2 再将16MB以上的内存转换为byte为单位
; 寄存器bx和dx中是以64KB为单位的内存容量
    xor eax, eax
    mov ax, bx
    mov ecx, 0x1_0000        ; 0x1_0000为64KB
    mul ecx                  ; 32位乘法, 默认的被乘数是eax, 积为64位， 高32位存入edx, 低32位存入eax
    add esi, eax             ; 由于此方法只能测出4GB以内的内存, 故32位eax足够了
    mov edx, esi             ; edx为总内存大小
    jmp .mem_get_ok

; int 15h ah=0x88获取内存大小, 只能获取64MB以内 ---------------------------------------------------------------
.e801_failed_so_try88:
; int 15h后, ax存入的是以KB为单位的内存容量
    mov ah, 0x88
    int 0x15
    jc .error_hlt
    and eax, 0x0000_ffff

; 16位乘法, 被乘数是ax, 积为32位, 积的高16位在dx中， 积的低16位在ax中
    mov cx, 0x400
    mul cx
    shl edx, 16
    or edx, eax
    add edx, 0x10_0000

.mem_get_ok:
    mov [total_mem_bytes], edx ; 将内存转换为byte后存入total_mem_bytes处
    jmp .final

.error_hlt:
    mov byte [gs:160], 'f'
    mov byte [gs:162], 'a'
    mov byte [gs:164], 'i'
    mov byte [gs:166], 'l'
    mov byte [gs:168], 'e'
    mov byte [gs:170], 'd'
    jmp $

.final:
    mov byte [gs:160], 'd'
    mov byte [gs:162], 'o'
    mov byte [gs:164], 'n'
    mov byte [gs:166], 'e'
    jmp $

    