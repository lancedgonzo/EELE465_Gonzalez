;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
; 	EELE465
;	Written by: Lance Gonzalez
;	Project 02 - Jan 25 2024
;
;	Summary:
;	Project blinks two LEDs using both delays and interrupts
;
;	Version Summary:
;
;
;	Interrupts:
;	Timer B0 - Set for 1s
;
;	Ports:
;	P3.6 - SCL
;	P5.2 - SDA
;
;	Registers:
;	R4	Small Delay loop
;	R5	Delay loop count - # of times to run through maximum delay loop
;	R6	SDA
;	R7	SCL
;	R8
;-------------------------------------------------------------------------------
            .cdecls C,LIST,"msp430.h"       ; Include device header file
            
;-------------------------------------------------------------------------------
            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.
;-------------------------------------------------------------------------------
            .text                           ; Assemble into program memory.
            .retain                         ; Override ELF conditional linking
                                            ; and retain current section.
            .retainrefs                     ; And retain any sections that have
                                            ; references to current section.

;-------------------------------------------------------------------------------
RESET       mov.w   #__STACK_END,SP         ; Initialize stackpointer
StopWDT     mov.w   #WDTPW|WDTHOLD,&WDTCTL  ; Stop watchdog timer

;-------------------------------------------------------------------------------
; Init: Initialization LED 1 and 2
;-------------------------------------------------------------------------------
Init:

	; Configuring LED1 - P1.0
	bic.b	#BIT0, &P1SEL0	; Setting pin as digital I/O
	bic.b	#BIT0, &P1SEL1
	bis.b	#BIT0, &P1DIR	; Initializing pin as output
	bis.b	#BIT0, &P1OUT	; Initializing LED1 as on

    ; Configuring LED2 - P6.6
	bic.b	#BIT6, &P6SEL0	; Setting pin as digital I/O
	bic.b	#BIT6, &P6SEL1
	bis.b	#BIT6, &P6DIR	; Initializing pin as output
	bis.b	#BIT6, &P6OUT	; Initializing LED2 as on

	mov.w	#0, R4			; Initialize R4 to 0
	mov.w	#0, R5			; Initialize R5 to 0
	mov.w	#0, R6			; Initialize R6 to 0
	mov.w	#0, R7			; Initialize R7 to 0
	mov.w	#0, R8			; Initialize R8 to 0

	nop
	bic.b	#LOCKLPM5, &PM5CTL0		; Disable High-z

;--------------------------------- end of init ---------------------------------


;-------------------------------------------------------------------------------
; Main: main subroutine
;-------------------------------------------------------------------------------
Main:
	call 	#I2CStart
	call	#I2CTx

	jmp		Main
;--------------------------------- end of main ---------------------------------

;-------------------------------------------------------------------------------
; I2CStart:
;-------------------------------------------------------------------------------
I2CStart:
	mov.b	#000D6h, R6		; 1101 0110b reversed from 0xEB Start bit + address 6B
	mov.b	#00055h, R7		; 01010101	Alternating clock. not quite correct for final thing
	mov.b	#00008h, R8		; full byte being sent

	ret
	nop
;------------------------------- end of I2CStart -------------------------------


;-------------------------------------------------------------------------------
; I2CTx:
;-------------------------------------------------------------------------------
I2CTx:
	rra.w	R6				; If clock to be sent was 1, set LED to high, otherwise set LED to low then go to SDA
	jc		SCL1
SCL0:
	bic.b	#BIT6, &P6OUT
	jmp		SDAOutput
SCL1:
	bis.b	#BIT6, &P6OUT

SDAOutput:
	rra.w	R7
	jc	SDA1				; If data to be sent was 1, set LED to high, otherwise set LED to low then go to delay
SDA0:
	bic.b	#BIT0, &P1OUT
	jmp		TransmitDelay
SDA1:
	bis.b	#BIT0, &P1OUT

TransmitDelay:
	call	#LargeDelay

	dec.b	R8				; Loop until byte is sent
	jnz		I2CTx

	ret
	nop
;--------------------------------- end of I2CTx --------------------------------

;-------------------------------------------------------------------------------
; Delay: delay for
;-------------------------------------------------------------------------------
LargeDelay:
	mov.b	#00003h, R5
SmallDelay:
	mov.w	#0AAEFh, R4				; Tuned for 1s Delay with 8 loops
SmallDelayLoop:
	dec.w	R4						; Loop through the small delay until zero, then restart if R5 is not zero. Otherwise return.
	jnz		SmallDelayLoop

	dec.w	R5
	jnz		SmallDelay

	ret
	nop

;--------------------------------- end of delay --------------------------------


;-------------------------------------------------------------------------------
; Stack Pointer definition
;-------------------------------------------------------------------------------
            .global __STACK_END
            .sect   .stack
            
;-------------------------------------------------------------------------------
; Interrupt Vectors
;-------------------------------------------------------------------------------
            .sect   ".reset"                ; MSP430 RESET Vector
            .short  RESET
