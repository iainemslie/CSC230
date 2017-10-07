;Iain Emslie V00825434
;This program creates a pattern of flashing LEDs
;Uses and Arduino 2560 and Arduino Display kit 6 bit Blue LED Module Board 


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                        Constants and Definitions                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Special register definitions
.def XL = r26
.def XH = r27
.def YL = r28
.def YH = r29
.def ZL = r30
.def ZH = r31
.def INVERT = r24
.def COUNTER = r20

; Stack pointer and SREG registers (in data space)
.equ SPH = 0x5E
.equ SPL = 0x5D
.equ SREG = 0x5F

; Initial address (16-bit) for the stack pointer
.equ STACK_INIT = 0x21FF

; Port and data direction register definitions (taken from AVR Studio; note that m2560def.inc does not give the data space address of PORTB)
.equ DDRB = 0x24
.equ PORTB = 0x25
.equ DDRL = 0x10A
.equ PORTL = 0x10B


; Definitions of the special register addresses for timer 0 (in data space)
.equ GTCCR = 0x43
.equ OCR0A = 0x47
.equ OCR0B = 0x48
.equ TCCR0A = 0x44
.equ TCCR0B = 0x45
.equ TCNT0  = 0x46
.equ TIFR0  = 0x35
.equ TIMSK0 = 0x6E


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;						 Button Definitions									  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Definitions for the analog/digital converter (ADC)
.equ ADCSRA	= 0x7A ; Control and Status Register A
.equ ADCSRB	= 0x7B ; Control and Status Register B
.equ ADMUX	= 0x7C ; Multiplexer Register
.equ ADCL	= 0x78 ; Output register (high bits)
.equ ADCH	= 0x79 ; Output register (low bits)

; Definitions for button values from the ADC
; Comment out one set of values.
; Option A (v 1.1)
;.equ ADC_BTN_RIGHT = 0x032
;.equ ADC_BTN_UP = 0x0FA
;.equ ADC_BTN_DOWN = 0x1C2
;.equ ADC_BTN_LEFT = 0x28A
;.equ ADC_BTN_SELECT = 0x352
; Option B (v 1.0)
.equ ADC_BTN_RIGHT	= 0x032
.equ ADC_BTN_UP	= 0x0C3
.equ ADC_BTN_DOWN	= 0x17C
.equ ADC_BTN_LEFT	= 0x22B
.equ ADC_BTN_SELECT	= 0x316


.cseg
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                          Reset/Interrupt Vectors                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.org 0x0000 ; RESET vector
	jmp main_begin
	
	
; According to the datasheet, the interrupt vector for timer 0 overflow is located
; at 0x002e
.org 0x002e
	jmp TIMER0_OVERFLOW_ISR ; Questions: Would rjmp work here? Why do we need a jmp instead of putting the entire ISR here?
	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                               Main Program                                  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; According to the datasheet, the last interrupt vector has address 0x0072, so the first
; "unreserved" location is 0x0074
.org 0x0074
main_begin:

	;Set register 20 to zero
	ldi COUNTER, 0 

	; Initialize the stack
	ldi r16, high(STACK_INIT)
	sts SPH, r16
	ldi r16, low(STACK_INIT)
	sts SPL, r16
	
	; Set DDRB and DDRL
	ldi r16, 0xFF
	sts DDRL, r16
	sts DDRB, r16

	;SETUP INPUT BUTTONS
	call BUTTON_SETUP
	
	
	call TIMER0_SETUP ; Set up timer 0 control registers (function below)
	
	ldi r16, 0
	sts OVERFLOW_INTERRUPT_COUNTER, r16
	sts LED_STATE, r16
	
	sei ; Set the I flag in SREG to enable interrupt processing
	
	; Now enter an infinite loop which repeatedly
	; sets the LED based on the current value of LED_STATE.
rjmp main_loop
	
SET_COUNT_ZERO:
	ldi COUNTER, 0
	jmp return_point
	
main_loop:
	
	lds r16, LED_STATE
	; If the LED_STATE is 1, then set the LED to be lit
	cpi r16, 0
	brne main_loop_done


	;If r24 is set then the invert button has been pressed
	cpi INVERT, 1
	brne skip_inverted

	call SET_INVERTED_LED

	skip_inverted:

	;If invert has been pressed then skip normal function
	cpi INVERT, 1
	breq skip_normal

	call SET_LED

	skip_normal:


	cpi COUNTER, 20
	breq SET_COUNT_ZERO
	return_point:


	call BUTTON_FUNCTION

