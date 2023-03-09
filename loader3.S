%include "boot.inc"

section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR
;here we do not use jmp anymore

;here we set GDT with 4 segment descriptor and reserved 60 segment descriptor space, each segment descriptor is set by writing the lower 4 bytes and higher 4 bytes directly

GDT_BASE: dd 0x00000000
	  dd 0x00000000
	;the first segment descriptor of the GDT is useless so we set it 0

CODE_DESC: dd 0x0000ffff
	   dd DESC_CODE_HIGH4
;in the flat pattern each segment is 4GB, so we set the base address of each segment 0 but the offset of each segment is the maximum,so the lower 4 BYTEs is 0x0000ffff,the higher 4 BYTEs is set in document boot.inc so we could use it directly

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
	;initialize the registers
	mov ax,SELECTOR_DATA
	mov ds,ax
	mov es,ax
	mov ss,ax
	mov esp,LOADER_STACK_TOP
	mov ax,SELECTOR_VIDEO
	mov gs,ax

	
	;here we call a method to read the kernel into the memory
	mov eax,KERNEL_START_SECTOR
	mov ebx,KERNEL_BIN_BASE_ADDR
	mov ecx,200 
	call rd_disk_m_32


	;
	;now, we will start to use virtual address
	;

	call setup_page ;call the method to set up PDE and PTE

	sgdt [gdt_ptr]	;we save the address of GDT,because we will put it in the highest 1GB space in the virtual address(put it in the kernel)
	mov ebx,[gdt_ptr+2]	;get the base address of GDT,in order to get the base address of the video space and then put it in the kernel
	or dword [ebx+0x18+4],0xc0000000	;set the base address of video in the highest 1GB,in the kekrnel
	
	add dword [gdt_ptr+2],0xc0000000	;set the base address of GDT in the highest 1GB space, in the kernel
	
	add esp,0xc0000000	;set the pointer of stack
	
	mov eax,PAGE_DIR_TABLE_POS
	mov cr3,eax	;set the cr3 register

	mov eax,cr0
	or eax,0x80000000
	mov cr0,eax	;set the 31 bite(pg site) of cr0 with 1 to open virtual space
	
	lgdt [gdt_ptr]	;reload the GDT
	mov byte [gs:160],'V'	;each line 80 characters,each character use 2 bites,so each line use 160 bites,so here the character v will output on the second line
	
	jmp $

	;here we accomplish the set page method
setup_page:
	mov ecx,4096	;clear the space for PDE
	mov esi,0
.clear_page_dir:
	mov byte [PAGE_DIR_TABLE_POS+esi],0	;set the space with 0 byte by byte
	inc esi
	loop .clear_page_dir

	;here we start to set the PDE,totally we just set three PDE,the first one number 0, the last one number 1023 and the 769th number 768
.create_pde:	
	mov eax,PAGE_DIR_TABLE_POS
	add eax,0x1000
	mov ebx,eax	;save the base address of the PTE and we will use it later
	
	or eax,PG_US_U | PG_RW_W | PG_P 	;set the feature of the PDE
	mov [PAGE_DIR_TABLE_POS+0x0],eax	;set the first one
	mov [PAGE_DIR_TABLE_POS+0xc00],eax	;set the number 768
	
	sub eax,0x1000
	mov [PAGE_DIR_TABLE_POS+4092],eax	;set the last one with the address of the PDE itself
	 
	;now we are going to create PTE
	mov ecx,256
	mov esi,0
	mov eax,PG_US_U | PG_RW_W |PG_P
.create_pte:
	mov [ebx+esi*4],eax
	inc esi
	add eax,4096
	loop .create_pte
	
	;create other PDE,we will set all PDE in order to share the kernel space
	mov eax,PAGE_DIR_TABLE_POS
	add eax,0x2000	;the address of the second PTE,it will be saved in the second PDE
	or eax,PG_US_U | PG_RW_W | PG_P
	mov ebx,PAGE_DIR_TABLE_POS
	mov ecx,254	;from 769 to 1022 there are 254 PDE left
	mov esi,769	;in order to set the address of the PDE we want to set
.create_kernel_pde:
	mov [ebx+esi*4],eax
	add eax,0x1000
	inc esi
	loop .create_kernel_pde

	ret
	
	
                            	  
rd_disk_m_32:                     ;the method of rd_disk_m_16
	mov esi,eax
	mov edi,ecx                 ;save eax and cx because we will use them after

	mov dx,0x1f2
	mov al,cl		  ;to set the port 0x1f2(sector count) with sector 
	out dx,al                 ;number we will read

	mov eax,esi		  ;restore the value of eax

	;this sector we set the LBA address
	mov dx,0x1f3
	out dx,al

	mov cl,8
	shr eax,cl		   ;shift right logical 8
	mov dx,0x1f4
	out dx,al

	shr eax,cl
	mov dx,0x1f5
	out dx,al

	shr eax,cl
	and al,0x0f		   ;here we set the port 0x1f6(device)
	or al,0xe0
	mov dx,0x1f6
	out dx,al

	mov dx,0x1f7		   ;set the order,0x20 means read the sector
	mov al,0x20
	out dx,al

	;this sector we check the status of the port ,if it is ready we could read the        ;disk
   
   .not_ready:
	nop
	in al,dx		   ;the dx is not change,there we could get the status
	and al,0x88                
	cmp al,0x08
	jnz .not_ready

	;if port is ready we could get the data,each time we could get just 2B,so need	      ;a loop,register cx will store the times
	mov eax,edi      		    ;the sector number we want to read, here is just 1
	mov edx,256		    ;each sector need to read 256 times
	mul edx			    ;the other operator is ax,and the ans in ax
	mov ecx,eax

	mov dx,0x1f0		    ;we get the data from port 0x1f0(data)

   .go_on_read:
	in ax,dx
	mov [ebx],ax
	add ebx,2
	loop .go_on_read
	ret

	


