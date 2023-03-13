%include "boot.inc"

section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR
jmp loader_start

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

gdt_ptr dw GDT_LIMIT
	dd GDT_BASE
;here we get the address for GDTR

loadermsg db '2 loader in real.'		;the message to show

loader_start:
	mov sp,LOADER_BASE_ADDR
	mov bp,loadermsg
	mov cx,17	;the length of the sentence loadermsg
	mov ax,0x1301
	mov bx,0x001f
	mov dx,0x1800
	int 0x10

			;now get into the save mode

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
