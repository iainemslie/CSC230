
.include "m2560def.inc"

.include "lcd_function_defs.inc"

; Definitions for button values from the ADC
; Some boards may use the values in option B
; The code below used less than comparisons so option A should work for both
; Option A (v 1.1)
;.equ ADC_BTN_RIGHT = 0x032
;.equ ADC_BTN_UP = 0x0FA
;.equ ADC_BTN_DOWN = 0x1C2
;.equ ADC_BTN_LEFT = 0x28A
;.equ ADC_BTN_SELECT = 0x352
; Option B (v 1.0)
.equ ADC_BTN_RIGHT = 0x032
.equ ADC_BTN_UP = 0x0C3
.equ ADC_BTN_DOWN = 0x17C
.equ ADC_BTN_LEFT = 0x22B
.equ ADC_BTN_SELECT = 0x316

; Initial address (16-bit) for the stack pointer
.equ STACK_INIT = 0x21FF

.equ SPH_DATASPACE = 0x5E
.equ SPL_DATASPACE = 0x5D


.cseg
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                          Reset/Interrupt Vectors                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.org 0x0000 ; RESET vector
	jmp main_begin

; The interrupt vector for timer 2 overflow is 0x1e
.org 0x001e
	jmp TIMER2_OVERFLOW_ISR
	
	
; Add interrupt handlers for timer interrupts here. See Section 14 (page 101) of the datasheet for addresses.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                               Main Program                                  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; According to the datasheet, the last interrupt vector has address 0x0070, so the first
; "unreserved" location is 0x0072
.org 0x0072
main_begin:

	; Initialize the stack
	; Notice that we use "SPH_DATASPACE" instead of just "SPH" for our .def
	; since m2560def.inc defines a different value for SPH which is not compatible
	; with STS.
	ldi r16, high(STACK_INIT)
	sts SPH_DATASPACE, r16
	ldi r16, low(STACK_INIT)
	sts SPL_DATASPACE, r16

	;Initialize the tenths, seconds, minutes and add to zero
	call RESET_VALUES
	;Set the values for the lap tenths, seconds and minutes to zero
	call RESET_CURRENT_LAPS
	; Initialize the LCD
	call lcd_init
	;Setup timer2
	call TIMER2_SETUP
	;Clear row 0 of the LCD
	call CLEAR_LCD_ROW_0
	;Clear row 1 of the LCD
	call UNSET_LAPS
	;Set initial values of the LCD
	call SET_LCD
	;Set up the buttons 
	call BUTTON_SETUP

	;sei ;Set to sei to begin with timer running
	cli ;Set to cli to begin with timer stopped
main_loop:
	call SET_LCD

	call BUTTON_FUNCTION

	rjmp main_loop

stop:
	rjmp stop
		
SET_LCD:
	push r16
	push YL
	push YH

	; Load the base address of the LINE_ONE array
	ldi YL, low(LINE_ONE)
	ldi YH, high(LINE_ONE)

	;Write to the top line time follows by the values for each time index	
	ldi r16, 'T'
	st Y+, r16
	ldi r16, 'i'
	st Y+, r16
	ldi r16, 'm'
	st Y+, r16
	ldi r16, 'e'
	st Y+, r16
	ldi r16, ':'
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	lds r16, MINUTES_HIGH
	call GET_DIGIT
	st Y+, r16
	lds r16, MINUTES_LOW
	call GET_DIGIT
	st Y+, r16
	ldi r16, ':'
	st Y+, r16
	lds r16, SECONDS_HIGH
	call GET_DIGIT
	st Y+, r16
	lds r16, SECONDS_LOW
	call GET_DIGIT
	st Y+, r16
	ldi r16, '.'
	st Y+, r16
	lds r16, TENTHS
	call GET_DIGIT
	st Y+, r16
	

	; Null terminator
	ldi r16, 0
	st Y+, r16
	
	; Set up the LCD to display starting on row 0, column 0
	ldi r16, 0 ; Row number
	push r16
	ldi r16, 0 ; Column number
	push r16
	call lcd_gotoxy
	pop r16
	pop r16
	
	; Display the string
	ldi r16, high(LINE_ONE)
	push r16
	ldi r16, low(LINE_ONE)
	push r16
	call lcd_puts
	pop r16
	pop r16

	pop YH
	pop YL
	pop r16
	ret

