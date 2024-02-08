;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
; 	EELE465
;	Written by: Zach Carmean, Lance Gonzalez, Grant Kirkland
;   Working: Grant Kirkland
;	Project 02 - Feb 2 2024
;
;	Summary:
;
;
;	Version Summary:
;   v01:
;   v02:
;	v03: Transmits byte of data with ack, sends another address
; 	v04: Switches to Compare interrupt for clock, finished I2C transmission
;	v05: Merged lances and zachs code. Working stop transmit and start code
;	v06: Merged zachs acknowledge code.
;
;	Ports:
;	    P3.6 - SCL
;	    P5.2 - SDA
;		P4.5 - Clock Active-Low Reset
;
;	Registers:
;	    R4	SDA
;	    R5	Clock Delay Loop
;	    R6	Remaining transmit bits
;		R7	Status Register
;			B0 - Clock
;
;	RTC:
;		Vin - 3V3
;		GND - GND
;		SCL - P3.6
;		SDA - P5.2
;		BAT - N/C
;		32K - N/C
;		SQW - N/C
;		RST - P4.5
; 		R7 	Outer Clock Loop
;
;	Todo:
;		*Acknowledge: pretty much everything. acknowledge is just wait a clock cycle currently.
;		*Fix clock timing to be standard i2c frequency
;		*Test data delay with clock. Might be able to do with analog discovery. Not sure if delay is long enough.
;		*Flowchart
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
; Init: Initialization of Ports 5.2, 3.6, and 4.5
;-------------------------------------------------------------------------------
Init:

    ; Configuring P4.5 /RST
        bis.b	#BIT5, &P4DIR	; Initializing P4.5 as output
        bic.b	#BIT5, &P4OUT	; Configuring off

	; Configuring P5.2 SDA
	    bis.b	#BIT2, &P5DIR	; Initializing P5.2 as output
	    bis.b	#BIT2, &P5OUT	; Configuring ON

    ; Configuring P3.6 SCL
        bis.b	#BIT6, &P3DIR	; Initializing P3.6 as output
        bis.b	#BIT6, &P3OUT	; Configuring ON

	; Configuring Timer B0 - 1.05 (measured 1.00) s = 1E-6 * 8 * 5 * 26250
		bis.w	#TBCLR, &TB0CTL			; Clear timers & dividers
		bis.w	#TBSSEL__SMCLK, &TB0CTL	; Set SMCLK as the source
		bis.w	#MC__UP, &TB0CTL		; Set mode as up
		bis.w	#CNTL_0, &TB0CTL		; 16-bit counter length
		mov.w	#26255, &TB0CCR0		; Setting Capture Compare Register 0
		;bis.w	#ID__2, &TB0CTL			; Set divider to 8
		;bis.w	#TBIDEX__5, &TB0EX0		; Set Expansion register divider to 5
		bic.w	#CCIFG, &TB0CCTL0		; Clear interrupt flag - Capture/Compare
;	bis.w	#CCIE, &TB0CCTL0		; Enable Capture/Compare interrupt for TB0

	; Initialize Used Registers
        mov.w	#0, R4
        mov.w	#0, R5
        mov.w	#0, R6
        mov.w	#0, R7
		bis.b	#BIT0, R7

		nop
		bis.w	#GIE, SR				; Enable maskable interrupts
		nop
	    bic.b	#LOCKLPM5, &PM5CTL0		; Disable High-z
;--------------------------------- end of init ---------------------------------

;-------------------------------------------------------------------------------
; Main: main subroutine
;-------------------------------------------------------------------------------
Main:
	bis.b	#BIT5, &P4OUT		; Disabling RTC reset

    call 	#I2CStart			; I2C Start Condition / load address into memory
	call	#Start_SCL

	call	#I2CTx				; I2C Transmit loaded bit
	call	#I2CAckRequest


	mov.b	#000ABh, R4
	swpb	R4
	mov.b	#00008h, R6

	call	#I2CTx				; I2C Transmit loaded bit
	call	#I2CDataLineInput
	call	#I2CAckRequest
	call	#I2CDataLineOutput

    call	#I2CStop		; I2C Stop Condition
	call	#Stop_SCL

    call	#I2CReset		; I2C Hold both lines high for a couple clock cycles for debugging

    jmp		Main
;--------------------------------- end of main ---------------------------------

;-------------------------------------------------------------------------------
; I2CStart:
;-------------------------------------------------------------------------------
I2CStart:
	bic.b	#BIT2, &P5OUT	; SDA Low

	mov.b	#00068h, R4		; 1101 000 reversed from 0xEB Start bit + address 6B
	rla.w	R4				; one less byte being sent due to start condition
	bic.b	#BIT0, R4		; Set readwrite bit

	swpb	R4
	mov.b	#00008h, R6		; full byte being sent

	call 	#DataDelay
	ret
	nop
;------------------------------- end of I2CStart -------------------------------

;-------------------------------------------------------------------------------
; Start_SCL:
;-------------------------------------------------------------------------------
Start_SCL:
        bic.w   #CCIFG, &TB0CCTL0
		bis.w	#CCIE, &TB0CCTL0		; Enable Capture/Compare interrupt for TB0

        ret
; --------------- END Start_SCL ------------------------------------------------
;-------------------------------------------------------------------------------
; I2CTx: Transmit data stored in R4.
;-------------------------------------------------------------------------------
I2CTx:
	bit.b	#BIT0, R7		; Test clock if zero, keep waiting for low
	jnz		I2CTx

	call	#DataDelay			; Delay for data

	rla.w	R4					; SDA rotate transmitted bit into carry
	jc		SDA1				; output bit

