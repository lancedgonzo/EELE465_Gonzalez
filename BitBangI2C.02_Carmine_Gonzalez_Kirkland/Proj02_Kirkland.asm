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
;	R4	I2C Transmit Byte
;	R5	Delay loop count - # of times to run through maximum delay loop
;
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
	bic.b	#BIT0, &P1OUT	; Initializing LED2 as off

    ; Configuring LED2 - P6.6
	bic.b	#BIT6, &P6SEL0	; Setting pin as digital I/O
	bic.b	#BIT6, &P6SEL1
	bis.b	#BIT6, &P6DIR	; Initializing pin as output
	bic.b	#BIT6, &P6OUT	; Initializing LED2 as off

	mov.w	#0, R4			; Initialize R4 to 0
	mov.w	#0, R5			; Initialize R5 to 0

	; Configuring Timer B0 - 1.05 (measured 1.00) s = 1E-6 * 8 * 5 * 26250
	bis.w	#TBCLR, &TB0CTL			; Clear timers & dividers
	bis.w	#TBSSEL__SMCLK, &TB0CTL	; Set SMCLK as the source
	bis.w	#MC__UP, &TB0CTL		; Set mode as up
	bis.w	#ID__8, &TB0CTL			; Set divider to 8
	bis.w	#TBIDEX__5, &TB0EX0		; Set Expansion register divider to 5
	bis.w	#CNTL_0, &TB0CTL		; 16-bit counter length
	mov.w	#26255, &TB0CCR0		; Setting Capture Compare Register 0
	bic.w	#CCIFG, &TB0CCTL0		; Clear interrupt flag - Capture/Compare
	bis.w	#CCIE, &TB0CCTL0		; Enable Capture/Compare interrupt for TB0

	nop
	bis.w	#GIE, SR				; Enable maskable interrupts
	nop
	bic.b	#LOCKLPM5, &PM5CTL0		; Disable High-z

;--------------------------------- end of init ---------------------------------


;-------------------------------------------------------------------------------
; Main: main subroutine
;-------------------------------------------------------------------------------
Main:
	call 	#I2CStartTransmit
	bis.b	#BIT0, &P1OUT	; Initializing LED2 as on
	bis.b	#BIT6, &P6OUT	; Initializing LED2 as on
	mov.w	#00008h, R5
	call 	#Delay
	jmp		Main
;--------------------------------- end of main ---------------------------------

;-------------------------------------------------------------------------------
; Delay: delay for
;-------------------------------------------------------------------------------
Delay:
	mov.w	#0AAEFh, R4				; Tuned for 1s Delay with 8 loops
SmallDelay:
	dec.w	R4						; Loop through the small delay until zero, then restart if R5 is not zero. Otherwise return.
	jnz		SmallDelay

	dec.w	R5
	jnz		Delay

	ret
	nop

;--------------------------------- end of delay --------------------------------

;-------------------------------------------------------------------------------
; Main: main subroutine
;-------------------------------------------------------------------------------
Main:
	mov.w	#00008h, R5
	call 	#Delay
	call 	#FlashRed
	jmp		Main
;--------------------------------- end of main ---------------------------------

;-------------------------------------------------------------------------------
; I2CStartTransmit:
;-------------------------------------------------------------------------------
I2CStartTransmit:
StartCondition:
	bis.b	#BIT0, &P1OUT	; Initializing LED1 as on
	bic.b	#BIT6, &P6OUT	; Initializing LED2 as off

	mov.w	#00002h, R5
	call 	#Delay

	bic.b	#BIT0, &P1OUT	; Initializing LED1 as off
	bic.b	#BIT6, &P6OUT	; Initializing LED2 as off

	mov.w	#00002h, R5
	call 	#Delay

;--------------------------- end of I2CStartTransmit ---------------------------


;-------------------------------------------------------------------------------
; FlashRed: toggle led1
;-------------------------------------------------------------------------------
FlashRed:
	xor.b	#01h, P1OUT		; toggle LED1 then return
	ret
	nop
;------------------------------- end of FlashRed -------------------------------

;-----------------------START TimerB0_250ms-------------------------------------
TimerB0_250ms:
	xor.b	#BIT6, &P6OUT			; toggle LED1
	bic.w	#CCIFG, &TB0CCTL0		; Clear interrupt flag - Capture/Compare
	reti
;-----------------------END TimerB0_250ms---------------------------------------


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
            
            .sect	".int43"				; TB0CCR0
            .short	TimerB0_250ms


