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

;-------------------------------------------------------------------------------
init: 
    ; Configuring P5.2 SDA
	    bis.b	#BIT2, &P5DIR	        ; Initializing P5.2 as output
	    bis.b	#BIT2, &P5OUT	        ; Configuring ON

    ; Configuring P3.6 SCL
        bis.b	#BIT6, &P3DIR	        ; Initializing P3.6 as output
        bis.b	#BIT6, &P3OUT	        ; Configuring ON

        bic.b	#LOCKLPM5, &PM5CTL0		; Disable High-z

    ; Configuring Timer B0 
        bis.w   #TBCLR, &TB0CTL
        bis.w   #TBSSEL__SMCLK, &TB0CTL
        bis.w   #MC__UP, &TB0CTL

    ; Timer Compare Registers
        mov.w   #32768, &TB0CCR0        ; init CCR0
        mov.w   #1638, &TB0CCR1         ; init CCR1

        bis.w   #CCIE, &TB0CCTL0
        bic.w   #CCIFG, &TB0CCTL0

        bis.w   #CCIE, &TB0CCTL1
        bic.w   #CCIFG, &TB0CCTL1

        bis.w   #GIE, SR

main: 
        jmp main    

;-------------------------------------------------------------------------------
; Start and Stop functionality
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; Interrupt Service Routines
;-------------------------------------------------------------------------------
ISR_TB0_CCR1: 
        bic.b   #BIT6, &P3OUT
        bic.w   #CCIFG, &TB0CCTL1
        reti

ISR_TB0_CCR0: 
        bis.b   #BIT6, &P3OUT
        bic.w   #CCIFG, &TB0CCTL0
        reti
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

