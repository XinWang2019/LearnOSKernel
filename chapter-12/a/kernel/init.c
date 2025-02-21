#include "init.h"
#include "print.h"
#include "interrupt.h"
#include "../device/timer.h"
#include "memory.h"
#include "thread.h"
#include "../device/console.h"
#include "../device/keyboard.h"
#include "../userprog/tss.h"

/* 负责初始化所有模块 */
void init_all() {
    put_str("init_all\n");
    idt_init(); // 初始化中断
    mem_init();
    thread_init();
    timer_init(); // 初始化PIT
    keyboard_init();
    console_init(); // 控制台初始化最好放在开中断之前
    tss_init();
}