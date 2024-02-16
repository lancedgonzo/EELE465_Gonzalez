;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
; 	EELE465
;	Written by: Zach Carmean, Lance Gonzalez, Grant Kirkland
;   Working: Grant Kirkland
;	Project 02 - Feb 2 2024
;
;	Summary:
;
;
;	Version Summary:
;   v01:
;   v02:
;	v03: Transmits byte of data with ack, sends another address
; 	v04: Switches to Compare interrupt for clock, finished I2C transmission
;	v05: Merged lances and zachs code. Working stop transmit and start code
;	v06: Merged zachs acknowledge code. Updated clock speed to 5kHz. Added code to receive data from RTC
;	v07: Set up memory allocation. Adjusted the read data and save data sections to cycle through memory positions
;
;	Ports:
;	    P3.6 - SCL
;	    P5.2 - SDA
;		P4.5 - Clock Active-Low Reset
;
;	Registers:
;	    R4	SDA
;	    R5	Clock Delay Loop
;	    R6	Remaining transmit bits
;		R7	Status Register
;			B7 - Clock
;			B6 - Ack
;			B0-4 Memory counter
;		R8	Memory address increment
;		R9	Transmit Counter
;
;	RTC:
;		Vin - 3V3
;		GND - GND
;		SCL - P3.6
;		SDA - P5.2
;		BAT - N/C
;		32K - N/C
;		SQW - N/C
;		RST - P4.5
;
;	Todo:
; 		* Add save to data memory functionality
;		* Flowchart
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
; Init: Initialization of Ports 5.2, 3.6, and 4.5
;-------------------------------------------------------------------------------
Init:

    ; Configuring P4.5 /RST
        bis.b	#BIT5, &P4DIR	; Initializing P4.5 as output
        bic.b	#BIT5, &P4OUT	; Configuring off

	; Configuring P5.2 SDA
	    bis.b	#BIT2, &P5DIR	; Initializing P5.2 as output
	    bis.b	#BIT2, &P5OUT	; Configuring ON

    ; Configuring P3.6 SCL
        bis.b	#BIT6, &P3DIR	; Initializing P3.6 as output
        bis.b	#BIT6, &P3OUT	; Configuring ON

	; Configuring Timer B0 - 1.05 (measured 1.00) s = 1E-6 * 8 * 5 * 104
		bis.w	#TBCLR, &TB0CTL			; Clear timers & dividers
		bis.w	#TBSSEL__SMCLK, &TB0CTL	; Set SMCLK as the source
		bis.w	#MC__UP, &TB0CTL		; Set mode as up
		bis.w	#CNTL_0, &TB0CTL		; 16-bit counter length
		mov.w	#00150, &TB0CCR0		; Setting Capture Compare Register 0
		bic.w	#CCIFG, &TB0CCTL0		; Clear interrupt flag - Capture/Compare

	; Initialize Used Registers
        mov.w	#0, R4
        mov.w	#0, R5
        mov.w	#0, R6
        mov.w	#0, R7
        mov.w	#0, R8
        mov.w	#0, R9
		bis.b	#BIT7, R7		; Set to match SCL


		nop
		bis.w	#GIE, SR				; Enable maskable interrupts
		nop
	    bic.b	#LOCKLPM5, &PM5CTL0		; Disable High-z
;--------------------------------- end of init ---------------------------------

;-------------------------------------------------------------------------------
; Main: main subroutine
;-------------------------------------------------------------------------------
Main:
		bis.b	#BIT5, &P4OUT		; Disabling RTC reset
		jmp		ReadLoopInit
		mov.b	#03h, R9			; 3 init outputs
InitLoop:

	; Initialize the RTC Loop (1 iteration for each register to be adressed)
		; Transmit Start condition, slave address transmit,
		call 	#I2CStartSend
		call	#I2CTx
		call	#I2CAckRequest

		bit.b	#BIT6, R7			; Test if ack recieved
		jnz		AckFailedInit

		; Transmit First section of memory
		call 	#ReadData
		call	#I2CTx
		call	#I2CAckRequest

		bit.b	#BIT6, R7			; Test if ack recieved
		jnz		AckFailedInit

		; Transmit Second section of memory
		call 	#ReadData
		call	#I2CTx				; I2C Transmit loaded bit
		call	#I2CAckRequest

		bit.b	#BIT6, R7			; Test if ack recieved
		jnz		AckFailedInit

