#ifndef _KERNEL_INTERRUPT_H
#define _KERNEL_INTERRUPT_H
#include "stdint.h"
typedef void* intr_handler;
void idt_init(void);
#endif