CLEAR_LCD_ROW_0:
	push r16
	push YL
	push YH

	; Load the base address of the LINE_ONE array
	ldi YL, low(LINE_ONE)
	ldi YH, high(LINE_ONE)

	;Write to the top line time follows by the values for each time index	
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16


	; Null terminator
	ldi r16, 0
	st Y+, r16
	
	; Set up the LCD to display starting on row 0, column 0
	ldi r16, 0 ; Row number
	push r16
	ldi r16, 0 ; Column number
	push r16
	call lcd_gotoxy
	pop r16
	pop r16
	
	; Display the string
	ldi r16, high(LINE_ONE)
	push r16
	ldi r16, low(LINE_ONE)
	push r16
	call lcd_puts
	pop r16
	pop r16

	pop YH
	pop YL
	pop r16
	ret

;Displays the lap times to the LCD
SET_LAP:
	push r16
	push YL
	push YH

	; Load the base address of the LINE_ONE array
	ldi YL, low(LINE_TWO)
	ldi YH, high(LINE_TWO)

	;Write to the top line time follows by the values for each time index	
	lds r16, LAST_LAP_START_MINUTES_HIGH
	call GET_DIGIT
	st Y+, r16
	lds r16, LAST_LAP_START_MINUTES_LOW
	call GET_DIGIT
	st Y+, r16
	ldi r16, ':'
	st Y+, r16
	lds r16, LAST_LAP_START_SECONDS_HIGH
	call GET_DIGIT
	st Y+, r16
	lds r16, LAST_LAP_START_SECONDS_LOW
	call GET_DIGIT
	st Y+, r16
	ldi r16, '.'
	st Y+, r16
	lds r16, LAST_LAP_START_TENTHS
	call GET_DIGIT
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	lds r16, LAST_LAP_END_MINUTES_HIGH
	call GET_DIGIT
	st Y+, r16
	lds r16, LAST_LAP_END_MINUTES_LOW
	call GET_DIGIT
	st Y+, r16
	ldi r16, ':'
	st Y+, r16
	lds r16, LAST_LAP_END_SECONDS_HIGH
	call GET_DIGIT
	st Y+, r16
	lds r16, LAST_LAP_END_SECONDS_LOW
	call GET_DIGIT
	st Y+, r16
	ldi r16, '.'
	st Y+, r16
	lds r16, LAST_LAP_END_TENTHS
	call GET_DIGIT
	st Y+, r16

	; Null terminator
	ldi r16, 0
	st Y+, r16
	
	; Set up the LCD to display starting on row 0, column 0
	ldi r16, 1 ; Row number
	push r16
	ldi r16, 0 ; Column number
	push r16
	call lcd_gotoxy
	pop r16
	pop r16
	
	; Display the string
	ldi r16, high(LINE_TWO)
	push r16
	ldi r16, low(LINE_TWO)
	push r16
	call lcd_puts
	pop r16
	pop r16

	pop YH
	pop YL
	pop r16
	ret

;Displays a blank line on the second row of the LCD
UNSET_LAPS:
	push r16
	push YL
	push YH

	; Load the base address of the LINE_ONE array
	ldi YL, low(LINE_TWO)
	ldi YH, high(LINE_TWO)

	;Write to the top line time follows by the values for each time index	
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16
	ldi r16, ' '
	st Y+, r16

	; Null terminator
	ldi r16, 0
	st Y, r16
	
	; Set up the LCD to display starting on row 0, column 0
	ldi r16, 1 ; Row number
	push r16
	ldi r16, 0 ; Column number
	push r16
	call lcd_gotoxy
	pop r16
	pop r16
	
	; Display the string
	ldi r16, high(LINE_TWO)
	push r16
	ldi r16, low(LINE_TWO)
	push r16
	call lcd_puts
	pop r16
	pop r16

	pop YH
	pop YL
	pop r16
	ret


