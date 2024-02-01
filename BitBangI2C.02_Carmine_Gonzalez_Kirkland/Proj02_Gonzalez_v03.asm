;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
; 	EELE465
;	Written by: Zach Carmean, Lance Gonzalez, Grant Kirkland
;   Working: Lance Gonzalez
;	Project 02 - Feb 2 2024
;
;	Summary:
;	    
;
;	Version Summary:
;   v01: 
;   v02:
;	v03: Transmits byte of data with ack, sends another address
;
;	Ports:
;	    P3.6 - SCL
;	    P5.2 - SDA
;
;	Registers:
;	    R4	SDA
;	    R5	Clock Delay Loop
;	    R6	Remaining transmit bits
;
;	Todo:
;		Acknowledge: pretty much everything. acknowledge is just wait a clock cycle currently.
;		Fix clock timing to be standard i2c frequency
;		Test data delay with clock. Might be able to do with analog discovery. Not sure if delay is long enough.
;		Flowchart
;		Update to ports 3.6 / 5.2
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

	; Configuring P5.2 SDA
	    bis.b	#BIT2, &P5DIR	; Initializing P5.2 as output
	    bis.b	#BIT2, &P5OUT	; Configuring ON

    ; Configuring P3.6 SCL
        bis.b	#BIT6, &P3DIR	; Initializing P3.6 as output
        bis.b	#BIT6, &P3OUT	; Configuring ON

	; Initialize Used Registers
        mov.w	#0, R4
        mov.w	#0, R5
        mov.w	#0, R6

	    nop
	    bic.b	#LOCKLPM5, &PM5CTL0		; Disable High-z

;--------------------------------- end of init ---------------------------------


;-------------------------------------------------------------------------------
; Main: main subroutine
;-------------------------------------------------------------------------------
Main:
        call 	#I2CStart			; I2C Start Condition / load address into memory
        call	#I2CTx				; I2C Transmit loaded bit
        call	#I2CAckRequest		; I2C Wait for acknowledge

        mov.b	#0055h, R4
        swpb	R4
        mov.b	#00008h, R6		; full byte being sent

        call	#I2CTx
        call	#I2CAckRequest

        call	#I2CStop		; I2C Stop Condition
        call	#I2CReset		; I2C Hold both lines high for a couple clock cycles for debugging
        call	#I2CReset

        jmp		Main
;--------------------------------- end of main ---------------------------------

;-------------------------------------------------------------------------------
; I2CStart:
;-------------------------------------------------------------------------------
I2CStart:
	bic.b	#BIT2, &P5OUT	; SDA Low

	mov.b	#0006Bh, R4		; 1101 0110b reversed from 0xEB Start bit + address 6B
	rla.w	R4				; one less byte being sent due to start condition
	bis.b	#BIT0, R4		; Set readwrite bit
; todo add read write bit

	swpb	R4
	mov.b	#00008h, R6		; full byte being sent

	call	#I2CClockDelay
	ret
	nop
;------------------------------- end of I2CStart -------------------------------

;-------------------------------------------------------------------------------
; I2CTx: Transmit data stored in R4.
;-------------------------------------------------------------------------------
I2CTx:

	bic.b	#BIT6, &P3OUT	; Clock to low

	call	#DataDelay		; Delay for data

	rla.w	R4				; SDA rotate transmitted bit into carry
	jc		SDA1			; output bit

SDA0:
	bic.b	#BIT2, &P5OUT
	jmp		TransmitClockCycle

SDA1:
	bis.b	#BIT2, &P5OUT

TransmitClockCycle:
	call	#I2CClockDelay	; Wait half clock period, before setting clock to high and waiting again.
	bis.b	#BIT6, &P3OUT
	call	#I2CClockDelay


	dec.b	R6				; Loop until byte is sent
	jnz		I2CTx

	ret
	nop
;--------------------------------- end of I2CTx --------------------------------
;-------------------------------------------------------------------------------
; I2CAckRequest:
;-------------------------------------------------------------------------------
I2CAckRequest: 
    ;INIT P5.2 as input with pull up 
        bic.b   #BIT2, &P5DIR
        bis.b   #BIT2, &P5REN
        bis.b   #BIT2, &P5OUT
         
        call    #DataDelay 		; Call I2C stability delay

        ;Set Clock High 
        bis.b   #BIT6, &P3OUT

        call    #Poll_Ack        ; Call polling loop for Ack

        call    #DataDelay 		; Call I2C stability delay

        ;Set Clock low
        bic.b   #BIT6, &P3OUT

	;Re-INIT P5.2 as output
		bis.b	#BIT2, &P5DIR	; Initializing pin as output

        ret
;----------------- END I2CAckReques Subroutine----------------------------------

;-------------------------------------------------------------------------------
; Poll_Ack:
;-------------------------------------------------------------------------------
Poll_Ack: 
        bit.b   #BIT2, &P5IN            ; Test P5.2 for Ack (High)
        jz      Poll_Ack                ; Until Data line is high keep polling
        ret                             ; Once acknowledged return
        
;----------------- END Poll_Ack Subroutine--------------------------------------
;-------------------------------------------------------------------------------
; I2CStop: Transmit stop condition for I2C
;-------------------------------------------------------------------------------
I2CStop:
	bic.b	#BIT6, &P3OUT	; SCL Low
	call	#DataDelay		; data delay
	bic.b	#BIT2, &P5OUT	; SDA Low
	call	#I2CClockDelay
	bis.b	#BIT6, &P3OUT	; SCL High
	call	#DataDelay		; data delay
	bis.b	#BIT2, &P5OUT	; SDA Low
	call	#I2CClockDelay
	ret
	nop
;------------------------------- end of I2CStart -------------------------------

;-------------------------------------------------------------------------------
; I2CReset: Holds both lines high for a clock cycle for debugging
;-------------------------------------------------------------------------------
I2CReset:
	bis.b	#BIT2, &P5OUT
	bis.b	#BIT6, &P3OUT
	call	#I2CClockDelay
	call	#I2CClockDelay
	ret
	nop
;--------------------------------- end of I2CTx --------------------------------

;-------------------------------------------------------------------------------
; I2CClockDelay: delay for clock pulses - not tuned todo
;-------------------------------------------------------------------------------
I2CClockDelay:
	mov.w	#003EFh, R5				; Tuned for 1s Delay with 8 loops
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
	nop
	nop
	nop
	nop
	nop
	nop
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
