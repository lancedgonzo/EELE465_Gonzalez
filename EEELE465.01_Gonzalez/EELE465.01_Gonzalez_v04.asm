;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
; EELE465
; Written by: Lance Gonzalez
; Project 01v01 - Jan 20 2024
; Heartbeat LED
;
;
;
; Version History:
;   v01 - Test LED1 (P1.0)
;   v02 - Flash LED1 via Subroutine
;   v03 - Test LED2 (P6.6)
;   v04 - Include ISR for LED2
;-------------------------------------------------------------------------------


;~~ CONTROLLER CONFIGURATION ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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

;~~ MAIN FUNCTION ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;-------------------------------------------------------------------------------
; Main loop here
;-------------------------------------------------------------------------------

init: 
        ;-Port Setups (LED1, LED2, LPM-disable)
            bis.b   #BIT0, &P1DIR
            bis.b   #BIT6, &P6DIR
            bic.b   #LOCKLPM5, &PM5CTL0
            bis.b   #BIT6, &P6OUT
            

        ;-Timer B0 Setup
            bis.w   #TBCLR, &TB0CTL
            bis.w   #TBSSEL__SMCLK, &TB0CTL
            bis.w   #MC__CONTINUOUS, &TB0CTL
            bis.w   #ID__4, &TB0CTL
            bis.w   #TBIE, &TB0CTL
            bic.w   #TBIFG, &TB0CTL
            bis.w   #GIE, SR
            
main:
            call    #flashLED1
            jmp     main



;~~ SUBROUTINES ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;-------------------------------------------------------------------------------
; FLASH LED1:
;-------------------------------------------------------------------------------
flashLED1:
            xor.b   #BIT0, &P1OUT
            call    #delay

            ret
;----------------- END FLASH LED1 ----------------------------------------------


;-------------------------------------------------------------------------------
; DELAY LOOP:
;-------------------------------------------------------------------------------
delay: 
            mov.w   #0FFFFh, R4
            mov.w   #0FFFFh, R5

delay_decInnerLoop:
            dec.w   R4
            jnz     delay_decInnerLoop

delay_decOuterLoop:
            dec.w   R5
            jnz     delay_decOuterLoop

            ret
;----------------- END DELAY LOOP ----------------------------------------------

;-------------------------------------------------------------------------------
; ISR - TIMERB0 OVERFLOW:
;-------------------------------------------------------------------------------
ISR_TB0_Overflow:
            xor.b   #BIT6, &P6OUT
            bic.w   #TBIFG, &TB0CTL
            reti

;----------------- END TIMERB0 OVERFLOW ----------------------------------------


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

            .sect   ".int42"
            .short  ISR_TB0_Overflow