main_loop_done:
	rjmp main_loop


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;			BUTTON FUNCTION			;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BUTTON_FUNCTION:
	push r16
	push r22
	push r23

	; Set the ADSC bit to 1 in the ADCSRA register to start a conversion
	lds	r16, ADCSRA
	ori	r16, 0x40
	sts	ADCSRA, r16
	

	lds		r16, ADCSRA
	andi	r16, 0x40
	
	; Load the ADC result into the X pair (XH:XL). Note that XH and XL are defined above.
	lds	XL, ADCL
	lds	XH, ADCH

	; Store the threshold in r22:r23
	ldi	r22, low(ADC_BTN_SELECT)
	ldi	r23, high(ADC_BTN_SELECT)
	
	; Compare XH:XL with the threshold in r22:r23
	cp	XL, r22 ; Low byte
	cpc	XH, r23 ; High byte

	brsh NO_BUTTON_PRESSED

	; Store the threshold in r22:r23
	ldi	r22, low(ADC_BTN_RIGHT)
	ldi	r23, high(ADC_BTN_RIGHT)
	
	; Compare XH:XL with the threshold in r22:r23
	cp	XL, r22 ; Low byte
	cpc	XH, r23 ; High byte

	brlo RIGHT_BUTTON_PRESSED
	
	; Store the threshold in r22:r23
	ldi	r22, low(ADC_BTN_UP)
	ldi	r23, high(ADC_BTN_UP)
	
	; Compare XH:XL with the threshold in r22:r23
	cp	XL, r22 ; Low byte
	cpc	XH, r23 ; High byte	

	brlo UP_BUTTON_PRESSED

	; Store the threshold in r22:r23
	ldi	r22, low(ADC_BTN_DOWN)
	ldi	r23, high(ADC_BTN_DOWN)
	
	; Compare XH:XL with the threshold in r22:r23
	cp	XL, r22 ; Low byte
	cpc	XH, r23 ; High byte

	brlo DOWN_BUTTON_PRESSED
	
	; Store the threshold in r22:r23
	ldi	r22, low(ADC_BTN_LEFT)
	ldi	r23, high(ADC_BTN_LEFT)
	
	; Compare XH:XL with the threshold in r22:r23
	cp	XL, r22 ; Low byte
	cpc	XH, r23 ; High byte

	brlo LEFT_BUTTON_PRESSED

	; Store the threshold in r22:r23
	ldi	r22, low(ADC_BTN_SELECT)
	ldi	r23, high(ADC_BTN_SELECT)
	
	; Compare XH:XL with the threshold in r22:r23
	cp	XL, r22 ; Low byte
	cpc	XH, r23 ; High byte

	brlo SELECT_BUTTON_PRESSED
	
		
RIGHT_BUTTON_PRESSED:
	;Enable normal mode
	ldi INVERT, 0
	pop r23
	pop r22
	pop r16
	ret

UP_BUTTON_PRESSED:
	;change speed to 0.25
	ldi r16, 0x04
	sts	TCCR0B, r16
	pop r23
	pop r22
	pop r16
	ret

DOWN_BUTTON_PRESSED:
	;change speed back to 1
	ldi r16, 0x05
	sts	TCCR0B, r16
	pop r23
	pop r22
	pop r16
	ret

LEFT_BUTTON_PRESSED:
	;Enable inverted mode
	ldi INVERT, 1
	pop r23
	pop r22
	pop r16
	ret

SELECT_BUTTON_PRESSED:
	com r25
	cli
	PAUSE_LOOP:

	;call BUTTON_FUNCTION

	cpi r25, 0xFF
	breq PAUSE_LOOP

NO_BUTTON_PRESSED:
	pop r23
	pop r22
	pop r16
	ret



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;			BUTTON SETUP			;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Sets up the ADCSRA, ADCSRB and ADMUX for input from 5 buttons
BUTTON_SETUP:
	push r16
	; Set up the ADC
	
	; Set up ADCSRA (ADEN = 1, ADPS2:ADPS0 = 111 for divisor of 128)
	ldi	r16, 0x87
	sts	ADCSRA, r16
	
	; Set up ADCSRB (all bits 0)
	ldi	r16, 0x00
	sts	ADCSRB, r16
	
	; Set up ADMUX (MUX4:MUX0 = 00000, ADLAR = 0, REFS1:REFS0 = 1)
	ldi	r16, 0x40
	sts	ADMUX, r16
	
	pop r16
	ret


