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

char* intr_name[IDT_DESC_CNT];//this is used to store the name of interrupt.it is used to help us after when there is interrupt
intr_handler idt_table[IDT_DESC_CNT];//in this array,we store the address of iterrupt handler.in kernel.S we use it to call the function to hand the interrrupt


//this fucntion is used to initialize the PIC(8259A)
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



//the two functions below are used to initialize the IDT
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


//this function is the general interrupt handler
static void general_intr_handler(uint8_t vec_nr){
	if(vec_nr == 0x27 || vec_nr == 0x2f){
		return;
	}
	put_str("int vector: 0x");
	put_int(vec_nr);
	put_char('\n');
}

static void exception_init(void) {
   int i;
   for (i = 0; i < IDT_DESC_CNT; i++) {
      idt_table[i] = general_intr_handler;//firstly all interrupt handler points this function,if someone need to change we will change later.
      intr_name[i] = "unknown";//firstly all name is unknown
   }
//we set the name of some exception the system used
   intr_name[0] = "#DE Divide Error";
   intr_name[1] = "#DB Debug Exception";
   intr_name[2] = "NMI Interrupt";
   intr_name[3] = "#BP Breakpoint Exception";
   intr_name[4] = "#OF Overflow Exception";
   intr_name[5] = "#BR BOUND Range Exceeded Exception";
   intr_name[6] = "#UD Invalid Opcode Exception";
   intr_name[7] = "#NM Device Not Available Exception";
   intr_name[8] = "#DF Double Fault Exception";
   intr_name[9] = "Coprocessor Segment Overrun";
   intr_name[10] = "#TS Invalid TSS Exception";
   intr_name[11] = "#NP Segment Not Present";
   intr_name[12] = "#SS Stack Fault Exception";
   intr_name[13] = "#GP General Protection Exception";
   intr_name[14] = "#PF Page-Fault Exception";
   //the fifteenth is reserved by the system not used.
   intr_name[16] = "#MF x87 FPU Floating-Point Error";
   intr_name[17] = "#AC Alignment Check Exception";
   intr_name[18] = "#MC Machine-Check Exception";
   intr_name[19] = "#XF SIMD Floating-Point Exception";

}



//this funtion call function idt_desc_init and pic_init to init them
void idt_init(){
	put_str("idt_init start\n");
	idt_desc_init();
	exception_init();
	pic_init();

	uint64_t idt_operand = ((sizeof(idt) -1) | ((uint64_t)(uint32_t)idt << 16));
	asm volatile ("lidt %0"::"m"(idt_operand));
	put_str("idt_init done\n");
}
