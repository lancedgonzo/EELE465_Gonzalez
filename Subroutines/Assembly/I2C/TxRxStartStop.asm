;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
;
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

;------------------------------------------------------------------------------
; init
;------------------------------------------------------------------------------
init:

		mov.w   #WDTPW | WDTHOLD, &WDTCTL

		mov.w   #UCB0CTLW0, UCB0CTLW0		; start of I2C set up
		bis.w   #UCSWRST, UCB0CTLW0


		bis.w   #UCSSEL__SMCLK, UCB0CTLW0
		mov.b 	#10, UCB0BRW

		bis.w   #UCMODE_3, UCB0CTLW0
		bis.w   #UCMST + UCTR, UCB0CTLW0

		mov.b 	#0x68, UCB0I2CSA

		mov.b 	#0x01, UCB0TBCNT
		bis.w 	#UCASTP_2, UCB0CTLW1

		bis.w 	#0x01, UCB0TBCNT

		bis.b   #BIT6, &P3DIR               ; P3.6 -> output
        bic.b   #BIT6, &P3OUT

		bis.b   #BIT2, &P5DIR               ; P5.2 -> output
        bic.b   #BIT2, &P5OUT

		bic.b	#LOCKLPM5, &PM5CTL0

		bic.w   #UCSWRST, UCB0CTLW0

		bis.w 	#UCTXIE0, UCB0IE			; Rx and Tx inturrupt set up
		bis.w 	#UCRXIE0, UCB0IE
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
; Main loop here
;-------------------------------------------------------------------------------
I2Cstart:
		bis.w #UCTXSTT, UCB0CTLW0  ; Start I2C by setting UCTXSTT bit
                                            
I2Ctransmit:
		bis.w	#UCTR, UCB0CTLW0
		bis.w	#UCTXSTT, UCB0CTLW0		; start condition

I2Creceive:
		bic.w	#UCTR, UCB0CTLW0
		bis.w	#UCTXSTT, UCB0CTLW0		; start condition

I2Cstop:
		bis.w   #UCTXSTP, UCB0CTLW0		; stop condition


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
            
