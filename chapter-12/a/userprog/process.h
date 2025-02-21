#ifndef __PROCESS_H__
#define __PROCESS_H__

#define USER_VADDR_START 0x8048000
#define default_prio 31

void start_process(void* filename_);
void page_dir_activate(struct task_struct* p_thread);
void process_activate(struct task_struct* p_thread);
uint32_t* create_page_dir(void);
void create_user_vaddr_bitmap(struct task_struct* user_prog);
void process_execute(void* filename, char* name);

#endif