;		call 	#I2CTxNack

		; Stop condition
		call	#I2CStop		; I2C Stop Condition

		; decrement loop counter
		call	#I2CReset
		dec.b	R9
		jnz		InitLoop 			; Continue Init until loop counter 0
		jmp		Main			; todo update to readloopinit

AckFailedInit:
		call	#I2CStop		; I2C Stop Condition
		call	#I2CReset
		jmp		Main

ReadLoopInit:
	mov.b	#05h, R9		; 5 memory addresses to cycle through
	bic.b	#BIT0, R7		; Update status bit to point to first address
	bic.b	#BIT1, R7
	bis.b	#BIT2, R7
	bis.b	#BIT3, R7
	bic.b	#BIT4, R7

ReadLoop:
	; Reading Time loop
		; Transmit start condition, slave address transmit
		call 	#I2CStartSend
		call	#I2CTx
		call	#I2CAckRequest

		bit.b	#BIT6, R7			; Test if ack recieved
		jnz		AckFailedRead

		; transmit address to read from
		call 	#ReadData
		call	#I2CTx
		call	#I2CAckRequest

		bit.b	#BIT6, R7			; Test if ack recieved
		jnz		AckFailedRead

		call	#I2CStop			; I2C Stop Condition

		call	#I2CReset

		; Transmit start read condition
		call 	#I2CStartRecieve
		call	#I2CTx
		call	#I2CAckRequest

		bit.b	#BIT6, R7			; Test if ack recieved
		jnz		AckFailedRead

		call	#I2CRx				; I2C Recieve loaded bit, then transmit nack and stop
		call	#I2CTxNack

		call	#I2CStop			; I2C Stop Condition

		call	#SaveData			; Save bit to memory
		call	#I2CReset

		; decrement loop counter
		dec.b	R9
		jnz 	ReadLoop
		jmp		ReadLoopInit

AckFailedRead:
		call	#I2CStop		; I2C Stop Condition
		call	#I2CReset
		jmp		ReadLoopInit

;--------------------------------- end of main ---------------------------------

;-------------------------------------------------------------------------------
; I2CStartSend:
;-------------------------------------------------------------------------------
I2CStartSend:
	bic.b	#BIT2, &P5OUT	; SDA Low

	mov.b	#00068h, R4		; 1101 000 reversed from 0xEB Start bit + address 6B
	rla.w	R4				; one less byte being sent due to start condition
	bic.b	#BIT0, R4		; Clear readwrite bit

	swpb	R4
	mov.b	#00008h, R6		; full byte being sent

	call 	#DataDelay
	call 	#Start_SCL
	ret
	nop
;----------------------------- end of I2CStartSend -----------------------------

;-------------------------------------------------------------------------------
; I2CStartRecieve:
;-------------------------------------------------------------------------------
I2CStartRecieve:
	bic.b	#BIT2, &P5OUT	; SDA Low

	mov.b	#00068h, R4		; 1101 000 reversed from 0xEB Start bit + address 6B
	rla.w	R4				; one less byte being sent due to start condition
	bis.b	#BIT0, R4		; Set readwrite bit

	swpb	R4
	mov.b	#00008h, R6		; full byte being sent

	call 	#DataDelay
	call 	#Start_SCL
	ret
	nop
;---------------------------- end of I2CStartRecieve ---------------------------

;-------------------------------------------------------------------------------
; Start_SCL:
;-------------------------------------------------------------------------------
Start_SCL:
    bic.w   #CCIFG, &TB0CCTL0
	bis.w	#CCIE, &TB0CCTL0		; Enable Capture/Compare interrupt for TB0

    ret
; --------------- END Start_SCL ------------------------------------------------

;-------------------------------------------------------------------------------
; I2CTxAck: Transmit data stored in R4.
;-------------------------------------------------------------------------------
I2CTxAck:
	mov.b	#00001h, R6		; 1 bit being sent
	mov.w	#00000h, R4
	call	#I2CTx
	ret
;--------------- END I2CTxAck ------------------------------------------------

;-------------------------------------------------------------------------------
; I2CTxAck: Transmit data stored in R4.
;-------------------------------------------------------------------------------
I2CTxNack:
	mov.b	#00001h, R6		; 1 bit being sent
	mov.w	#08000h, R4
	call	#I2CTx
	ret
