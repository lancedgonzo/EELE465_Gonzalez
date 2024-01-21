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
;   v01 - Test LED1 (OPERATIONAL)
;   v02 - Flash LED1 via Subroutine
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
            bic.w   #0001h, &PM5CTL0        ; enable GPIO low power mode
            bis.b   #01h, &P1DIR
main:

            jmp     flashLED1



;~~ SUBROUTINES ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;-------------------------------------------------------------------------------
; FLASH LED1:
;-------------------------------------------------------------------------------
flashLED1:
            xor.b  #01h, &P1OUT
            jmp    delay
;----------------- END FLASH LED1 ----------------------------------------------


;-------------------------------------------------------------------------------
; DELAY LOOP:
;-------------------------------------------------------------------------------
delay: 
            mov.w   #0FFFFh, R4
;            mov.w   #0FFFFh, R5

delay_decInnerLoop:
            dec.w   R4
            jnz     delay_decInnerLoop
            jz      main

;decOuterLoop:
;            dec.w   R5
;            jnz     delay
;----------------- END DELAY LOOP ----------------------------------------------

;-------------------------------------------------------------------------------
; ISR - TIMERB0 OVERFLOW:
;-------------------------------------------------------------------------------


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
            