SDA0:
	bic.b	#BIT2, &P5OUT
	jmp		TransmitClockCycle

SDA1:
	bis.b	#BIT2, &P5OUT

TransmitClockCycle:
	bit.b	#BIT0, R7		; Test clock if zero, keep waiting for high
	jz		TransmitClockCycle

	dec.b	R6				; Loop until byte is sent
	jnz		I2CTx

TransmitEnd:
	bit.b	#BIT0, R7		; Test clock if zero, keep waiting for high
	jnz		TransmitEnd
	mov.b	#00008h, R6		; full byte being sent

	ret
	nop
;--------------------------------- end of I2CTx --------------------------------

;-------------------------------------------------------------------------------
; I2CDataLineInput:
;-------------------------------------------------------------------------------
I2CDataLineInput:
	;INIT P5.2 as input with pull up
    bic.b   #BIT2, &P5DIR
    bis.b   #BIT2, &P5REN
    bis.b   #BIT2, &P5OUT

	ret
	nop
;--------------------------- end of I2CDataLineInput ---------------------------

;-------------------------------------------------------------------------------
; I2CAckRequest:
;-------------------------------------------------------------------------------
I2CAckRequest:
;	bis.b	#BIT2, &P5OUT

AckWait1:
	bit.b	#BIT0, R7		; Test clock if zero, keep waiting for high
	jz		AckWait1

AckWait2:
	bit.b	#BIT0, R7		; Test clock if zero, keep waiting for high
	jnz		AckWait2
;	bic.b	#BIT2, &P5OUT
	ret
    nop

;----------------- END I2CAckReques Subroutine----------------------------------

;-------------------------------------------------------------------------------
; I2CDataLineOutput:
;-------------------------------------------------------------------------------
I2CDataLineOutput:
	;Re-INIT P5.2 as output
	bis.b	#BIT2, &P5DIR	; Initializing pin as output

    ret
    nop
;--------------------------- end of I2CDataLineOutput --------------------------

;-------------------------------------------------------------------------------
; I2CStop: Transmit stop condition for I2C
;-------------------------------------------------------------------------------
I2CStop:
	bit.b	#BIT0, R7		; Test clock if zero, keep waiting for high
	jz		I2CStop

StopHigh:
	call 	#DataDelay
	bis.b	#BIT2, &P5OUT
	call 	#DataDelay

	ret
	nop
;------------------------------- end of I2CStart -------------------------------

;-------------------------------------------------------------------------------
; Stop_SCL:
;-------------------------------------------------------------------------------
Stop_SCL:
        bic.w   #CCIE, &TB0CCTL0            ; disble CCR0
        bic.w   #CCIFG, &TB0CCTL0

		mov.w	#0, TB0R

        ret
; --------------- END Stop_SCL -------------------------------------------------

;-------------------------------------------------------------------------------
; I2CReset: Holds both lines high for a clock cycle for debugging
;-------------------------------------------------------------------------------
I2CReset:
	bis.b	#BIT2, &P5OUT
	bis.b	#BIT6, &P3OUT
	bis.b	#BIT0, R7
	call	#I2CClockDelay
	call	#I2CClockDelay
	ret
	nop
;--------------------------------- end of I2CTx --------------------------------

;-------------------------------------------------------------------------------
; I2CClockDelay: delay for clock pulses - not tuned todo
;-------------------------------------------------------------------------------
I2CClockDelay:
	mov.w	#0F3EFh, R5				; Tuned for 1s Delay with 8 loops
ClockDelayLoop:
	dec.w	R5						; Loop through the small delay until zero, then restart if R5 is not zero. Otherwise return.
	jnz		ClockDelayLoop

	ret
	nop

;--------------------------------- end of delay --------------------------------

;-------------------------------------------------------------------------------
; DataDelay: Very small delay for data
;-------------------------------------------------------------------------------
DataDelay:
	mov.w	#009EFh, R5
	mov.w 	#01h, R8
DataInner:
	dec.w	R5						; Loop through the small delay until zero, then restart if R5 is not zero. Otherwise return.
	jnz		DataInner

DataOuter:
	mov.w	#009EFh, R5
	dec.w 	R8
	jnz 	DataInner

	ret
	nop
;--------------------------------- end of delay --------------------------------

; ~~~~~~~~~~~~~~~~~~~~~~~~ INTERRUPT SERVICE ROUTINES ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;-------------------------------------------------------------------------------
; ISR_TB0_CCR1
;-------------------------------------------------------------------------------
ISR_TB0_CCR1:
        bic.w   #CCIFG, &TB0CCTL1
        reti
        nop
; --------------- END ISR_TB0_CCR1 ---------------------------------------------

;-------------------------------------------------------------------------------
; ISR_TB0_CCR0
;-------------------------------------------------------------------------------
ISR_TB0_CCR0:
        xor.b   #BIT6, &P3OUT
        xor.b	#BIT0, R7
        bic.w   #CCIFG, &TB0CCTL0
        reti
        nop
; --------------- END ISR_TB0_CCR0 ---------------------------------------------

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

			.sect   ".int43"
            .short  ISR_TB0_CCR0

            .sect   ".int42"
            .short  ISR_TB0_CCR1
