; mul32.asm
; CSC 230 - Summer 2017
;
; This program performs multiplation by repetitive adding


.cseg
.org 0
	; Initialization code
	; Do not move or change these instructions or the registers they refer to. 
	; You may change the data values being loaded.
	; The default values set A = 0x3412 and B = 0x2010
	ldi r16, 0xFF ;Low byte of operand A
	ldi r17, 0xFF;High byte of operand A
	ldi r18, 0xFF ;Low byte of operand B
	ldi r19, 0xFF ;High byte of operand B

	;Set everything to zero
	ldi r20, 0x00	
	ldi r21, 0x00 	
	ldi r22, 0x00 	
	ldi r23, 0x00  
	ldi r24, 0x00   ;Set to zero empty slot to add with carry
	ldi r25, 0x00   ;Use for loop counter low byte
	ldi r26, 0x00	;Use for loop counter high byte
	ldi r28, 0x01   ;Use as flag for counter


	mov r26, r18 ; Store value of low byte B in counter
	mov r25, r19 ; Store value of high byte B in counter

loop:
	add r23, r16  ; Add low byte1 to itself
	adc r22, r17  ; Add high byte1 to itself (Order for readability)
	adc r21, r24  ; For overflow
	adc r20, r24  ; For overflow

	tst r28
	brne DecLow   ;If r28 has flag set then decrement low register
	tst r26	  	  ; Compare low byte of counter to zero
	brne DecLow  ; If High value is not zero then decrement
	
rjmp loop

DecHigh:
	dec r25
	ldi r28, 0x01 ;Set to 0x01 if high bit decremented
	rjmp loop

DecLow:
	ldi r28, 0x00
	dec r26
	tst r25	  ; Compare high counter to zero 
	breq test_counter	  ; If high counter reaches zero then exit
	tst r26	  	  ; Compare low byte of counter to zero
	breq DecHigh   ; Otherwise decrement high value
	

	rjmp loop
	
	
	; Your task: compute the 32-bit product A*B (using the bytes from registers r16 - r19 above as the values of
	; A and B) and store the result in the locations OUT3:OUT0 in data memory (see below).
	; You are encouraged to use a simple loop with repeated addition, not the MUL instructions, although you are
	; welcome to use MUL instructions if you want a challenge.

test_counter:
	tst r26 ;If reached here and both counter bytes are zero then break out 
	breq add_to_mem
	rjmp loop ;If both counters are not zero then return to loop
	
add_to_mem:
	STS OUT0,r23	
	STS OUT1,r22
	STS OUT2,r21
	STS OUT3,r20

	
	; End of program (do not change the next two lines)
stop:
	rjmp stop

	
; Do not move or modify any code below this line. You may add extra variables if needed.
; The .dseg directive indicates that the following directives should apply to data memory
.dseg 
.org 0x200 ; Start assembling at address 0x200 of data memory (addresses less than 0x200 refer to registers and ports)

OUT0:	.byte 1 ; Bits  7...0 of the output value
OUT1:	.byte 1 ; Bits 15...8 of the output value
OUT2:	.byte 1 ; Bits 23...16 of the output value
OUT3:	.byte 1 ; Bits 31...24 of the output value
