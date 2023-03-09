;this is the third edition of MBR,in this edition,we use MBR to load the loader in 0x0;2 pf the disk,and we load it to the address of 0x900 of the memory
;the detial in page 130

%include "boot.inc"
SECTION MBR vstart=0x7c00
	;this sector we inite the register,they could not inite with immediate number
	;so we inite them with register cs,because in the end of the BIOS,in order to
	;run MBR,it will make cs=0.
        mov ax,cs
        mov ds,ax
        mov es,ax
        mov ss,ax
        mov fs,ax
        mov sp,0x7c00
        mov ax,0xb800
        mov gs,ax

	;in this sector we use BIOS interrupt 0x10 to clear the output of BIOS(when 
	;BIOS runs ,it will show some information in the screen).
        mov ax,0x0600
        mov bx,0x0700
        mov cx,0
        mov dx,0x184f

        int 0x10
	
	;this sector we output the 1MBR in the screen
        mov byte [gs:0x00],'1'
        mov byte [gs:0x01],0xA4

        mov byte [gs:0x02],' '
        mov byte [gs:0x03],0xA4
 
	mov byte [gs:0x04],'M'
        mov byte [gs:0x05],0xA4

        mov byte [gs:0x06],'B'
        mov byte [gs:0x07],0xA4

        mov byte [gs:0x08],'R'
        mov byte [gs:0x09],0xA4

        ;this sector we give the parameters to the method rd_disk_m_16
	;and call it
	mov eax,LOADER_START_SECTOR  ;the LBA address of the loader in the disk
	mov bx,LOADER_BASE_ADDR    ;the address where to put the loader in the memory
	mov cx,4                  ;the number of sector we try to read(changed from 1 to 4)
	call rd_disk_m_16

	jmp LOADER_BASE_ADDR+0x300      ;when loader was loaded to memory, jump to here
 

                            	  
rd_disk_m_16:                     ;the method of rd_disk_m_16
	mov esi,eax
	mov di,cx                 ;save eax and cx because we will use them after

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
	mov ax,di      		    ;the sector number we want to read, here is just 1
	mov dx,256		    ;each sector need to read 256 times
	mul dx			    ;the other operator is ax,and the ans in ax
	mov cx,ax

	mov dx,0x1f0		    ;we get the data from port 0x1f0(data)
   .go_on_read:
	in ax,dx
	mov [bx],ax
	add bx,2
	loop .go_on_read
	ret
	

    times 510-($-$$) db 0

    db 0x55,0xaa
