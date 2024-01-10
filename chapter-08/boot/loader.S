%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR
; 定义段选择子
SELECTOR_CODE  equ (0x0001<<3) + TI_GDT + RPL0 ;    代码段段选择子
SELECTOR_DATA  equ (0x0002<<3) + TI_GDT + RPL0 ;    数据段段选择子
SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0 ;    显存段段选择子

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
;--------------------------------------------------------------------------------------------------
; 获取内存分布
;--------------------------------------------------------------------------------------------------
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
    jmp .mem_get_ok

.error_hlt:
    mov byte [gs:160], 'f'
    mov byte [gs:162], 'a'
    mov byte [gs:164], 'i'
    mov byte [gs:166], 'l'
    mov byte [gs:168], 'e'
    mov byte [gs:170], 'd'
    jmp $

.mem_get_ok:
    mov [total_mem_bytes], edx ; 将内存转换为byte后存入total_mem_bytes处

;--------------------------------------------------------------------------------------------------
; 进入保护模式
;--------------------------------------------------------------------------------------------------
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

;--------------------------------------------------------------------------------------------------
; 加载kernel
;--------------------------------------------------------------------------------------------------
    mov eax, KERNEL_START_SECTOR                           ; kernel.bin所在的扇区
    mov ebx, KERNEL_BIN_BASE_ADDR
; 从磁盘读出后, 写入到ebx指定的地址
    mov ecx, 200                                           ; 读入的扇区数

    call rd_disk_m_32

;--------------------------------------------------------------------------------------------------
; 开启内存分页
;--------------------------------------------------------------------------------------------------
; 创建页目录及页表并初始化也内存位图
    call setup_page

; 将描述符表地址及偏移量写入内存gdt_ptr, 一会儿用新地址重新加载
    sgdt [gdt_ptr]

; 将gdt描述符中视频段描述符中的段基址+0xc000_0000
    mov ebx, [gdt_ptr + 2]
    or dword [ebx + 0x18 + 4], 0xc000_0000 ; 地址0xd34

; 将gdt的基址加上0xc000_0000使其成为内核所在的高地址
    add dword [gdt_ptr + 2], 0xc000_0000

; 将栈指针同样映射到内核地址
    add esp, 0xc000_0000

; 把页目录地址赋予cr3
    mov eax, PAGE_DIR_TABLE_POS
    mov cr3, eax

; 打开cr0的pg位, 第31位
    mov eax, cr0
    or eax, 0x8000_0000
    mov cr0, eax

; 在开启分页后, 用gdt新的地址重新加载
    lgdt [gdt_ptr]

    mov byte [gs:160], 'V'

; 此时不刷新流水线也没问题
; 由于一直处在32位下, 原则上不需要强制刷新
; 但以防万一, 还是加上了, 免得以后出问题
    jmp SELECTOR_CODE:enter_kernel                         ; 强制刷新流水线, 更新gpt

enter_kernel:
    call kernel_init                                       ; addr=0xd74
    mov esp, 0xc009f000
    jmp KERNEL_ENTRY_POINT                                 ; 用地址0x1500访问测试, 结果ok

;  将kernel.bin中的segment拷贝到编译的地址 ------------------------------------------------------------
kernel_init:
    xor eax, eax
    xor ebx, ebx                                            ; ebx记录程序头表地址
    xor ecx, ecx                                            ; cx记录程序头表中的program header数量
    xor edx, edx                                            ; 大学记录program header尺寸, 即e_phentsize

    mov dx, [KERNEL_BIN_BASE_ADDR + 42]                     ; 偏移文件42字节处的属性是e_phentsize, 表示program header大小
    mov ebx, [KERNEL_BIN_BASE_ADDR + 28]                    ; e_phoff, 表示第一个program header在文件中的偏移量
    add ebx, KERNEL_BIN_BASE_ADDR
    mov cx, [KERNEL_BIN_BASE_ADDR + 44]                     ; e_phnum, 表示program header数量

.each_segment:
    cmp byte [ebx + 0], PT_NULL                             ; 若p_type等于PT_NULL, 说明此program header未使用
    je .PTNULL

