.model tiny

jumps ; fixes jump out of range somehow
.code
org 100h

locals @@ ; from now on each identifier beginning from @@ will only work in the scope it was declared
start:
	jmp main

print macro a
	local @@start, @@msg
	push ax dx ds
	jmp @@start
@@msg db a, 0Dh, 0Ah,'$'
@@start:
	mov ah,9
	lea dx, @@msg
	int 21h
	pop ds dx ax
endm

	
oldInt9Seg dw ?
oldInt9Off dw ?
hexAlphabet db "0123456789ABCDEF$"

wasEscapePressed db 0
wasEnterPressed db 0
isTunePlaying db 0
currentNote db 0

Note_C equ 9121d
Note_Cs equ 8609d
Note_D equ 8126d
Note_Ds equ 7670d
Note_E equ 7239d
Note_F equ 6833d
Note_Fs equ 6449d
Note_G equ 6087d
Note_Gs equ 5746d
Note_A equ 5424d
Note_B equ 5120d
Note_H equ 4832d
Note_C2 equ 4560d
Note_Cs2 equ 8609d / 2
Note_D2 equ 8126d / 2
Note_Ds2 equ 7670d / 2
Note_E2 equ 7239d / 2
Note_F2 equ 6833d / 2
Note_Fs2 equ 6449d / 2
Note_G2 equ 6087d / 2


handleNote macro key, freq
	local next, handleEnd, antiKey
antiKey equ key + 80h
	cmp al, key
	jne next
	mov [currentNote], al
	mov bx, freq
	call playSoundFromBx
next:
	cmp al, antiKey
	jne handleEnd
	cmp [currentNote], key
	jne handleEnd
	call offSound
	mov [currentNote], 0
handleEnd:
	
endm


offSound proc
	push ax
	in      al, 61h
	and     al, 11111100b
	out     61h, al
	pop ax
	ret
endp

playSoundFromBx proc
	push ax bx cx dx

	mov     al, 10110110b    ; the magic number (use this binary number only!)
	out     43h, al          ; send it to the initializing port 43h timer 2.

	mov     ax, bx           ; move our frequency value into ax.

	out     42h, al          ; send lsb to port 42h.
	mov     al, ah           ; move msb into al
	out     42h, al          ; send msb to port 42h.

	in      al, 61h          ; get current value of port 61h.
	or      al, 00000011b    ; or al to this value, forcing first two bits high.
	out     61h, al          ; copy it to port 61h of the ppi chip
							 ; to turn on the speaker.


	pop dx cx bx ax
	ret
endp

playNote proc ; bx = freq or 0 if silence, cx = length
	push ax bx cx dx es
	mov ax, 0
	mov es, ax
	add cx, [word ptr es:046Ch]
	cmp bx, 0
	je delay
	call playSoundFromBx
delay:
	cmp [word ptr es:046Ch], cx
	jne delay
	
	call offSound
	
	pop es dx cx bx ax
	ret
endp

playNote_m macro note, len
	mov bx, note
	mov cx, len
	call playNote
endm

playTune proc
	push ax bx cx dx
	mov [isTunePlaying], 1
	playNote_m Note_C2 4
	playNote_m Note_H 4
	playNote_m Note_C2 4
	playNote_m 0 4
	playNote_m Note_G 4
	playNote_m 0 4
	playNote_m Note_Gs 4
	playNote_m 0 4
	playNote_m Note_C2 4
	playNote_m Note_H 4
	playNote_m Note_C2 4
	playNote_m 0 4
	playNote_m Note_D2 4
	playNote_m 0 4
	playNote_m Note_G 4
	playNote_m 0 4
	playNote_m Note_C2 4
	playNote_m Note_H 4
	playNote_m Note_C2 4
	playNote_m 0 4
	playNote_m Note_D2 4
	playNote_m 0 4
	playNote_m Note_F 4
	playNote_m Note_G 4
	playNote_m Note_Gs 12d
	playNote_m 0 4
	playNote_m Note_G 4
	playNote_m Note_F 4
	playNote_m Note_Ds 8
	
	mov [isTunePlaying], 0
	pop dx cx bx ax
	ret
endp

newInt9 proc far
	push ax bx
	cli
	in al, 60h
	cmp [isTunePlaying], 1
	je @@checkEscape
	
	handleNote 10h, Note_C
	handleNote 03h, Note_Cs
	handleNote 11h, Note_D
	handleNote 04h, Note_Ds
	handleNote 12h, Note_E
	handleNote 13h, Note_F
	handleNote 06h, Note_Fs
	handleNote 14h, Note_G
	handleNote 07h, Note_Gs
	handleNote 15h, Note_A
	handleNote 08h, Note_B
	handleNote 16h, Note_H
	handleNote 17h, Note_C2
	handleNote 0Ah, Note_Cs2
	handleNote 18h, Note_D2
	handleNote 0Bh, Note_Ds2
	handleNote 19h, Note_E2
	handleNote 1Ah, Note_F2
	handleNote 0Dh, Note_Fs2
	handleNote 1Bh, Note_G2	

@@checkEscape:
	cmp al, 01h
	jne @@checkEnter
	mov [wasEscapePressed], 1

@@checkEnter:
	cmp al, 1Ch
	jne @@notEnter
	mov [wasEnterPressed], 1
	jmp @@end
@@notEnter:
	mov [wasEnterPressed], 0
	jmp @@end
@@end:
	mov al, 20h ;Send EOI (end of interrupt)
	out 20h, al ; to the 8259A PIC.
	pop bx ax
	iret
endp

help:
	print "USAGE: plays music:"
	print "qwertyuiop[]2356790= - these keys mean notes"
	print "Enter - for sample tune"
	print "Esc - for exit"
	ret
main:
	cmp [byte ptr cs:80h], 0
	jne help
	
	mov ax, 3509h
	int 21h
	mov [oldInt9Seg], es
    mov [oldInt9Off], bx
	mov ax, 2509h
    mov dx, offset newInt9
    int 21h
whileIsNotEsc:
	cmp [wasEnterPressed], 1
	jne enterWasNotPressed
	call playTune
enterWasNotPressed:
	cmp [wasEscapePressed], 1
	jne whileIsNotEsc
	
    mov dx, [oldInt9Off]
	mov ax, [oldInt9Seg]
	mov ds, ax
	mov ax, 2509h
    int 21h
	call offSound
	ret
end start