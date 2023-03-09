%include "boot.inc"

section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR
;here we do not use jmp anymore

;here we set GDT with 4 segment descriptor and reserved 60 segment descriptor space each segment descriptor is set by write the lower 4 bytes and higher 4 bytes directly

GDT_BASE: dd 0x00000000
	  dd 0x00000000
	;the first segment descriptor of the GDT is useless so we set it 0

CODE_DESC: dd 0x0000ffff
	   dd DESC_CODE_HIGH4
;in the flat pattern each sector is 4GB, so we set the base address of each sector is 0 but the offset of each sector is the maximum,so the lower 4 BYTEs is 0x0000ffff,the higher 4 BYTEs is set in document boot.inc so we could use it directly

DATA_STACK_DESC:  dd 0x0000ffff
		  dd DESC_DATA_HIGH4

VIDEO_DESC: dd 0x80000007
	    dd DESC_VIDEO_HIGH4
;here for video, in real mode,the memory space for show character is 0xbffff-0xb8000,so the beginning address is 0xb8000,so the segment_base_address is 0xb8000,and for the lower 4 bytes of the segment descriptor,the higher 16 bites is for the segment_base_address's 0-15 bite,so it is 8 and for the offset,for the unit is 4kB,so the offset is (0xbffff-0xb8000)/4k = 7

GDT_SIZE equ $-GDT_BASE
GDT_LIMIT equ GDT_SIZE-1 	;here we get the limit of the segment,it will be used to set GDTR

times 60 dq 0   ;reserve 60 spaces for segment descriptors

		;set selector
SELECTOR_CODE equ (0x0001<<3) + TI_GDT + RPL0
SELECTOR_DATA equ (0x0002<<3) + TI_GDT + RPL0
SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0

total_mem_bytes dd 0
;here we use 'total_mem_bytes' to storage the address of the final result of the memory size.and the address of 'total_mem_bytes' is 0xb00. Because the offset of this command in the file is 0x200, and the laod address of the file is 0x900, so the final address of 'total_mem_bytes' is 0x200+0x900=0xb00


gdt_ptr dw GDT_LIMIT
	dd GDT_BASE
;here we get the address for GDTR

ards_buf times 244 db 0		;we remain 244 bytes here, because when we use method 0xE820,we need space to storage the ARDS, we choose 244 bytes, just in order to make the address of 'loader_start:' 0x300,and in mbr3.S,we have changed the jmp address for 'jmp LOADER_BASE_ADDR' to 'jmp LOADER_BASE_ADDR+0x300',so from mbr3.S,it could jump to 'loader_start' directly.
ards_nr dw 0	;it is used to storage a address where storage the numbers of ARDS.



loader_start:
	;first,we get the memory by three method
	xor ebx,ebx	;set ebx 0,we use it to appoint the ARDS we get,the first one is 0
	mov edx,0x534d4150	;a label, it is fixed
	mov di,ards_buf		;the address of the buffer of ARDS,ES;DI appoints the address of buffer,ES has set in MBR with 0
.e820_mem_get_loop:		;each time we get one ARDS,the data of eax and ecx will change ,so we put them in the loop
	mov eax,0x0000e820	;the submethod is 0xe820
	mov ecx,20		;each time we get 20 bytes
	int 0x15
	jc .e820_failed_so_try_e801	;if the method e820 failed,then CF=1,then jump to method e801
	add di,cx		;di plus 20 bytes,point the new address for new ARDS
	inc word [ards_nr]	;the number of ARDS plus 1
	cmp ebx,0		;if CF=0,it could run to here,and if ebx=0,means no ARDS anymore
	jnz .e820_mem_get_loop  ;if ebx is not 0, means there are still ARDS,then loop
	
	;then we compute each ARDS,get the biggest useful memory,put it in edx
	mov cx,[ards_nr]	;set the loop times by the ARDS numbers
	mov ebx,ards_buf	;the address of ARDS
	xor edx,edx
.find_max_mem_area:
	mov eax,[ebx]		;the first 4 bytes of the ARDS is the lower base address of the memory
	add eax,[ebx+8]		;here is the lower length of the memory,add to the base address we get the total address
	add ebx,20		;to get the address of the next ARDS
	cmp edx,eax
	jge .next_ards		;if the memory in edx is larger,we loop to next ARDS
	mov edx,eax		;if the memory in eax is larger,put it in edx
.next_ards:
	loop .find_max_mem_area
	jmp .mem_get_ok		;the loop is over,we get the result
	

.e820_failed_so_try_e801:
	mov ax,0xe801
	int 0x15
	jc .e801_failed_so_try88
	mov cx,0x400		;the unit of the cx is KB,so it need to multiple 0x400,0x400=1000
	mul cx			;another is ax,and the result lower in ax, higher in dx
	shl edx,16
	and eax,0x0000FFFF
	or edx,eax		;then we get the 32 bites result of the lower 15MB memory
	add edx,0x100000	;here we need to add 1MB
	mov esi,edx		;we will use edx later,so storage the result in esi
	
	;compute the higher 
	xor eax,eax
	mov ax,bx		;the bx storage the number of higher memory blocks(16M-4GB),each is 64KB
	mov ecx,0x10000		;0x10000=64K
	mul ecx			;the higher result in edx,and lower in eax,because the total is 4GB,so edx=0
	add esi,eax
	mov edx,esi
	jmp .mem_get_ok

.e801_failed_so_try88:
	mov ah,0x88
	int 0x15
	jc .error_hlt		;if the last method also failed,then failed
	and eax,0x0000ffff	;after the halt,the result in ax,but the unit is KB,so change to B
	mov cx,0x400		;0x400=1K
	mul cx			;the higher 2 bytes ans in dx,and lower 2 bytes in ax
	shl edx,16
	or edx,eax
	add edx,0x100000	;there are 1MB need to add
	

.mem_get_ok:
	mov [total_mem_bytes],edx	;finally,write the memory area into here,no matter which method is succeed
	

	;now get into the protection mode

	;open the A20
	in al,0x92
	or al,0000_0010B
	out 0x92,al

	;load GDT
	lgdt [gdt_ptr]

	;put the situation 0 of cr0 as 1
	mov eax,cr0
	or eax,0x00000001
	mov cr0,eax

	jmp dword SELECTOR_CODE:p_mode_start  ;refresh the pipeline for we will use 32bite

.error_hlt:
	hlt

[bits 32]
p_mode_start:
	;inite the registers
	mov ax,SELECTOR_DATA
	mov ds,ax
	mov es,ax
	mov ss,ax
	mov esp,LOADER_STACK_TOP
	mov ax,SELECTOR_VIDEO
	mov gs,ax
	
	mov byte [gs:160],'p';each line 80 characters,each character use 2 bites,so each line use 160 bites,so here the character p will output on the second line
	jmp $