SET_LAST_LAP_START:
	push r16
	
	;Load the values from CURRENT LAPS and write to LAST LAP
	lds r16, LAST_LAP_END_TENTHS
	sts LAST_LAP_START_TENTHS, r16

	lds r16, LAST_LAP_END_SECONDS_LOW
	sts LAST_LAP_START_SECONDS_LOW, r16

	lds r16, LAST_LAP_END_SECONDS_HIGH
	sts LAST_LAP_START_SECONDS_HIGH, r16

	lds r16, LAST_LAP_END_MINUTES_LOW
	sts LAST_LAP_START_MINUTES_LOW, r16

	lds r16, LAST_LAP_END_MINUTES_HIGH
	sts LAST_LAP_START_MINUTES_HIGH, r16

	pop r16
	ret

SET_LAST_LAP_END:
	push r16

	lds r16, TENTHS
	sts LAST_LAP_END_TENTHS, r16

	lds r16, SECONDS_LOW
	sts LAST_LAP_END_SECONDS_LOW, r16

	lds r16, SECONDS_HIGH
	sts LAST_LAP_END_SECONDS_HIGH, r16

	lds r16, MINUTES_LOW
	sts LAST_LAP_END_MINUTES_LOW, r16

	lds r16, MINUTES_HIGH
	sts LAST_LAP_END_MINUTES_HIGH, r16
	
	pop r16
	ret


; GET_DIGIT( d: r16 )
; Given a value d in the range 0 - 9 (inclusive), return the ASCII character
; code for d. This function will produce undefined results if d is not in the
; required range.
; The return value (a character code) is stored back in r16
GET_DIGIT:
	push r17
	
	; The character '0' has ASCII value 48, and the character codes
	; for the other digits follow '0' consecutively, so we can obtain
	; the character code for an arbitrary single digit by simply
	; adding 48 (or just using the constant '0') to the digit.
	ldi r17, '0' ; Could also write "ldi r17, 48"
	add r16, r17
	
	pop r17
	ret	

BUSY_WAIT_FUNCTION:
	push r30
	push r31
	ldi r31, 0xFF
	ldi r30, 0xFF

busy_wait:
	sbiw r30, 1
	cpi r30, 0
	brne busy_wait

	pop r31
	pop r30

	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;						  		BUTTON FUNCTION	   			  			      ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BUTTON_FUNCTION:
	push r16

	; Set the ADSC bit to 1 in the ADCSRA register to start a conversion
	lds	r16, ADCSRA
	ori	r16, 0x40
	sts	ADCSRA, r16
	

	lds		r16, ADCSRA
	andi	r16, 0x40
	;brne	main_loop
	
	; Load the ADC result into the X pair (XH:XL). Note that XH and XL are defined above.
	lds	XL, ADCL
	lds	XH, ADCH

	; Store the threshold in r21:r20
	ldi	r22, low(ADC_BTN_RIGHT)
	ldi	r23, high(ADC_BTN_RIGHT)
	
	; Compare XH:XL with the threshold in r21:r20
	cp	XL, r22 ; Low byte
	cpc	XH, r23 ; High byte

	brlo RIGHT_BUTTON_PRESSED
	
	; Store the threshold in r21:r20
	ldi	r22, low(ADC_BTN_UP)
	ldi	r23, high(ADC_BTN_UP)
	
	; Compare XH:XL with the threshold in r21:r20
	cp	XL, r22 ; Low byte
	cpc	XH, r23 ; High byte	

	brlo UP_BUTTON_PRESSED

	; Store the threshold in r21:r20
	ldi	r22, low(ADC_BTN_DOWN)
	ldi	r23, high(ADC_BTN_DOWN)
	
	; Compare XH:XL with the threshold in r21:r20
	cp	XL, r22 ; Low byte
	cpc	XH, r23 ; High byte

	brlo DOWN_BUTTON_PRESSED
	
	; Store the threshold in r21:r20
	ldi	r22, low(ADC_BTN_LEFT)
	ldi	r23, high(ADC_BTN_LEFT)
	
	; Compare XH:XL with the threshold in r21:r20
	cp	XL, r22 ; Low byte
	cpc	XH, r23 ; High byte

	brlo LEFT_BUTTON_PRESSED

	; Store the threshold in r21:r20
	ldi	r22, low(ADC_BTN_SELECT)
	ldi	r23, high(ADC_BTN_SELECT)
	
	; Compare XH:XL with the threshold in r21:r20
	cp	XL, r22 ; Low byte
	cpc	XH, r23 ; High byte

	brlo SELECT_BUTTON_PRESSED

	;brsh main_loop ;if the ADC value was above the threshold, no button was pressed (so try again)

	pop r16
	ret

