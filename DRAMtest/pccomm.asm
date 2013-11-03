/*
 * pcserial.asm
 *
 *  Created: 23.11.2011 18:23:18
 *   Author: Ondra Moravek
 *   BOOTLOADER_NATIVE
 */ 
 

 .def PCTEMP = R22
 .def TXflash = R17 ; param2

 .macro		ADDI16
	LDI		ZL, @0
	LDI		ZH, @1
	ADD		ZL, @2
	ADC		ZH, @3
.endmacro

// r17:r16 = r17:r16+r19:r18
.macro		ADD16
	ADD		@1, @3
	ADC		@0, @2
.endmacro


.cseg

/* PC_Init: Prepares UART0 for communication with PC
*/
PC_Init:
	LDI		R16, 0
	OUT		UCSRA, R16 ; UCSR0A
	LDI		R16, (1 << RXEN) | (1 << TXEN) ; enable transmit and receive
	OUT		UCSRB, R16
	LDI		R16, (1 << UCSZ1) | (1 << UCSZ0) | (1 << URSEL) ; 8n1
	OUT		UCSRC, R16

	LDI		R16, 51

	OUT		UBRRL, R16

	RET

/* PC_SEND: Sends data through serial port to PC
 *	Params:
 *   R16 - data
*/
PC_SEND:
PC_SEND_WAIT:
	SBIS	UCSRA, UDRE
	RJMP	PC_SEND_WAIT
	; UDRE0 flag cleared if we got here

	OUT		UDR, R16
	RET

/* PC_RECEIVE: Receives data from serial port from PC
 *	Returns:
 *   R16 - data
*/
PC_RECEIVE:
PC_RECEIVE_WAIT:
	SBIS	UCSRA, RXC
	RJMP	PC_RECEIVE_WAIT
	
	IN		R16, UDR
	
.ifndef BINARY
	RCALL	PC_SEND
.endif

	RET


HEXNUMS: .db 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46


/* PC_DUMPSTRING: Sends string from flash/RAM into PC
 * CALL THROUGH PC_Send_String or PC_Send_String_RAM! Not directly!
 *
*/
PC_DUMPSTRING:
	; is it from flash?
	MOVW	X, Z
	RCALL	DRAMREAD
PC_DUMPSTRING_SEND:
	TST		R22 ; check if it is 00 -> end
	BREQ 	PC_DUMPSTRING_END
	MOV		R16, R22
	RCALL 	PC_SEND
	ADIW	Z, 1
	RJMP	PC_DUMPSTRING
PC_DUMPSTRING_END:
	RET

/* PC_DUMPBINARY: Sends binary number to UART
   Params:
		R16 - number of bytes
		Z - low bytes of address
		R17.0 - high bit of address (flash only)
		R18.0 - flash /1/ or RAM /0/
*/
PC_DUMPBINARY:
	PUSH	R22
PC_DUMPBINARY_LOOP:
	MOVW	X, Z
	RCALL	DRAMREAD
	ADIW	Z, 1
PC_DUMPBINARY_DO:
	PUSH	R16
	PUSH	ZL
	PUSH	ZH
	PUSH	R22
	; loop
	SWAP	R22 ; convert little endian to regular readable format
	ANDI	R22, 0xF
	LDI		R16, 0
	ADDI16	LOW(HEXNUMS<<1), HIGH(HEXNUMS<<1), R22, R16
	; do not forget to set RAMPZ, considering that HEXNUMS might be after 64kB boundary
	ELPM	R16, Z
	RCALL	PC_Send
	POP		R22
	ANDI	R22, 0xF
	LDI		R16, 0
	ADDI16	LOW(HEXNUMS<<1), HIGH(HEXNUMS<<1), R22, R16
	; do not forget to set RAMPZ, considering that HEXNUMS might be after 64kB boundary
	ELPM	R16, Z
	RCALL	PC_Send
	POP		ZH
	POP		ZL
	POP		R16
	SUBI	R16, 1
	TST		R16
	BREQ	PC_DUMPBINARY_END
	RJMP	PC_DUMPBINARY_LOOP
PC_DUMPBINARY_END:
	POP		R22
	RET

/* PC_LOADBINARY: Loads binary number in hex format from UART and saves to RAM.
    Params:
		X: base address
		R18: Length
*/
PC_LOADBINARY:
	PUSH	R17
PC_LOADBINARY_LOOP:
	TST		R18
	BREQ	PC_LOADBINARY_END
	RCALL	PC_RECEIVE ; load low nibble
	;MOV		R17, R16 ; save the low nibble
	; trick -- substract 0x30. If it is higher than 0x9, substract another 0x7
	SUBI	R16, 0x30
	CPI		R16, 0x10
	BRGE	PC_LOADBINARY_AF_LOW
PC_LOADBINARY_HIGHNIBBLE:
	MOV		R17, R16
	ANDI	R17, 0x0F
	RCALL	PC_RECEIVE ; load high nibble
	SUBI	R16, 0x30
	CPI		R16, 0x10
	BRGE	PC_LOADBINARY_AF_HIGH
PC_LOADBINARY_SAVE:
	ANDI	R16, 0x0F
	SWAP	R17
	OR		R16, R17
	ST		X+, R16
	SUBI	R18, 1
	RJMP	PC_LOADBINARY_LOOP

PC_LOADBINARY_AF_LOW:
	SUBI	R16, 0x7
	RJMP	PC_LOADBINARY_HIGHNIBBLE

PC_LOADBINARY_AF_HIGH:
	SUBI	R16, 0x7
	RJMP	PC_LOADBINARY_SAVE

PC_LOADBINARY_END:
	POP		R17
	RET
