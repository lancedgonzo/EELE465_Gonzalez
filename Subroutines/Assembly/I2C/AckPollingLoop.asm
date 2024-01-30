;-------------------------------------------------------------------------------
; I2C Acknolwedge Request Subroutine [Copy Only] File in Assembly
;
; Purpose:      This subroutine sets P5.2 (SDA) as input with pull-up resistor and calls
;               a polling loop that bit tests the input and continues to loop unitl 
; 
; Important Notes:      There is an includded call for an I2C stability Delay which is 
;                       currently not included. 

;-------------------------------------------------------------------------------
; I2CAckRequest:
;-------------------------------------------------------------------------------
I2CAckRequest: 
    ;INIT P5.2 as input with pull up 
        bic.b   #BIT2, &P5DIR
        bis.b   #BIT2, &P5REN
        bis.b   #BIT2, &P5OUT
         
        call    ; Call I2C stability delay

        ;Set Clock High 
        bis.b   #BIT6, &P3OUT

        call    Poll_Ack        ; Call polling loop for Ack

        call    ; Call I2C bit Delay

        ;Set Clock low
        bic.b   #BIT6, &P3OUT

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