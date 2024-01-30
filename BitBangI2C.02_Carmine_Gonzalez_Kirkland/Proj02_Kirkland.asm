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
	call	#I2CStop
	call	#I2CReset
	jmp		Main
;--------------------------------- end of main ---------------------------------

;-------------------------------------------------------------------------------
; I2CStart:
;-------------------------------------------------------------------------------
I2CStart:
	bic.b	#BIT6, &P6OUT	; SDA Low

	mov.b	#0006Bh, R6		; 1101 0110b reversed from 0xEB Start bit + address 6B
	rla.w	R6				; one less byte being sent due to start condition
	; todo add read write bit

	swpb	R6
;	mov.b	#00055h, R7		; 01010101	Alternating clock. not quite correct for final thing
	mov.b	#00008h, R8		; full byte being sent

	call	#I2CDelay
	ret
	nop
;------------------------------- end of I2CStart -------------------------------

;-------------------------------------------------------------------------------
; I2CStop:
;-------------------------------------------------------------------------------
I2CStop:
	bic.b	#BIT0, &P1OUT	; SCL Low
	call	#DataDelay		; data delay
	bic.b	#BIT6, &P6OUT	; SDA Low
	call	#I2CDelay
	bis.b	#BIT0, &P1OUT	; SCL High
	call	#DataDelay		; data delay
	bis.b	#BIT6, &P6OUT	; SDA Low
	call	#I2CDelay
	ret
	nop
;------------------------------- end of I2CStart -------------------------------


;-------------------------------------------------------------------------------
; I2CTx:
;-------------------------------------------------------------------------------
I2CTx:

	bic.b	#BIT0, &P1OUT	; Clock to low

	call	#DataDelay		; data delay
	;call	#NopDelay		; data delay

	rla.w	R6				; SDA rotate transmitted bit into carry
	jc		SDA1			; output bit

SDA0:
	bic.b	#BIT6, &P6OUT
	jmp		TransmitDelay

SDA1:
	bis.b	#BIT6, &P6OUT

TransmitDelay:
	call	#I2CDelay
	bis.b	#BIT0, &P1OUT	; Clock to high
	call	#I2CDelay


	dec.b	R8				; Loop until byte is sent
	jnz		I2CTx

	ret
	nop
;--------------------------------- end of I2CTx --------------------------------

I2CReset:
	bis.b	#BIT0, &P1OUT
	bis.b	#BIT6, &P6OUT
	call	#I2CDelay
	call	#I2CDelay
	ret
	nop

;-------------------------------------------------------------------------------
; NopDelay:
;-------------------------------------------------------------------------------
NopDelay:
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	ret
	nop
;------------------------------- end of NopDelay -------------------------------

;-------------------------------------------------------------------------------
; Delay: delay for
;-------------------------------------------------------------------------------
I2CDelay:
	mov.w	#003EFh, R4				; Tuned for 1s Delay with 8 loops
SmallDelayLoop:
	dec.w	R4						; Loop through the small delay until zero, then restart if R5 is not zero. Otherwise return.
	jnz		SmallDelayLoop

	ret
	nop

;--------------------------------- end of delay --------------------------------

;-------------------------------------------------------------------------------
; Delay: delay for
;-------------------------------------------------------------------------------
DataDelay:
	mov.w	#00009h, R4				; Tuned for 1s Delay with 8 loops
	jmp		SmallDelayLoop
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
