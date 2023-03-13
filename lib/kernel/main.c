#include "print.h"
int main(void){
	put_str("i am a kernel\n");
	put_int(0);
	put_char('\n');
	put_int(0x000123af);
	put_char('\n');
	while(1);
	return 0;
}