; 为函数memcpy压入参数, 参数是从右往左依次压入, 函数原型类似memcpy(dst, src, size)
    push dword [ebx + 16]                                   ; program header中偏移16字节的地方是p_filesz
    mov eax, [ebx + 4]                                      ; program header中偏移4字节的位置是p_offset
    add eax, KERNEL_BIN_BASE_ADDR                           ; eax为该段的物理地址
    push eax                                                ; 压入函数memcpy第二个参数: 源地址
    push dword [ebx + 8]                                    ; 压入函数memcpy第一个参数: 目的地址, 偏移程序头8字节的位置是p_vaddr, 即目的地址
    
    call mem_cpy
    add esp, 12                                             ; 清理栈中压入的三个参数

.PTNULL:
    add ebx, edx                                            ; edx为program header大小, 即e_phentsize, 在此ebx指向下一个program header
    loop .each_segment
    ret

; - 逐字节拷贝 mem_cpy(dst, src, size) --------------------------------------------------------------
; 输入: 栈中三个参数
; 输出: 无
;--------------------------------------------------------------------------------------------------
mem_cpy:
    cld
    push ebp
    mov ebp, esp
    push ecx                                               ; rep指令用到了ecx, 但ecx对于外层段的循环还有用, 故先入栈备份
    mov edi, [ebp + 8]                                     ; dst
    mov esi, [ebp + 12]                                    ; src
    mov ecx, [ebp + 16]                                    ; size
    rep movsb                                              ; 逐字节拷贝
    ; 恢复环境
    pop ecx
    pop ebp
    ret

; 创建页目录和页表 -----------------------------------------------------------------------------------
setup_page:
; 先吧页目录项逐字节清0
    mov ecx, 4096
    mov esi, 0
.clear_page_dir:
mov byte [PAGE_DIR_TABLE_POS + esi], 0
inc esi
loop .clear_page_dir

; 开始创建页目录项 (PDE)
.create_pde:
    mov eax, PAGE_DIR_TABLE_POS
    add eax, 0x1000                                        ; 此时eax为第0个页表的位置
    mov ebx, eax                                           ; 为.create_pte做准备, ebx为基址

; 下面将页目录项0和0xc00都存为第一个页表的地址, 每个页表表示4MB内存
; 这样, 0xc03f_ffff以下的地址和0x003f_ffff以下的地址都指向相同的页表
; 这是为将地址映射为内核地址做准备
    or eax, PG_US_U | PG_RW_W | PG_P                       ; 所有特权级都可以访问
    mov [PAGE_DIR_TABLE_POS + 0x0], eax                    ; 首个页目录项指向首个页表的地址0x10_1000
    mov [PAGE_DIR_TABLE_POS + 0xc00], eax                  ; 第768个页目录项
    sub eax, 0x1000                                        ; eax指向页目录表
    mov [PAGE_DIR_TABLE_POS + 4092], eax                   ; 最后一个页目录项指向页目录表自身

; 下面创建首个页表的页表项:
    mov ecx, 256                                           ; 为1MB低端内存的256个页表项填充
    mov esi, 0
    mov edx, PG_US_U | PG_RW_W | PG_P
.create_pte:
    mov [ebx+esi*4], edx
    add edx, 4096
    inc esi
    loop .create_pte

; 创建内核其他页表的PDE
    mov eax, PAGE_DIR_TABLE_POS
    add eax, 0x2000                                        ; 此时eax为第二个页表的位置
    or eax, PG_US_U | PG_RW_W | PG_P
    mov ebx, PAGE_DIR_TABLE_POS
    mov ecx, 254                                           ; 范围为第769~1022的所有目录项数量
    mov esi, 769
.create_kernel_pde:
    mov [ebx+esi*4], eax
    inc esi
    add eax, 0x1000
    loop .create_kernel_pde
    ret

;-------------------------------------------------------------------------------
; 功能:读取硬盘n个扇区
; 输入 ecx, 需要读取的扇区数量
rd_disk_m_32:	   
;-------------------------------------------------------------------------------
							 ; eax=LBA扇区号
							 ; ebx=将数据写入的内存地址
							 ; ecx=读入的扇区数
      mov esi,eax	   ; 备份eax
      mov di,cx		   ; 备份扇区数到di