RIGHT_BUTTON_PRESSED:
	pop r16
	ret

UP_BUTTON_PRESSED:
	;call RESET_CURRENT_LAPS
	call SET_LAST_LAP_START
	call SET_LAST_LAP_END
	call SET_LAP
	pop r16
	ret


DOWN_BUTTON_PRESSED:
	call UNSET_LAPS
	call RESET_CURRENT_LAPS
	pop r16
	ret

LEFT_BUTTON_PRESSED:
	;Clear timer to zero
	call RESET_VALUES
	pop r16
	ret

SELECT_BUTTON_PRESSED:
	push r17


	lds r17, PAUSE_FLAG
	cpi r17, 0 ;If pause is off then set it to be on
	breq set_pause
	cpi r17, 1	;If pause is on then set it to be off
	breq unset_pause

	return_pause:
	;Fix button problem by busywaiting after select is pressed
	call BUSY_WAIT_FUNCTION	
	call BUSY_WAIT_FUNCTION	
	call BUSY_WAIT_FUNCTION	
	call BUSY_WAIT_FUNCTION		
	pop r17
	pop r16
	ret

set_pause:
	cli
	ldi r17, 1
	sts PAUSE_FLAG, r17
	rjmp return_pause

unset_pause:
	sei
	ldi r17, 0
	sts PAUSE_FLAG, r17
	rjmp return_pause

	
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;						  		TIMER/ISR						  			  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; TIMER2_SETUP()
; Set up the control registers for timer 2.
TIMER2_SETUP:
	push r16	
	; Control register A
	; We set all bits to 0, which enables "normal port operation" and no output-compare
	; mode for all of the bit fields in TCCR0A and also disables "waveform generation mode"
	ldi r16, 0x00
	sts TCCR2A, r16
	
	; Control register B
	; Select prescaler = clock/64 and all other control bits 0 (see page 126 of the datasheet)
	ldi r16, 0x07 ;Prescaler value of 1024
	sts	TCCR2B, r16
	
	; Interrupt mask register (to select which interrupts to enable)
	ldi r16, 0x01 ; Set bit 0 of TIMSK0 to enable overflow interrupt (all other bits 0)
	sts TIMSK2, r16
	
	; Interrupt flag register
	; Writing a 1 to bit 0 of this register clears any interrupt state that might
	; already exist (thereby resetting the interrupt state).
	ldi r16, 0x01
	sts TIFR2, r16

	pop r16
	ret


; TIMER2_OVERFLOW_ISR()
; This ISR increments the OVERFLOW_INTERRUPT_COUNTER variable
; every time it's called and, after 244 interrupts have occurred,
; flips the value of the LED on pin 52 (Port B bit 1).
TIMER2_OVERFLOW_ISR:
	
	push r16
	lds r16, SREG ; Load the value of SREG into r16
	push r16 ; Push SREG onto the stack
	push r17
	push r18
	push r19
	
	; Increment the value of OVERFLOW_INTERRUPT_COUNTER
	lds r16, OVERFLOW_INTERRUPT_COUNTER
	inc r16
	; Change this value and the Prescaler to adjust the timing
	cpi r16, 6	;Set to six as 1/10th of 61
	brne timer2_isr_done
	
	call SET_TENTHS

	clr r16 ; Set the counter back to 0

timer2_isr_done:

	; Store the overflow counter back to memory
	sts OVERFLOW_INTERRUPT_COUNTER, r16
	
	pop r19
	pop r18
	pop r17
	; The next stack value is the value of SREG
	pop r16 ; Pop SREG into r16
	sts SREG, r16 ; Store r16 into SREG
	; Now pop the original saved r16 value
	pop r16

	reti ; Return from interrupt

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;		SET VALUES OF ADDRESSES IN MEMORY CORRESPONDING TO TIMER VALUES		  ;					  			  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SET_TENTHS:
	push r16
	push r19

	lds r19, ONE
	lds r16, TENTHS
	add r16, r19
	sts TENTHS, r16

	cpi r16, 10
	breq SET_SECONDS_LOW

	pop r19
	pop r16
	ret

