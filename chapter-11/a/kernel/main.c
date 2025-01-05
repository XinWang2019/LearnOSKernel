#include "print.h"
#include "init.h"
#include "debug.h"
#include "thread.h"
#include "console.h"
#include "ioqueue.h"
#include "keyboard.h"
#include "interrupt.h"

void k_thread_a(void* arg);
void k_thread_b(void* arg);

int main(void) {
    put_str("I am kernel\n");
    init_all();

    thread_start("consumer_a", 31, k_thread_a, " A_");
    thread_start("consumer_b", 31, k_thread_b, " B_");

    intr_enable(); // 打开中断，使时钟中断起作用

    while(1);
    // {
    //     console_put_str("Main ");
    // };
    return 0;
}

/* 在线程中运行的函数 */
void k_thread_a(void* arg) {
    /* 用void*来通用表示参数，被调用的函数知道自己需要什么类型的参数，自己转换再用 */
    char* para = arg;
    while(1) {
        enum intr_status old_status = intr_disable();
        if (!ioq_empty(&kbd_buf)) {
            console_put_str(para);
            char byte = ioq_getchar(&kbd_buf);
            console_put_char(byte);
        }
        intr_set_status(old_status);
    }
}

/* 在线程中运行的函数 */
void k_thread_b(void* arg) {
    /* 用void*来通用表示参数，被调用的函数知道自己需要什么类型的参数，自己转换再用 */
    char* para = arg;
    while(1) {
        enum intr_status old_status = intr_disable();
        if (!ioq_empty(&kbd_buf)) {
            console_put_str(para);
            char byte = ioq_getchar(&kbd_buf);
            console_put_char(byte);
        }
        intr_set_status(old_status);
    }
}