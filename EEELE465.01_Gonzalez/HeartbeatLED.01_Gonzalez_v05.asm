;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
; EELE465
; Written by: Lance Gonzalez
; Project 5 - Jan 22 2024
; Heartbeat LED
;
;   R4 = Inner Loop Value
;   R5 = Outer Loop Value
;
; Version History:
;   v01 - Test LED1 (P1.0)
;   v02 - Flash LED1 via Subroutine
;   v03 - Test LED2 (P6.6)
;   v04 - Include ISR for LED2
;   v05 - Tuned LED1 and LED2 to 0.5Hz
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


;~~ INITIALIZATION HERE ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
init: 
    ;-Port Setups 
        ;^ LED1(P1.0) -> Output, LED2(P6.6) -> Output, LPM-disable
            bis.b   #BIT0, &P1DIR
            bis.b   #BIT6, &P6DIR
            bic.b   #LOCKLPM5, &PM5CTL0

    ;-Timer B0 Setup using overflow Interrupt. 
        ;^ Configured to ACLK, Coninious, 12 bit,
        ;^ divide by 16 total,Enable TB0 Overflow Interrupt
            bis.w   #TBCLR, &TB0CTL             
            bis.w   #TBSSEL__ACLK, &TB0CTL          
            bis.w   #MC__CONTINUOUS, &TB0CTL      
            bis.w   #CNTL_1, &TB0CTL                ; 12-bit timer
            bis.w   #ID__8, &TB0CTL                 
            bis.w   #TBIDEX__8, &TB0CTL             
            bis.w   #TBIE, &TB0CTL                  ; Local Interrupt enable (TB0)
            bic.w   #TBIFG, &TB0CTL

            bis.w   #GIE, SR                        ; Global Maskable Interrupt Enable

;~~ MAIN FUNCTION ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;-------------------------------------------------------------------------------
; Main loop here
;-------------------------------------------------------------------------------
main:   ; Calls flashLED1 and returns. Main is infinite loop. 
            call    #flashLED1
            jmp     main

;~~ SUBROUTINES ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;-------------------------------------------------------------------------------
; FLASH LED1:
;-------------------------------------------------------------------------------
flashLED1:  
    ;^ Toggles P1.0, Sets outer loop value of 09h, calls subroutine delay
            xor.b   #BIT0, &P1OUT
            mov.w   #014h, R5
            call    #delay

            ret
;----------------- END FLASH LED1 ----------------------------------------------

;-------------------------------------------------------------------------------
; DELAY LOOP:
;-------------------------------------------------------------------------------
delay: 
    ;^ Sets 08FFFh as inner loop value, decrement inner loop until 0, outerloop decrements
    ;^ Inner loop nested in outerloop (repeats every outer loop), when outerloop is zero return
            mov.w   #0445Ch, R4

delay_decInnerLoop:
            dec.w   R4
            jnz     delay_decInnerLoop

delay_decOuterLoop:
            dec.w   R5
            jnz     delay

            ret
;----------------- END DELAY LOOP ----------------------------------------------

;-------------------------------------------------------------------------------
; ISR - TIMERB0 OVERFLOW:
;-------------------------------------------------------------------------------
ISR_TB0_Overflow:
    ;^ Toggle P6.6 and clear TB0 interrupt flag, return from interrupt
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
