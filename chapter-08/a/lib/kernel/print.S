TI_GDT equ 0
RPL0 equ 0
SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0

section .data
put_int_buffer dq 0          ; 定义8字节缓冲区用于数字到字符的转换

[bits 32]
section .text
; put_int -------------------------------------------------
; 功能描述: 将小端字节序的数字变成对应的ASCII后, 倒置

; 输入: 栈中参数为待打印的数字

; 输出: 在屏幕上打印十六进制数字, 并不会打印前缀0x
; 如打印十进制15, 只会打印f, 不会是0xf
global put_int
put_int:
    pushad
    mov ebp, esp
    mov eax, [ebp+4*9]
    mov edx, eax
    mov edi, 7               ; 指定在put_int_buffer中初始的偏移量
    mov ecx, 8               ; 32位数字中, 十六进制数字的位数是8个
    mov ebx, put_int_buffer
; 将32位数字按照16进制的形式从低到高逐个处理, 共处理8个十六进制数字
.16based_4bits:
    and edx, 0x0000_000F
    cmp edx, 9
    jg .is_A2F
    add edx, '0'
    jmp .store
.is_A2F:
    sub edx, 10
    add edx, 'A'

.store:
    mov [ebx+edi], dl
    dec edi
    shr eax, 4
    mov edx, eax
    loop .16based_4bits

; 现在put_int_buffer中已全部是字符, 打印之前把高位的连续'0'去掉
; 例如 000123变成123
ready_to_print:
    inc edi                  ; 此时edi=-1, 加1使其为0
.skip_prefix_0:
    cmp edi, 8               ; 若已经比较第9个字符
    je .full0
; 找出连续的0字符, edi作为非0的最高位字符的偏移
.go_on_skip:
    mov cl, [put_int_buffer+edi]
    inc edi
    cmp cl, '0'
    je .skip_prefix_0
    dec edi                  ; edi在上面的inc操作中指向了下一个字符, 若当前字符不为'0', 要使edi减1恢复指向当前字符
    jmp .put_each_num

.full0:
    mov cl, '0'              ; 输入的数字全0时, 则只打印0
.put_each_num:
    push ecx
    call put_char
    add esp, 4
    inc edi
    mov cl, [put_int_buffer+edi] ; 获取下一个字符到cl寄存器
    cmp edi, 8
    jl .put_each_num
    popad
    ret
; put_str ------------------------------------------------
; 功能描述: 通过调用put_char来打印以0结尾的字符串
;----------------------------------------------------------
global put_str
put_str:
; 本函数只用了ebx和ecx, 因此只备份这两个寄存器
    push ebx
    push ecx
    xor ecx, ecx
    mov ebx, [esp + 12]      ; 从栈中得到待打印的字符串地址
.goon:
    mov cl, [ebx]
    cmp cl, 0                ; 如果处理到了字符串尾, 跳到结束处返回
    jz .str_over
    push ecx
    call put_char
    add esp, 4               ; 回收参数所占的栈空间
    inc ebx                  ; 使ebx指向下一个字符
    jmp .goon
.str_over:
    pop ecx
    pop ebx
    ret
; put_char ------------------------------------------------
; 功能描述: 把栈中的1个字符写入光标所在处
;----------------------------------------------------------
global put_char
put_char:
    pushad                   ; 备份32位寄存器环境
; 需要保证gs中为正确的视频选择子
; 为保险起见, 每次打印时都为gs赋值
    mov ax, SELECTOR_VIDEO   ; 不能直接把立即数送入段寄存器
    mov gs, ax

; 获取当前光标位置 ------------------------------------------------
; 先获取高8位
    mov dx, 0x03d4           ; 索引寄存器
    mov al, 0x0e             ; 用于提供光标位置的高8位
    out dx, al
    mov dx, 0x03d5           ; 通过读写数据端口0x03d5来获得或者设置光标
    in al, dx                ; 得到光标位置的高8位
    mov ah, al