; TIMER0_SETUP()
; Set up the control registers for timer 0
; In this version, the timer is set up for overflow interrupt mode
; (which triggers an interrupt every time the timer's counter overflows
;  from 255 to 0)
TIMER0_SETUP:
	push r16
	
	; Control register A
	; We set all bits to 0, which enables "normal port operation" and no output-compare
	; mode for all of the bit fields in TCCR0A and also disables "waveform generation mode"
	ldi r16, 0x00
	sts TCCR0A, r16
	
	; Control register B
	; Select prescaler = clock/1024 and all other control bits 0 (see page 126 of the datasheet)
	; Question: How is a prescalar value of clock/256 set? How would the ISR need to change
	; in such a case?


	;This is set to 5 for one second intervals and 4 for .25 second intervals
	ldi r16, 0x05
	sts	TCCR0B, r16
	; Once TCCR0B is set, the timer will begin ticking
	
	; Interrupt mask register (to select which interrupts to enable)
	ldi r16, 0x01 ; Set bit 0 of TIMSK0 to enable overflow interrupt (all other bits 0)
	sts TIMSK0, r16
	
	; Interrupt flag register
	; Writing a 1 to bit 0 of this register clears any interrupt state that might
	; already exist (thereby resetting the interrupt state).
	ldi r16, 0x05
	sts TIFR0, r16
		
	
	pop r16
	ret



; TIMER0_OVERFLOW_ISR()
; This is not a regular function, but an interrupt handler, so there are no
; arguments or return value, and the RET instruction is not used. Instead,
; the "interrupt return" (RETI) instruction is used to end the ISR.
; Although it's not a regular function, we still have to follow normal
; function style for saving registers.
TIMER0_OVERFLOW_ISR:
	
	push r16
	; Since we pushed r16, we can now use it.
	; We need to push the contents of SREG (since we don't know whether the code
	; that was running before this ISR was using SREG for something). SREG isn't
	; a normal register, so to access its contents we have to go to data memory.
	; (Note that the address in data memory can be found via AVR Studio or the
	;  definition file. It is set via .equ at the top of this file)
	lds r16, SREG ; Load the value of SREG into r16
	push r16 ; Push SREG onto the stack
	push r17


	; Increment the value of OVERFLOW_INTERRUPT_COUNTER
	lds r16, OVERFLOW_INTERRUPT_COUNTER
	inc r16
	inc r16
	sts OVERFLOW_INTERRUPT_COUNTER, r16
	; Compare the value of the overflow counter to 61
	cpi r16, 61
	
	; If the value is less than 61, we're done
	brlo timer0_isr_done
	
	; If the counter equals 61, clear its value back to 0
	clr r16
	sts OVERFLOW_INTERRUPT_COUNTER, r16
	
	;Increment through each light by adding to counter
	inc COUNTER
	
	; Otherwise, 61 interrupts have occurred since the last
	; time we flipped the state, so load the LED_STATE value
	; and flip it

	lds r16, LED_STATE

	; We can flip 0 to 1 and 1 to 0 by using XOR
	ldi r17, 1
	eor r16, r17
	
	sts LED_STATE, r16
	
	
timer0_isr_done:
	
	pop r17
	; The next stack value is the value of SREG
	pop r16 ; Pop SREG into r16
	sts SREG, r16 ; Store r16 into SREG
	; Now pop the original saved r16 value
	pop r16

	reti ; Return from interrupt


; The function below was taken from delay_loop_functions.asm from Week 6
; SET_LED(r16: index)
; This function takes an argument in r16. The argument will
; be an index between 0 and 2, giving the LED to light:
;   r16 = 0 - Light the LED on Pin 52 (Port B Bit 1)
;	r16 = 2 - Light the LED on Pin 50 (PORT B Bit 3)
;	r16 = 4 - Light the LED on Pin 48 (Port L Bit 1)
;   r16 = 6 - Light the LED on Pin 46 (Port L Bit 3)
;	r16 = 8 - Light the LED on Pin 44 (Port L Bit 5)
;   r16 = 10 - Light the LED on Pin 42 (Port L Bit 7)
SET_LED:
	; This function uses r16, and even though r16 is the argument value,
	; we should save it to memory (since maybe the caller wants to continue
	; using it when the function ends).
	push r16
	
	; A 3-case if-statement for the different index values
	; (Try re-implementing this with an array instead of a cascading if-else)
	;Forwards
	cpi COUNTER, 0
	breq SET_LED_idx0
	cpi COUNTER, 2
	breq SET_LED_idx1
	cpi COUNTER, 4
	breq SET_LED_idx2
	cpi COUNTER, 6
	breq SET_LED_idx3
	cpi COUNTER, 8
	breq set_4
	cpi COUNTER, 10
	breq set_5

	;Backwards
	cpi COUNTER, 12
	breq SET_LED_idx4
	cpi COUNTER, 14
	breq SET_LED_idx3
	cpi COUNTER, 16
	breq SET_LED_idx2
	cpi COUNTER, 18
	breq SET_LED_idx1
	rjmp SET_LED_done

