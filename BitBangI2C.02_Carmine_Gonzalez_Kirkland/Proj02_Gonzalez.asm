;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
; EELE465
; Written by: Lance Gonzalez
; Project 02 - Jan 29 2024
; Bit Banging I2C 
;
;   Ports:
;       P3.6 - I2C SDA
;       P5.2 - I2C SCL 
;
;   Registers:
;       R4: Delay Loop 1
;       R5: Delay loop 2
;
; Version History:
;   v01 - Created timer compart interrupt for SCL PWM
;   v02 - Enables and Disables Clock PWM in cycle
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
        bis.b   #BIT6, &P3DIR               ; P3.6 -> output
        bic.b   #BIT6, &P3OUT
        bic.b   #LOCKLPM5, &PM5CTL0         ; disable low power mode 

    ; Timer Setup
        bis.w   #TBCLR, &TB0CTL             ; Clear TB0
        bis.w   #TBSSEL__SMCLK, &TB0CTL     ; SMCLK
        bis.w   #MC__UP, &TB0CTL            ; UP

    ; Timer Compare Reg
        mov.w   #048h, &TB0CCR0          	; 72d -> 7.1428e-5 s
        mov.w   #01Eh, &TB0CCR1            	; 30d -> 3e-5 s

        ;CCR0 flag clear
        ;bic.w   #CCIFG, &TB0CCTL0
        
        ;CCR1 flag clear
        ;bic.w   #CCIFG, &TB0CCTL1

        bis.w   #GIE, SR                    ; Enable maskable


;~~ MAIN FUNCTION ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;-------------------------------------------------------------------------------
; Main loop here
;-------------------------------------------------------------------------------
main:   
    ;^ Starts Clock Ends Clock in cyclic manner with delay loop
        call    #I2C_SCL_ON                      ; Starts PWM
        call    #delay                           ; waits set amount of time
        call    #I2C_SCL_OFF                     ; Stops PWM
        call 	#delay
        jmp     main


;~~ SUBROUTINES ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;-------------------------------------------------------------------------------
; I2C_SCL_ON:
;-------------------------------------------------------------------------------
I2C_SCL_ON: 
        bis.w   #CCIE, &TB0CCTL0
        bic.w 	#CCIFG, &TB0CCTL0

        bis.w   #CCIE, &TB0CCTL1
        bic.w 	#CCIFG, &TB0CCTL1
        ret
;----------------- END I2C_SCL_ON LOOP -----------------------------------------

;-------------------------------------------------------------------------------
; I2C_SCL_OFF:
;-------------------------------------------------------------------------------
I2C_SCL_OFF: 
        bic.w   #CCIE, &TB0CCTL0
        bic.w   #CCIE, &TB0CCTL1
        ret
;----------------- END I2C_SCL_OFF LOOP -----------------------------------------

;-------------------------------------------------------------------------------
; DELAY LOOP:
;-------------------------------------------------------------------------------
delay: 
    ;^ Sets inner loop at 100ms and outer loop at total 100ms increments for total time
            mov.w   #0FFFFh, R4
            mov.w   #0FFFFh, R5

delay_decInnerLoop:
            dec.w   R4
            jnz     delay_decInnerLoop

            dec.w   R5
            jnz     delay

            ret
;----------------- END DELAY LOOP ----------------------------------------------

;~~ INTERRUPT SERVICE ROUTINES ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;-------------------------------------------------------------------------------
; ISR - TIMERB0_CCR1: Sets P1.0 output to low
;-------------------------------------------------------------------------------
ISR_TB0_CCR1:
    ;^ PWM at 14 kHz, duty = 42%
        bic.b   #BIT6, &P3OUT
        bic.w   #CCIFG, &TB0CCTL1
        reti
;----------------- END TIMERB0_CCR1 -------------------------------------------

;-------------------------------------------------------------------------------
; ISR - TIMERB0_CCR0: Sets P1.0 output to HIGH
;-------------------------------------------------------------------------------
ISR_TB0_CCR0:
    ;^ PWM at 14 kHz, duty = 42%
        bis.b   #BIT6, &P3OUT
        bic.w   #CCIFG, &TB0CCTL0
        reti
;----------------- END TIMERB0_CCR0 -------------------------------------------

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

            .sect   ".int43"                ; ISR Vector Def for CCR0
            .short  ISR_TB0_CCR0

            .sect   ".int42"                ; ISR Vector Def for CCR1
            .short  ISR_TB0_CCR1
            
