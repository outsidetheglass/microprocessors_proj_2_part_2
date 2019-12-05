@ Code to make the user LEDs of a ARM processor blink
@ first to turn on LEDs 3 and 0
@ if button is pushed
@ then turn on LEDs 2 and 1
@ and repeat that endlessly
@ written by Stephanie "Stevie" Taylor, Dec 2019

.text
.global _start
_start:
	LDR R0,=#0x02 			@ value to write to the clock register
	LDR R1,=0x44E000AC		@ CM_PER_CM_PER_GPIO1_CLKCTRL
	STR R0,[R1] 
	MOV R10,#0				@ counter
	LDR R0,=0x4804C000 		@ lets do this the fun way - starting at the base address for GPIO1 registers
@ Load in values for LEDs high
	MOV R7,#0x01200000 		@ value for turning on high LEDs 3 and 0
	MOV R8,#0x00C00000		@ value for turning on high LEDs 2 and 1
	
	ADD R4,R0,#0x194		@ address for GPIO1_SETDATAOUT
	ADD R3,R0,#0x190		@ address for GPIO1_CLEARDATAOUT
	
	STR R7,[R4]				@ put LED 3 and 0 high value into the set register to turn on
	STR R8,[R3]				@ put LED 2 and 1 high value in to clear them
	
@ Now lets actually initialize the output
	ADD R5,R0,#0x148		@ address for GPIO1_FALLINGDETECT
	LDR R12,[R5]			@ Read current falling detect register
	MOV R11,#0x04000000		@ value for initializing the button
	ORR R12,R12,R11			@ Set bit 26
	STR R12,[R5]			@ set falling detect for button
	ADD R5,R0,#0x34			@ Address for IRQ status register
	STR R11,[R5]			@ enable pointer pend for GPIO1_26 pin
	
	ADD R1,R0,#0x134		@ Register address for GPIO1_OE
	LDR R6,[R1]				@ Read current OE register
	MOV R9,#0xFE1FFFFF		@ enable GPIO1_21 - GPIO1_24
	AND R6,R9,R6			@ Modify word to put back in
	STR R6,[R1]				@ put back in to OE register
	
@ initialize the INTC
	LDR R1,=0x482000E8		@ address of INTC_MIR_CLEAR3
	MOV R2,#0x04			@ value for unmasking
	STR R2,[R1]				@ write to the register
@ enable processor IRQ in CPSR
	MRS R3, CPSR			@ Copy CPSR to R3
	BIC R3,#0x80			@ Clear bit 7
	MSR CPSR_c, R3			@ write back to CPSR
@ Wait for Interrupt
LOOP:	NOP
		B LOOP
INT_DIRECTOR:
@ put code here
@ blink the USR LEDs in the correct order
BLINK:
	STR R7,[R4]				@ put LED 3 and 0 high value into the SETDATAOUT
	STR R8,[R3]				@ put LED 2 and 1 high value into the CLEARDATAOUT
	MOV R10,#0x00400000		@ delay value
	B DELAY1
REDO:
	STR R8,[R4]				@ put LED 2 and 1 high value into the SETDATAOUT
	STR R7,[R3]				@ put LED 3 and 0 high value into the CLEARDATAOUT
	MOV R10,#0x00400000		@ delay value
	B DELAY2
@ loop for 2 seconds
DELAY1:
	SUBS R10,#1				@ countdown
	BNE DELAY1
	B REDO
DELAY2:
	SUBS R10,#1				@ countdown
	BNE DELAY2
	B BLINK			
.END 