SET_SECONDS_LOW:
	clr r16
	sts TENTHS, r16

	lds r19, ONE
	lds r16, SECONDS_LOW
	add r16, r19
	sts SECONDS_LOW, r16

	cpi r16, 10
	breq SET_SECONDS_HIGH

	pop r19
	pop r16
	ret

SET_SECONDS_HIGH:
	clr r16
	sts SECONDS_LOW, r16

	lds r19, ONE
	lds r16, SECONDS_HIGH
	add r16, r19
	sts SECONDS_HIGH, r16

	cpi r16, 6
	breq SET_MINUTES_LOW

	pop r19
	pop r16
	ret

SET_MINUTES_LOW:
	clr r16
	sts SECONDS_HIGH, r16

	lds r19, ONE
	lds r16, MINUTES_LOW
	add r16, r19
	sts MINUTES_LOW, r16

	cpi r16, 10
	breq SET_MINUTES_HIGH

	pop r19
	pop r16
	ret

SET_MINUTES_HIGH:
	clr r16
	sts MINUTES_LOW, r16

	lds r19, ONE
	lds r16, MINUTES_HIGH
	add r16, r19
	sts MINUTES_HIGH, r16

	cpi r16, 10
	breq GO_TO_RESET

	pop r19
	pop r16
	ret

GO_TO_RESET:
	call RESET_VALUES
	pop r19
	pop r16
	ret

;Resets the values of the timer to zero when called
RESET_VALUES:
	push r16
	;Set values to zero for reset
	ldi r16, 1
	sts ONE, r16

	clr r16
	sts TENTHS, r16
	sts SECONDS_LOW, r16
	sts SECONDS_HIGH, r16
	sts MINUTES_LOW, r16
	sts MINUTES_HIGH, r16

	sts PAUSE_FLAG, r16
	pop r16
	ret

;Resets the values of the lap counter to zero 
RESET_CURRENT_LAPS:
	push r16
	;Set values to zero for reset

	clr r16
	sts CURRENT_LAP_START_TENTHS, r16
	sts CURRENT_LAP_START_SECONDS_LOW, r16
	sts CURRENT_LAP_START_SECONDS_HIGH, r16
	sts CURRENT_LAP_START_MINUTES_LOW, r16
	sts CURRENT_LAP_START_MINUTES_HIGH, r16
	;Set the lap flag to be zero
	sts LAP_FLAG, r16

	pop r16
	ret
	
	
; Include LCD library code
.include "lcd_function_code.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                               Data Section                                  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.dseg
; Note that no .org 0x200 statement should be present
; Put variables and data arrays here...
OVERFLOW_INTERRUPT_COUNTER: .byte 1 ; Counter for the number of times the overflow interrupt has been triggered.
PAUSE_FLAG: .byte 1
LAP_FLAG: .byte 1
IGNORE_BUTTON: .byte 1

LINE_ONE: .byte 100	
TENTHS: .byte 1
SECONDS_LOW: .byte 1
SECONDS_HIGH: .byte 1
MINUTES_LOW: .byte 1
MINUTES_HIGH: .byte 1
ONE: .byte 1

LINE_TWO: .byte 100
LAST_LAP_START_TENTHS: .byte 1
LAST_LAP_START_SECONDS_LOW: .byte 1
LAST_LAP_START_SECONDS_HIGH: .byte 1
LAST_LAP_START_MINUTES_LOW: .byte 1
LAST_LAP_START_MINUTES_HIGH: .byte 1

LAST_LAP_END_TENTHS: .byte 1
LAST_LAP_END_SECONDS_LOW: .byte 1
LAST_LAP_END_SECONDS_HIGH: .byte 1
LAST_LAP_END_MINUTES_LOW: .byte 1
LAST_LAP_END_MINUTES_HIGH: .byte 1

CURRENT_LAP_START_TENTHS: .byte 1
CURRENT_LAP_START_SECONDS_LOW: .byte 1
CURRENT_LAP_START_SECONDS_HIGH: .byte 1
CURRENT_LAP_START_MINUTES_LOW: .byte 1
CURRENT_LAP_START_MINUTES_HIGH: .byte 1



