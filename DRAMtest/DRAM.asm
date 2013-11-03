/*
 * DRAM.asm
 *
 *  Created: 17.5.2012 17:19:00
 *   Author: Ondra
 */ 

.macro		CPI16
	CPI		@1, LOW(@2)
	LDI		R22, HIGH(@2)
	CPC		R22, @0
.endmacro

 .macro PC_Send_String ; sends string from data section
 .ifndef BINARY
	PUSH	TXflash
	PUSH	ZH
	PUSH	ZL
	PUSH	R18

	LDI		TXflash, 1
	LDI		ZL, LOW(@0<<1)
	LDI		ZH, HIGH(@0<<1)
	CALL	PC_DUMPSTRING

	POP		R18
	POP		ZL
	POP		ZH
	POP		TXflash
.endif
.endmacro


DRAMINIT:
	LDI		R16, (1 << CS01) | (1 << CS00) ; clk/64
	OUT		TCCR0, R16
	LDI		R16, (1 << TOIE0)
	OUT		TIMSK, R16
	SEI
	RET


 
DRAMREFRESH:
	PUSH	ZL
	IN		ZL, SREG
	PUSH	ZL
	PUSH	ZH
	; set counter in Z reg
	CLR		ZL
	CLR		ZH
DRAMREFRESH_LOOP:
	ADIW	Z, 1
	CPI16	ZH, ZL, 1024
	BREQ	DRAMREFRESH_END
	; toggle /CAS
	CBI		PCAS, CAS
	; toggle /RAS
	CBI		PRAS, RAS

	; get back
	SBI		PCAS, CAS
	SBI		PRAS, RAS
	RJMP	DRAMREFRESH_LOOP
DRAMREFRESH_END:
	POP		ZH
	POP		ZL
	OUT		SREG, ZL
	POP		ZL
	RETI

/*
	byte(R16) DRAMREAD(int address(R26:R28))
*/
DRAMREAD:
	CLI
	; our RAM has 512kB => 10 addressing lines. Grab bottom 8bits + top 2 bits
	OUT		PORTA, R26 ; addrL
	MOV		R29, R27 ; backup
	ANDI	R29, 0x03
	LSL		R29
	LSL		R29
	OUT		PORTD, R29
	; /RAS
	CBI		PRAS, RAS
	LSR		R27
	LSR		R27 ; R27 >> 2
	LSL		R28 
	LSL		R28 
	LSL		R28 
	LSL		R28 
	LSL		R28 
	LSL		R28 ; R28 << 6
	OR		R27, R28
	OUT		PORTA, R27
	CLR		R26
	OUT		DDRB, R26 ; DDRB = 0x00 (input)
	SER		R26
	OUT		PORTB, R26 ; PORTB = 0xFF (pullups)
	CBI		PCAS, CAS
	NOP
	IN		R16, PINB
	SBI		PCAS, CAS
	SBI		PRAS, RAS
	SEI
	RET

/*
	void DRAMREAD(int address(R26:R28), byte data(R16))
*/
DRAMWRITE:
	CLI
	; our RAM has 512kB => 10 addressing lines. Grab bottom 8bits + top 2 bits
	OUT		PORTA, R26 ; addrL
	MOV		R29, R27 ; backup
	ANDI	R29, 0x03
	LSL		R29
	LSL		R29
	OUT		PORTD, R29
	; /RAS
	CBI		PRAS, RAS
	LSR		R27
	LSR		R27 ; R27 >> 2
	LSL		R28 
	LSL		R28 
	LSL		R28 
	LSL		R28 
	LSL		R28 
	LSL		R28 ; R28 << 6
	OR		R27, R28
	OUT		PORTA, R27
	SER		R26
	OUT		DDRB, R26 ; DDRB = 0xFF (output)
	OUT		PORTB, R16 ; PORTB = data
	CBI		PWE, WE
	NOP
	CBI		PCAS, CAS
	NOP
	SBI		PWE, WE
	SBI		PCAS, CAS
	SBI		PRAS, RAS
	SEI
	RET
