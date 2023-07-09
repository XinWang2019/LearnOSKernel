; loader 和 kernel -------------------------------------------------------------

LOADER_BASE_ADDR equ 0x900
LOADER_START_SECTOR equ 0x2
PAGE_DIR_TABLE_POS equ 0x10_0000

KERNEL_START_SECTOR equ 0x9
KERNEL_BIN_BASE_ADDR equ 0x7_0000
KERNEL_ENTRY_POINT equ 0xc000_1500

; GDT描述符属性 --------------------------------------------------------------------
DESC_G_4K equ         1000_0000_0000_0000_0000_0000b ; G, 段界限粒度为4KB
DESC_D_32 equ          100_0000_0000_0000_0000_0000b ; D/B, 用于代码段, 表示命令中操作数和有效地址为32位, 使用EIP寄存器
DESC_L    equ           00_0000_0000_0000_0000_0000b ; L, 表示32位代码段
DESC_AVL  equ            0_0000_0000_0000_0000_0000b ; AVL
DESC_LIMIT_CODE2  equ      1111_0000_0000_0000_0000b ; 段界限高4位
DESC_LIMIT_DATA2  equ      DESC_LIMIT_CODE2
DESC_LIMIT_VIDEO2 equ       000_0000_0000_0000_0000b
DESC_P            equ           1000_0000_0000_0000b ; P, 表示段存在于内存中
DESC_DPL_0        equ            000_0000_0000_0000b
DESC_DPL_1        equ            010_0000_0000_0000b
DESC_DPL_2        equ            100_0000_0000_0000b
DESC_DPL_3        equ            110_0000_0000_0000b
DESC_S_CODE       equ              1_0000_0000_0000b ; S, 表示为数据段
DESC_S_DATA       equ              DESC_S_CODE
DESC_S_SYS        equ              0_0000_0000_0000b
DESC_TYPE_CODE    equ                1000_0000_0000b ; TYPE, 代码段可执行, 非一致, 不可读, 该内存段未被访问
DESC_TYPE_DATA    equ                0010_0000_0000b ; TYPE, 数据段不可执行, 向上扩展, 可写, 该内存段未被访问

DESC_CODE_HIGH4   equ (0x00 << 24) + DESC_G_4K + DESC_D_32 + \
DESC_L + DESC_AVL + DESC_LIMIT_CODE2 + \
DESC_P + DESC_DPL_0 + DESC_S_CODE + \
DESC_TYPE_CODE + 0x00

DESC_DATA_HIGH4   equ (0x00 << 24) + DESC_G_4K + DESC_D_32 + \
DESC_L + DESC_AVL + DESC_LIMIT_DATA2 + \
DESC_P + DESC_DPL_0 + DESC_S_DATA + \
DESC_TYPE_DATA + 0x00

DESC_VIDEO_HIGH4   equ (0x00 << 24) + DESC_G_4K + DESC_D_32 + \
DESC_L + DESC_AVL + DESC_LIMIT_VIDEO2 + \
DESC_P + DESC_DPL_0 + DESC_S_DATA + \
DESC_TYPE_DATA + 0x0b

; 选择子属性 -----------------------------------------------------------------------
RPL0 equ 00b
RPL1 equ 01b
RPL2 equ 10b
RPL3 equ 11b
TI_GDT equ 000b
TI_LDT equ 100b

; 页表相关属性 ------------------------------------------------------------------------------------------
PG_P    equ 1b
PG_RW_R equ 00b
PG_RW_W equ 10b
PG_US_S equ 000b
PG_US_U equ 100b

; elf文件中program header的p_type字段取值 ----------------------------------------------------------------
PT_NULL equ 0
PT_LOAD equ 1