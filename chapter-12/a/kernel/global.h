#ifndef __KERNEL_GLOBAL_H__
#define __KERNEL_GLOBAL_H__
#include "stdint.h"

#define NULL ((void*)0)
#define PG_SIZE 4096
#define DIV_ROUND_UP(X, STEP) ((X + STEP - 1) / (STEP))

#define RPL0 0
#define RPL1 1
#define RPL2 2
#define RPL3 3
//------------------------ GDT描述符属性------------------------//
#define DESC_G_4K    1
#define DESC_D_32    1
#define DESC_L       0 // 64位代码标记，此处标记为0即可
#define DESC_AVL     0 // cpu不用此位，暂置为0
#define DESC_P       1
#define DESC_DPL_0   0
#define DESC_DPL_1   1
#define DESC_DPL_2   2
#define DESC_DPL_3   3
/**
 * 代码段和数据段属于存储段，tss和各种门描述符属于系统段，
 * s为1时表示存储段，为0时表示系统段
 */
#define DESC_S_CODE    1
#define DESC_S_DATA    DESC_S_CODE
#define DESC_S_SYS     0
#define DESC_TYPE_CODE 8
// x=1,c=0,r=0,a=0代码段是可执行的、非依从的、不可读的, 已访问位a清0

#define DESC_TYPE_DATA 2
// x=0,e=0,w=1,a=0数据段是不可执行的、向上扩展的、可写的，已访问位a清0

#define DESC_TYPE_TSS  9 // B位为0,不忙

#define TI_GDT 0
#define TI_LDT 1

#define SELECTOR_K_CODE     ((1 << 3) + (TI_GDT << 2) + RPL0)
#define SELECTOR_K_DATA     ((2 << 3) + (TI_GDT << 2) + RPL0)
#define SELECTOR_K_STACK     SELECTOR_K_DATA
#define SELECTOR_K_GS       ((3 << 3) + (TI_GDT << 2) + RPL0)
/* 第3个段描述符是显存，第4个是tss */
#define SELECTOR_U_CODE     ((5 << 3) + (TI_GDT << 2) + RPL3)
#define SELECTOR_U_DATA     ((6 << 3) + (TI_GDT << 2) + RPL3)
#define SELECTOR_U_STACK    SELECTOR_U_DATA

#define GDT_ATTR_HIGH          ((DESC_G_4K << 7) + (DESC_D_32  << 6) + (DESC_L      << 5) + (DESC_AVL << 4))
#define GDT_CODE_ATTR_LOW_DPL3 ((DESC_P    << 7) + (DESC_DPL_3 << 5) + (DESC_S_CODE << 4) +  DESC_TYPE_CODE)
#define GDT_DATA_ATTR_LOW_DPL3 ((DESC_P    << 7) + (DESC_DPL_3 << 5) + (DESC_S_DATA << 4) +  DESC_TYPE_DATA)

//----------TSS描述符属性-----------------------------
#define TSS_DESC_D    0
#define TSS_ATTR_HIGH ((DESC_G_4K << 7) + (TSS_DESC_D << 6) + (DESC_L << 5)     + (DESC_AVL << 4) + 0x0)
#define TSS_ATTR_LOW  ((DESC_P << 7)    + (DESC_DPL_0 << 5) + (DESC_S_SYS << 4) + DESC_TYPE_TSS)
#define SELECTOR_TSS  ((4 << 3) + (TI_GDT << 2) + RPL0)

/* 定义GDT中描述符的结构 */
struct gdt_desc {
    uint16_t limit_low_word;
    uint16_t base_low_word;
    uint8_t  base_mid_byte;
    uint8_t  attr_low_byte;
    uint8_t  limit_high_attr_high;
    uint8_t  base_high_byte;
};

/*---------- IDT描述符属性 ----------*/
#define IDT_DESC_P 1
#define IDT_DESC_DPL0 0
#define IDT_DESC_DPL3 3
#define IDT_DESC_32_TYPE 0xE // 32位的门
#define IDT_DESC_16_TYPE 0x6 // 16位的门, 不会用到
#define IDT_DESC_ATTR_DPL0 ((IDT_DESC_P << 7) + (IDT_DESC_DPL0 << 5) + IDT_DESC_32_TYPE)
#define IDT_DESC_ATTR_DPL3 ((IDT_DESC_P << 7) + (IDT_DESC_DPL3 << 5) + IDT_DESC_32_TYPE)

#define bool int
#define true 1
#define false 0

#define EFLAGS_MBS    (1 << 1) // 此项必须要设置
#define EFLAGS_IF_1   (1 << 9) // if为1，开中断
#define EFLAGS_IF_0   0        // if为0，关中断
#define EFLAGS_IOPL_3 (3 << 12)// IOPL3，用于测试用户程序在非系统调用下进行IO
#define EFLAGS_IOPL_0 (0 << 12)// IOPL0

#endif