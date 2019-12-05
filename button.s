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
	MOV R11,#0x04000000		@ value for initializing the button
	
	ADD R5,R0,#0x148		@ address for GPIO1_FALLINGDETECT
	ADD R4,R0,#0x194		@ address for GPIO1_SETDATAOUT
	ADD R3,R0,#0x190		@ address for GPIO1_CLEARDATAOUT
	
	STR R11,[R5]			@ set falling detect for button
	STR R7,[R4]				@ put LED 3 and 0 high value into the set register to turn on
	STR R8,[R3]				@ put LED 2 and 1 high value in to clear them
	
@ Now lets actually initialize the output
	ADD R1,R0,#0x134		@ Register address for GPIO1_OE
	LDR R6,[R1]				@ Read current OE register
	MOV R9,#0xFE1FFFFF		@ enable GPIO1_21 - GPIO1_24
	AND R6,R9,R6			@ Modify word to put back in
	STR R6,[R1]				@ put back in to OE register
	B BLINK
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
