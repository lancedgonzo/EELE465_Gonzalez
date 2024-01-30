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
; Main loop here
;-------------------------------------------------------------------------------
init: 

    ;Init P6.6 (LED2) as output
        bis.b   #BIT6, &P6DIR
        bic.b   #BIT6, &P6OUT
        

        bic.b   #LOCKLPM5, &PM5CTL0         ; disable low power mode 

main:
        call    #I2CAckRequest
        call 	#delay
        jmp     main
                         


;-------------------------------------------------------------------------------
; I2CAckRequest:
;-------------------------------------------------------------------------------
I2CAckRequest: 
    ;INIT P5.2 as input with pull up 
        bic.b   #BIT2, &P5DIR
        bis.b   #BIT2, &P5REN
        bis.b   #BIT2, &P5OUT

        ;Set "Clock" High 
        bis.b   #BIT6, &P6OUT

        call    #Poll_Ack        ; Call polling loop for Ack

        ;Set "Clock" low
        bic.b   #BIT6, &P6OUT

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
; DELAY LOOP:
;-------------------------------------------------------------------------------
delay: 
    ;^ Sets inner loop at 100ms and outer loop at total 100ms increments for total time
            mov.w   #0FFFFh, R4
            mov.w   #010h, R5

delay_decInnerLoop:
            dec.w   R4
            jnz     delay_decInnerLoop

            dec.w   R5
            jnz     delay

            ret
;----------------- END DELAY LOOP ----------------------------------------------

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
            
