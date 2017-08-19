; divmod16.asm
; CSC 230 - Summer 2017
; Iain Emslie CSC 230
;
; This program performs multiplication using register additions
; Based on a template by Bill Bird

.cseg
.org 0

	; Initialization code
	; Do not move or change these instructions or the registers they refer to. 
	; You may change the data values being loaded.
	; The default values set A = 0x3412 and B = 0x0003
	ldi r16, 0x0F ;Low byte of operand A
	ldi r17, 0x7C ;High byte of operand A
	ldi r18, 0xEC ;Low byte of operand B
	ldi r19, 0x72 ;High byte of operand B
	
	; Your task: Perform the integer division operation A/B and store the result in data memory. 
	; Store the 2 byte quotient in DIV1:DIV0 and store the 2 byte remainder in MOD1:MOD0.

;Set labels for registers
.def A_LOW = r25
.def A_HIGH = r24
.def B_LOW = r27
.def B_HIGH = r26
.def COUNTER_HIGH = r28	
.def COUNTER_LOW = r29
.def COUNTER_ADD = r20
.def COUNTER_SUB = r21
.def ZERO = r22

;Move initial values to named registers
	mov A_LOW, r16	;Low byte of A
	mov A_HIGH, r17	;High byte of A
	mov B_LOW, r18	;Low byte of B
	mov B_HIGH, r19	;High byte of B
	ldi COUNTER_ADD, 0x01 ;Value to add to counter each time
	ldi ZERO, 0x00

;Subtract A from B
loop:
	sub A_LOW, B_LOW
	sbc A_HIGH, B_HIGH
	rjmp negative_reached
back:
	rjmp inc_counter
	rjmp loop

;Increase counter each time the loop iterates
inc_counter:
	add COUNTER_LOW, COUNTER_ADD
	adc COUNTER_HIGH, ZERO
	rjmp loop

negative_reached:
	brcc back
	add A_LOW, r18
	adc A_HIGH, r19

;Copy quotient and remained to data memory
copy_to_data:
	sts DIV0, COUNTER_LOW
	sts DIV1, COUNTER_HIGH
	sts MOD0, A_LOW
	sts MOD1, A_HIGH
	

	; End of program (do not change the next two lines)
stop:
	rjmp stop
	
; Do not move or modify any code below this line. You may add extra variables if needed.
; The .dseg directive indicates that the following directives should apply to data memory
.dseg 
.org 0x200 ; Start assembling at address 0x200 of data memory (addresses less than 0x200 refer to registers and ports)

DIV0:	.byte 1 ; Bits  7...0 of the quotient
DIV1:	.byte 1 ; Bits 15...8 of the quotient
MOD0:	.byte 1 ; Bits  7...0 of the remainder
MOD1:	.byte 1 ; Bits 15...8 of the remainder