;读写硬盘:
;第1步：设置要读取的扇区数
      mov dx,0x1f2
      mov al,cl
      out dx,al            ;读取的扇区数

      mov eax,esi	   ;恢复ax

;第2步：将LBA地址存入0x1f3 ~ 0x1f6

      ;LBA地址7~0位写入端口0x1f3
      mov dx,0x1f3                       
      out dx,al                          

      ;LBA地址15~8位写入端口0x1f4
      mov cl,8
      shr eax,cl
      mov dx,0x1f4
      out dx,al

      ;LBA地址23~16位写入端口0x1f5
      shr eax,cl
      mov dx,0x1f5
      out dx,al

      shr eax,cl
      and al,0x0f	   ;lba第24~27位
      or al,0xe0	   ; 设置7～4位为1110,表示lba模式
      mov dx,0x1f6
      out dx,al

;第3步：向0x1f7端口写入读命令，0x20 
      mov dx,0x1f7
      mov al,0x20                        
      out dx,al

;;;;;;; 至此,硬盘控制器便从指定的lba地址(eax)处,读出连续的cx个扇区,下面检查硬盘状态,不忙就能把这cx个扇区的数据读出来

;第4步：检测硬盘状态
  .not_ready:		   ;测试0x1f7端口(status寄存器)的的BSY位
      ;同一端口,写时表示写入命令字,读时表示读入硬盘状态
      nop
      in al,dx
      and al,0x88	   ;第4位为1表示硬盘控制器已准备好数据传输,第7位为1表示硬盘忙
      cmp al,0x08
      jnz .not_ready	   ;若未准备好,继续等。

;第5步：从0x1f0端口读数据
      mov ax, di	   ;以下从硬盘端口读数据用insw指令更快捷,不过尽可能多的演示命令使用,
			   ;在此先用这种方法,在后面内容会用到insw和outsw等

      mov dx, 256	   ;di为要读取的扇区数,一个扇区有512字节,每次读入一个字,共需di*512/2次,所以di*256
      mul dx
      mov cx, ax	   
      mov dx, 0x1f0
  .go_on_read:
      in ax,dx		
      mov [ebx], ax
      add ebx, 2
			  ; 由于在实模式下偏移地址为16位,所以用bx只会访问到0~FFFFh的偏移。
			  ; loader的栈指针为0x900,bx为指向的数据输出缓冲区,且为16位，
			  ; 超过0xffff后,bx部分会从0开始,所以当要读取的扇区数过大,待写入的地址超过bx的范围时，
			  ; 从硬盘上读出的数据会把0x0000~0xffff的覆盖，
			  ; 造成栈被破坏,所以ret返回时,返回地址被破坏了,已经不是之前正确的地址,
			  ; 故程序出会错,不知道会跑到哪里去。
			  ; 所以改为ebx代替bx指向缓冲区,这样生成的机器码前面会有0x66和0x67来反转。
			  ; 0X66用于反转默认的操作数大小! 0X67用于反转默认的寻址方式.
			  ; cpu处于16位模式时,会理所当然的认为操作数和寻址都是16位,处于32位模式时,
			  ; 也会认为要执行的指令是32位.
			  ; 当我们在其中任意模式下用了另外模式的寻址方式或操作数大小(姑且认为16位模式用16位字节操作数，
			  ; 32位模式下用32字节的操作数)时,编译器会在指令前帮我们加上0x66或0x67，
			  ; 临时改变当前cpu模式到另外的模式下.
			  ; 假设当前运行在16位模式,遇到0X66时,操作数大小变为32位.
			  ; 假设当前运行在32位模式,遇到0X66时,操作数大小变为16位.
			  ; 假设当前运行在16位模式,遇到0X67时,寻址方式变为32位寻址
			  ; 假设当前运行在32位模式,遇到0X67时,寻址方式变为16位寻址.

      loop .go_on_read
      ret
    