; 再获取低8位
    mov dx, 0x03d4
    mov al, 0x0f
    out dx, al
    mov dx, 0x03d5
    in al, dx

; 将光标存入bx
    mov bx, ax
; 下面这行是在栈中获取待打印的字符
    mov ecx, [esp + 36]      ; pushad压入4x8=32字节, 加上主调函数4字节的返回地址, 故esp+36字节
    cmp cl, 0xd              ; CR是0x0d, LF是0x0a
    jz .is_carriage_return
    cmp cl, 0xa
    jz .is_line_feed

    cmp cl, 0x8              ; BS(backspace)的ascii码是8
    jz .is_backspace
    jmp .put_other

.is_backspace:
; 当为backspace时, 本质上只要将光标向前移动一个显存的位置即可, 后面再输入
; 的字符自然会覆盖此处的字符. 但有可能在键入backspace后并不再键入新的字符,
; 这时光标已经向前移动到待删除的字符位置, 但字符还在原处, 显得怪异, 所以此处
; 添加了空格或空字符0
    dec bx
    shl bx, 1                ; 左移1位等于乘2, 表示光标对应显存中的偏移字节
    mov byte [gs:bx], 0x20   ; 将待删除的字节补为0或者空格皆可
    inc bx
    mov byte [gs:bx], 0x07
    shr bx, 1
    jmp .set_cursor

.put_other:
    shl bx, 1
    mov [gs:bx], cl          ; ascii字符本身
    inc bx
    mov byte [gs:bx], 0x07   ; 字符属性
    shr bx, 1                ; 恢复老的光标值
    inc bx
    cmp bx, 2000
; 若光标值小于2000, 表示未写到显存的最后, 则去设置新的光标值
; 若超出屏幕字符数大小, 则换行处理
    jl .set_cursor

.is_line_feed:               ; 是换行符LF(\n)
.is_carriage_return:         ; 是回车符CR(\r)
; 如果是CR, 只要把光标移动到行首就可以了
; 效仿Linux, 将\r和\n都处理为下一行行首
    xor dx, dx               ; dx是被除数的高16位, 清0
    mov ax, bx               ; ax是被除数的低16位
    mov si, 80
    div si
    sub bx, dx               ; 光标值减去除80的余数就是取整, 以上四行处理\r的代码

.is_carriage_return_end:     ; 回车符CR处理结束
    add bx, 80
    cmp bx, 2000
.is_line_feed_end:           ; 若是LF(\n), 将光标+80便可
    jl .set_cursor

; 屏幕行范围是0～24, 滚屏的原理是将屏幕的第1～24行搬运到0～23行
; 再将第24行用空格填充
.roll_screen:                ; 若超出屏幕大小, 开始滚屏
    cld
    mov ecx, 960             ; 2000-80=1920字符, 每个字符2字节, 一次搬运4字节, 共3840/4=960次
    mov esi, 0xc00b80a0      ; 第1行行首
    mov edi, 0xc00b8000      ; 第0行行首
    rep movsd

; 将最后一行填充为空白
    mov ebx, 3840
    mov ecx, 80              ; 一行80字符, 每次清空1字符, 一行需要80次

.cls:
    mov word [gs:ebx], 0x0720; 黑底白字空格键
    add ebx, 2
    loop .cls
    mov bx, 1920             ; 将光标值重置为1920, 最后一行的首字符

.set_cursor:
; 将光标设为bx值
; 1 先设置高8位 ------------------------------------------------
    mov dx, 0x03d4           ; 索引寄存器
    mov al, 0x0e             ; 用于提供光标位置的高8位
    out dx, al
    mov dx, 0x03d5           ; 通过读写数据端口0x3d5来获得或者设置光标位置
    mov al, bh
    out dx, al

; 再设置低8位 --------------------------------------------------
    mov dx, 0x03d4
    mov al, 0x0f
    out dx, al
    mov dx, 0x03d5
    mov al, bl
    out dx, al
.put_char_done:
    popad
    ret