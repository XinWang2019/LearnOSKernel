#ifndef __TSS_H__
#define __TSS_H__

void update_tss_esp(struct task_struct* pthread);
void tss_init();

#endif