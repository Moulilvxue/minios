#include "init.h"
#include "print.h"
int main(void){
	put_str("i am a kernel\n");
	init_all();
	asm volatile ("sti");
	while(1);
	return 0;
}