;--------------- END I2CTxAck ------------------------------------------------


;-------------------------------------------------------------------------------
; I2CTx: Transmit data stored in R4.
;-------------------------------------------------------------------------------
I2CTx:
	bit.b	#BIT7, R7		; Test clock if zero, keep waiting for low
	jnz		I2CTx

	call	#DataDelay			; Delay for data

	rla.w	R4					; SDA rotate transmitted bit into carry
	jc		SDA1				; output bit

SDA0:
	bic.b	#BIT2, &P5OUT
	jmp		TransmitClockCycle

SDA1:
	bis.b	#BIT2, &P5OUT

TransmitClockCycle:
	bit.b	#BIT7, R7		; Test clock if zero, keep waiting for high
	jz		TransmitClockCycle

	dec.b	R6				; Loop until byte is sent
	jnz		I2CTx

TransmitEnd:
	bit.b	#BIT7, R7		; Test clock if zero, keep waiting for high
	jnz		TransmitEnd
	mov.b	#00008h, R6		; full byte being sent

	ret
	nop
;--------------------------------- end of I2CTx --------------------------------

;-------------------------------------------------------------------------------
; I2CRx: Receive data to R4.
;-------------------------------------------------------------------------------
I2CRx:
	call	#I2CDataLineInput
	mov.b	#00008h, R6		; full byte being received

I2CRxLowPoll:
	bit.b	#BIT2, &P5IN	; test input line
	jnz		RxInputHigh
RxInputLow:
	bic.b	#BIT0, R4
	jmp		RxInputSetDone
RxInputHigh:
	bis.b	#BIT0, R4
RxInputSetDone:
	bit.b	#BIT7, R7		; Test clock if zero, keep waiting for low

	jnz		I2CRxLowPoll

	rla.b	R4

I2CRxHighPoll:
	bit.b	#BIT7, R7		; Test clock if zero, keep waiting for low
	jz		I2CRxHighPoll


	dec.b	R6				; Loop until byte is received
	jnz		I2CRxLowPoll

	call	#I2CDataLineOutput
	ret
	nop
;--------------------------------- end of I2CTx --------------------------------

;-------------------------------------------------------------------------------
; SaveData:
;-------------------------------------------------------------------------------
SaveData:
	mov.w	#001Fh, R8		; Move bit mask into R8
	and.w	R7, R8			; Mask R7 using R8
	or.w	#2000h, R8		; or R8 with 2000h to generate address

	mov.w	R4, 0(R8)		; Move contents of R4 to address

	inc.w	R8				; Set R8 to next address location and check if its rolled over. if it has, reset.
	inc.w	R8

	cmp		#2020h, R8

	jnz		PostSaveStatus
	mov.w	#2000h, R8;

PostSaveStatus:
	and.b	#00E0h, R7		; Update R7 with new address
	and.b	#001Fh, R8		; Update R7 with new address
	or.b	R8, R7

;	mov.w 	#000h, R4
	ret
	nop
;--------------------------- end of I2CDataLineInput ---------------------------

;-------------------------------------------------------------------------------
; ReadData:
;-------------------------------------------------------------------------------
ReadData:
	mov.w	#001Fh, R8		; Move bit mask into R8
	and.w	R7, R8			; Mask R7 using R8
	or.w	#2000h, R8		; or R8 with 2000h to generate address

	mov.w	@R8+, R4		; Move contents of R4 to address and increment to next address location. then check if it has rolled over, if it has reset.
	swpb	R4

	cmp		#2020h, R8

	jnz		PostReadStatus
	mov.w	#2000h, R8;

PostReadStatus:
	and.b	#00E0h, R7		; Update R7 with new address
	and.b	#001Fh, R8		; Update R7 with new address
	or.b	R8, R7

;	mov.w 	#000h, R4
	ret
	nop
;--------------------------- end of I2CDataLineInput ---------------------------

;-------------------------------------------------------------------------------
; I2CDataLineInput:
;-------------------------------------------------------------------------------
I2CDataLineInput:
	;INIT P5.2 as input with pull up
    bic.b   #BIT2, &P5DIR
    bis.b   #BIT2, &P5REN
    bis.b   #BIT2, &P5OUT

	ret
	nop
;--------------------------- end of I2CDataLineInput ---------------------------

;-------------------------------------------------------------------------------
; I2CAckRequest:
;-------------------------------------------------------------------------------
I2CAckRequest:
	call	#I2CDataLineInput

