;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
; EELE465
; Written by: Lance Gonzalez
; Project 02 - Jan 25 2024
; Bit Banging I2C 
;
;   Ports:
;       P3.6 - I2C SDA
;       P5.2 - I2C SCL 
;
;   Registers:
;       R4: I2C transmit byte
;
;
; Version History:
;   v01 - Created timer compart interrupt for SCL PWM
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

;~~ INITIALIZATION ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
init: 
    ;^ Handles port, register, and other initialization

    ; Port Setup
        bis.b   #BIT0, &P1DIR               ; P1.0 -> output
        bic.b   #BIT0, &P1OUT
        bic.b   #LOCKLPM5, &PM5CTL0         ; disable low power mode 

    ; Timer Setup
        bis.w   #TBCLR, &TB0CTL             ; Clear TB0
        bis.w   #TBSSEL__SMCLK, &TB0CTL     ; SMCLK
        bis.w   #MC_UP, &TB0CTL             ; UP 

    ; Timer Compare Reg
        mov.w   #01BE7h, &TB0CCR0           ; 7143d -> 7.1428e-5 s
        mov.w   #0BB8h, &TB0CCR1            ; 3000d -> 3e-5 s 

        ;Interrupt enable + flag clear
        bis.w   #CCIE, &TB0CCTL0
        bic.w   #CCIFG, &TB0CCTL0
        
        ;Interrupt enable + flag clear
        bis.w   #CCIE, &TB0CCTL1
        bic.w   #CCIFG, &TB0CCTL1

        bis.w   #GIE, SR                    ; Enable maskable


;~~ MAIN FUNCTION ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;-------------------------------------------------------------------------------
; Main loop here
;-------------------------------------------------------------------------------
main:   
    ;^ Infinite Loop
            jmp     main

;~~ INTERRUPT SERVICE ROUTINES ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;-------------------------------------------------------------------------------
; ISR - TIMERB0_CLOCK_PWM:
;-------------------------------------------------------------------------------
ISR_TB0_ClockPWM:
    ;^ PWM at 14 kHz, duty = 42%
            reti
;----------------- END TIMERB0_CLOCK_PWM ---------------------------------------

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
            
