/*
 * DRAMtest.asm
 *
 *  Created: 17.5.2012 15:24:45
 *   Author: Ondra
 */ 

/*
	PortA = A0-A7
	PortB = A8-A11, DATA/0-1 
	PortC = 0/CAS, 1/RAS, 6/WE
	PortD = DATA/2-7

*/

 .dseg
ADDRLD: .BYTE 2

.cseg


.equ	CAS = 0
.equ	PCAS = PORTC
.equ	RAS = 1
.equ	PRAS = PORTC
.equ	WE = 6
.equ	PWE = PORTC

.org 0x00
JMP		START

.org OVF0ADDR
JMP		DRAMREFRESH

.include "DRAM.asm"

STR_CMDLINE: .db 0x0D, 0x0A, "Command> ", 0x00
STR_UNKNOWN_COMMAND: .db "Unknown command.", 0x0D, 0x0A, 0x00
STR_CRLF: .db 0x0D, 0x0A, 0x00


START:
	LDI		R16, LOW(RAMEND)
	LDI		R17, HIGH(RAMEND)

	OUT		SPL, R16
	OUT		SPH, R17

	LDI		R16, (1 << CAS) | (1 << RAS) | (1 << WE)
	OUT		DDRD, R16

	LDI		R16, 0xFF
	OUT		DDRA, R16
	OUT		DDRC, R16

	LDI		R16, 0x03
	OUT		DDRB, R16


	RCALL	DRAMINIT
	RCALL	PC_Init

APP:
	/*PC_Send_String STR_CMDLINE
	RCALL	PC_Receive

	PUSH	R16
	PC_Send_String	STR_CRLF
	POP		R16

	CPI		R16, 'a'
	BREQ	B_COMMAND_ADDR

	CPI		R16, 'r' //read memory
	BREQ	B_COMMAND_READ

	CPI		R16, 'w' // write memory
	BREQ	B_COMMAND_WRITE

	PC_Send_String	STR_UNKNOWN_COMMAND*/

	CLR		R26
	CLR		R27
	CLR		R28
	LDI		R16, 0x55
	RCALL	DRAMWRITE
	LDI		R16, 0xAA
	LDI		R26, 0x02
	RCALL	DRAMWRITE

	CLR		R26
	RCALL	DRAMREAD
	MOV		R18, R16
	LDI		R26, 0x02
	RCALL	DRAMREAD
	MOV		R17, R16

	JMP		APP

B_COMMAND_ADDR:
	RCALL	COMMAND_ADDR
	RJMP	APP

B_COMMAND_READ:
	LDI		R16, 1
	MOV		ZL, XL
	MOV		ZH, XH
	LDI		R17, 0x1
	LDI		R18, 0 ; RAM
	CALL	PC_DUMPBINARY
	RJMP	APP

B_COMMAND_WRITE:
	PUSH	XL
	PUSH	XH
	LDI		R18, 1 ; one byte
	RCALL	PC_LOADBINARY
	POP		XH
	POP		XL
	RJMP	APP

COMMAND_ADDR:
	LDI		XL, LOW(ADDRLD)
	LDI		XH, HIGH(ADDRLD)
	LDI		R18, 2
	RCALL	PC_LOADBINARY
	LDI		ZL, LOW(ADDRLD)
	LDI		ZH, HIGH(ADDRLD)
	LD		XH, Z+ ; first read HIGH byte
	LD		XL, Z
COMMAND_ADDR_END:
	RJMP	APP



.include "pccomm.asm"
