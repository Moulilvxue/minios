#include "print.h"
#include "global.h"
#include "stdint.h"
#include "interrupt.h"
#include "io.h"
#define PIC_M_CTRL 0x20
#define PIC_M_DATA 0x21
#define PIC_S_CTRL 0xa0
#define PIC_S_DATA 0xa1

#define IDT_DESC_CNT 0x21

//here we define the structure of ID(interrupt desciptor)
struct gate_desc{
	uint16_t func_offset_low_word;
	uint16_t selector;
	uint8_t dcount;
	uint8_t attribute;
	uint16_t func_offset_high_word;
};

static void make_idt_desc(struct gate_desc* p_gdesc,uint8_t attr,intr_handler function);
static struct gate_desc idt[IDT_DESC_CNT];
//the IDT is an array of ID(interrupt descriptor)


extern intr_handler intr_entry_table[IDT_DESC_CNT];
//this is an array of the address which points to the function of interrupt


static void pic_init(void){
	outb(PIC_M_CTRL,0x11);//master icw1
	outb(PIC_M_DATA,0x20);//master icw2
	outb(PIC_M_DATA,0x04);//master icw3
	outb(PIC_M_DATA,0x01);//master icw4

	outb(PIC_S_CTRL,0x11);//slave icw1
        outb(PIC_S_DATA,0x28);//slave icw2
        outb(PIC_S_DATA,0x02);//slave icw3
        outb(PIC_S_DATA,0x01);//slave icw4

	outb(PIC_M_DATA,0xfe);
	outb(PIC_S_DATA,0xff);
	put_str("    pic_init done\n");
}




static void make_idt_desc(struct gate_desc* p_gdesc,uint8_t attr,intr_handler function){
	p_gdesc->func_offset_low_word = (uint32_t) function & 0x0000ffff;
	p_gdesc->selector = SELECTOR_K_CODE;
	p_gdesc->dcount = 0;
	p_gdesc->attribute = attr;
	p_gdesc->func_offset_high_word = ((uint32_t)function &0xffff0000) >> 16;
}


static void idt_desc_init(void){
	int i;
	for(i=0;i<IDT_DESC_CNT;i++){
		make_idt_desc(&idt[i],IDT_DESC_ATTR_DPL0,intr_entry_table[i]);
	}
	put_str("     idt_desc_init done\n");
}


void idt_init(){
	put_str("idt_init start\n");
	idt_desc_init();
	pic_init();

	uint64_t idt_operand = ((sizeof(idt) -1) | ((uint64_t)(uint32_t)idt << 16));
	asm volatile ("lidt %0"::"m"(idt_operand));
	put_str("idt_init done\n");
}