;Workaround for out of bounds problem
set_4:
	jmp SET_LED_idx4
set_5:
	jmp SET_LED_idx5

SET_LED_idx0:
	lds r16, PORTB
	lds r16, 0x00
	ori r16, 0x02
	sts PORTB, r16
	rjmp SET_LED_done
SET_LED_idx1:
	lds r16, PORTL
	lds r16, 0x00
	sts PORTL, r16
	lds r16, PORTB
	lds r16, 0x00
	ori r16, 0x08
	sts PORTB, r16
	rjmp SET_LED_done
SET_LED_idx2:
	lds r16, PORTB
	lds r16, 0x00
	lds r16, 0x02
	sts PORTB, r16
	lds r16, PORTL
	lds r16, 0x00
	ori r16, 0x03
	sts PORTL, r16
	rjmp SET_LED_done
SET_LED_idx3:
	lds r16, PORTB
	lds r16, 0x00
	sts PORTB, r16
	lds r16, PORTL
	lds r16, 0x00
	ori r16, 0x08
	sts PORTL, r16
	rjmp SET_LED_done
SET_LED_idx4:
	lds r16, PORTB
	lds r16, 0x00
	sts PORTB, r16
	lds r16, PORTL
	lds r16, 0x00
	ori r16, 0x20
	sts PORTL, r16
	rjmp SET_LED_done
SET_LED_idx5:
	lds r16, PORTB
	lds r16, 0x00
	sts PORTB, r16	
	lds r16, PORTL
	lds r16, 0x00
	ori r16, 0x80
	sts PORTL, r16


SET_LED_done:	
	; Load the saved value of r16 and return	
	pop r16
	ret


;;;;;;;;;;;;;;;;;;;;
;	   INVERSE	   ;
;;;;;;;;;;;;;;;;;;;;
SET_INVERTED_LED:
	; This function uses r16, and even though r16 is the argument value,
	; we should save it to memory (since maybe the caller wants to continue
	; using it when the function ends).
	push r16

	cpi COUNTER, 0
	breq SET_INVERTED_LED_idx0
	cpi COUNTER, 2
	breq SET_INVERTED_LED_idx1
	cpi COUNTER, 4
	breq SET_INVERTED_LED_idx2
	cpi COUNTER, 6
	breq SET_INVERTED_LED_idx3
	cpi COUNTER, 8
	breq SET_INVERTED_LED_idx4
	cpi COUNTER, 10
	breq SET_INVERTED_LED_idx5
	;Backwards
	cpi COUNTER, 12
	breq SET_INVERTED_LED_idx4
	cpi COUNTER, 14
	breq SET_INVERTED_LED_idx3
	cpi COUNTER, 16
	breq SET_INVERTED_LED_idx2
	cpi COUNTER, 18
	breq SET_INVERTED_LED_idx1
	rjmp SET_INVERTED_LED_done

SET_INVERTED_LED_idx0:
	ldi	r16, 0xF9
	sts PORTB, r16
	ldi r16, 0xFF
	sts PORTL, r16
	rjmp SET_LED_done
SET_INVERTED_LED_idx1:
	ldi r16, 0x00
	sts PORTB, r16
	ldi	r16, 0xF7
	sts PORTB, r16
	ldi r16, 0xFF
	sts PORTL, r16
	rjmp SET_LED_done
SET_INVERTED_LED_idx2:
	ldi r16, 0xFF
	sts PORTB, r16
	ldi r16, 0xF9
	sts PORTL, r16
	rjmp SET_LED_done
SET_INVERTED_LED_idx3:
	ldi	r16, 0xFF
	sts PORTB, r16
	ldi r16, 0xF7
	sts PORTL, r16
	rjmp SET_LED_done
SET_INVERTED_LED_idx4:
	ldi	r16, 0xFF
	sts PORTB, r16
	ldi r16, 0xDF
	sts PORTL, r16
	rjmp SET_LED_done
SET_INVERTED_LED_idx5:	
	ldi	r16, 0xFF
	sts PORTB, r16
	ldi r16, 0x7F
	sts PORTL, r16
	rjmp SET_LED_done
SET_INVERTED_LED_done:	
	; Load the saved value of r16 and return	
	pop r16
	ret
	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                               Data Section                                  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.dseg
.org 0x200
LED_STATE: .byte 1 ; The current state of the LED (1 = on, 0 = off)

OVERFLOW_INTERRUPT_COUNTER: .byte 1 ; Counter for the number of times the overflow interrupt has been triggered.