AckWait1:
	; if ack 1 the bis bit1 r7: 0 then 0
	bit.b	#BIT2, &P5IN	; test input line
	jnz		SetAck
UnsetAck:
	bic.b	#BIT6, R7
	jmp		ClkTest
SetAck:
	bis.b	#BIT6, R7
ClkTest:
	bit.b	#BIT7, R7		; Test clock if zero, keep waiting for high
	jz		AckWait1
AckWait2:
	bit.b	#BIT7, R7		; Test clock if zero, keep waiting for high
	jnz		AckWait2

	call	#I2CDataLineOutput

	ret
    nop

;----------------- END I2CAckReques Subroutine----------------------------------

;-------------------------------------------------------------------------------
; I2CDataLineOutput:
;-------------------------------------------------------------------------------
I2CDataLineOutput:
	bit.b	#BIT2, &P5IN		; Test input line, and set output to match before setting P5.2 as output
	jz		DataLineOutLow

    bis.b   #BIT2, &P5OUT
	jmp		EndDataLineOutput

DataLineOutLow:
    bic.b   #BIT2, &P5OUT

EndDataLineOutput:
	bis.b	#BIT2, &P5DIR		; Reinitializing pin as output
    ret
    nop
;--------------------------- end of I2CDataLineOutput --------------------------

;-------------------------------------------------------------------------------
; I2CStop: Transmit stop condition for I2C
;-------------------------------------------------------------------------------
I2CStop:
	bit.b	#BIT7, R7		; Test clock if zero, keep waiting for high before raising output to high for stop condition.
	jz		I2CStop

StopHigh:
	call 	#DataDelay
	bis.b	#BIT2, &P5OUT
	call 	#DataDelay

    bic.w   #CCIE, &TB0CCTL0            ; disble CCR0
    bic.w   #CCIFG, &TB0CCTL0

	mov.w	#0, TB0R

	ret
	nop
;------------------------------- end of I2CStart -------------------------------


;-------------------------------------------------------------------------------
; I2CReset: Holds both lines high for a short time to put delays between outputs
;-------------------------------------------------------------------------------
I2CReset:
	bis.b	#BIT2, &P5OUT
	bis.b	#BIT6, &P3OUT
	bis.b	#BIT7, R7
	call	#I2CClockDelay
	call	#I2CClockDelay
	ret
	nop
;--------------------------------- end of I2CTx --------------------------------

;-------------------------------------------------------------------------------
; I2CClockDelay: delay for clock pulses - not tuned todo
;-------------------------------------------------------------------------------
I2CClockDelay:
	mov.w	#000EFh, R5				; Tuned for 1s Delay with 8 loops
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
	ret
	nop
;--------------------------------- end of delay --------------------------------

; ~~~~~~~~~~~~~~~~~~~~~~~~ Data Memory ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;-------------------------------------------------------------------------------
; Data Memory
;-------------------------------------------------------------------------------
    .data                   ; go to data memory (2000h)
    .retain                 ; keep section even if not used

SecondsAddr1:	.short    0000h
SecondsData1:	.short    0030h
MinutesAddr2:	.short    0001h
MinutesData2:	.short    0011h
HoursAddr3:		.short    0002h
HoursData3:		.short    0013h
SecondsAddr4:	.short    0000h
SecondsData4:	.short    0000h
MinutesAddr5:	.short    0001h
MinutesData5:	.short    0000h
HoursAddr6:		.short    0002h
HoursData6:		.short    0000h
TempAddr7:		.short    0011h
TempData7:		.short    0000h
TempAddr8:		.short    0012h
TempData8:		.short    0000h
;~~~~~~~~~~~~~~~~~~~~~~~~~ End Data Memory ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; ~~~~~~~~~~~~~~~~~~~~~~~~ INTERRUPT SERVICE ROUTINES ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;-------------------------------------------------------------------------------
; ISR_TB0_CCR0 - XOR output to toggle clock, also XOR status bit to keep synced to clock
;-------------------------------------------------------------------------------
ISR_TB0_CCR0:
    xor.b   #BIT6, &P3OUT
    xor.b	#BIT7, R7
    bic.w   #CCIFG, &TB0CCTL0
    reti
    nop
; --------------- END ISR_TB0_CCR0 ---------------------------------------------

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
