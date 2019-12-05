@ Code to make the user LEDs of a ARM processor blink
@ first to turn on LEDs 3 and 0
@ if button is pushed
@ then turn on LEDs 2 and 1
@ if button is pushed turn on LEDs 3 and 0 
@ and repeat that endlessly
@ written by Stephanie "Stevie" Taylor, Dec 2019

.text
.global _start
.global INT_DIRECTOR
_start:
	MOV R10,#0				@ counter for the delay loop
@ Stack stuff
	LDR R13,=STACKSVC		@ point to base of stack for SVC mode
	ADD R13,R13,#0x1000		@ point to top of stack
	CPS #0x12				@ Switch to IRQ mode
	LDR R13,=STACKIRQ		@ point to IRQ stack
	ADD R13,R13,#0x1000		@ now to the top of the IRQ stack
	CPS #0X13				@ Back to SVC mode
@ clock stuff
	LDR R0,=#0x02 			@ value to write to the clock register
	LDR R1,=0x44E000AC		@ CM_PER_CM_PER_GPIO1_CLKCTRL
	STR R0,[R1] 			@ write to register
	LDR R0,=0x4804C000 		@ lets do this the fun way - starting at the base address for GPIO1 registers
@ Load in values for LEDs high
	MOV R7, #0x00C00000		@ load value for turning LEDs 2 and 1 on first
	@ #0x01200000 is value for turning on high LEDs 3 and 0
	@ #0x00C00000 is value for turning on high LEDs 2 and 1
	
	ADD R4,R0,#0x194		@ address for GPIO1_SETDATAOUT
	ADD R3,R0,#0x190		@ address for GPIO1_CLEARDATAOUT
	
	STR R7,[R4]				@ put LED 1 and 2 high value into the set register to turn on
	ADD R7,R7,#0x00600000	@ add to get value for setting LEDs 3 and 0
	STR R7,[R3]				@ put LED 3 and 0 high value in to clear them
	@ at this point R7 holds the value for LED 3 and 0 high

	ADD R1,R0,#0x134		@ Register address for GPIO1_OE
	LDR R6,[R1]				@ Read current OE register
	MOV R9,#0xFE1FFFFF		@ enable GPIO1_21 - GPIO1_24
	AND R6,R9,R6			@ Modify word to put back in
	STR R6,[R1]				@ put back in to OE register
	
@ Now lets actually initialize the output
	ADD R5,R0,#0x14C		@ address for GPIO1_FALLINGDETECT
	LDR R12,[R5]			@ Read current falling detect register
	MOV R11,#0x20000000		@ value for initializing the button
	ORR R12,R12,R11			@ Set bit 26
	STR R12,[R5]			@ set falling detect for button
	ADD R5,R0,#0x34			@ Address for IRQ status register
	STR R11,[R5]			@ enable pointer pend for GPIO1_26 pin
	
@ initialize the INTC
	LDR R5,=0x482000E8		@ address of INTC_MIR_CLEAR3
	MOV R12,#0x04			@ value for unmasking
	STR R12,[R5]				@ write to the register
	
@ enable processor IRQ in CPSR
	MRS R12, CPSR			@ Copy CPSR to R12
	BIC R12,#0x80			@ Clear bit 7
	MSR CPSR_c, R12			@ write back to CPSR
	
@ Wait for Interrupt
LOOP:	NOP
		B LOOP
INT_DIRECTOR:
	STMFD SP!, {R0-R3, LR}	@ push registers to my stack
	LDR R0,=0x482000F8		@ address of INTC-PENDING_IRQ3 register
	LDR R1,[R0]				@ read the current value of INTC-PENDING_IRQ3
	TST R1,#0x00000004		@ test bit 2
	BEQ PASS_ON				@ Not from GPIO INT1A so go back to the pass on loop
	LDR R0,=0x04000000		@ else it is from GPIOINT1A, check if bit 26 is 1 
	BNE BUTTON_SVC			@ if it is 1, then button pushed and go to button svc loop
	BEQ PASS_ON				@ if it is not 1, then go back to wait loop
PASS_ON:
	LDMFD SP!, {R0-R3,LR}	@ restore registers
	SUBS PC, LR, #4			@ pass execution to the wait loop
BUTTON_SVC:
	MOV R1,#0x04000000		@ value turns off GPIO1_26 and INTC interrupt requests - turning our "phone ringer" off
	STR R1,[R0]				@ write to GPIO1_IRQSTATUS0 register
	
@ handle responding to new IRQ
	LDR R0,=0x48200048		@ address of INTC_CONTROL register
	MOV R1, #01				@ Value to clear bit 0
	STR R1,[R0]				@ Write to INTC_CONTROL register
	
@ toggle logic
	TST R7,#0x01200000		@ if current R7 address means LEDs 3 and 0 are on 
	BNE BLINK12				@ then branch into the procedure for switching to LEDs 2 and 1 on
	BEQ BLINK03				@ else turn on BLINK03

@ if the code gets here, that means R7 is neither representing LEDs 3 and 0 or LEDs 2 and 1 being on
@ so lets turn one set on here, just to be safe
	MOV R7, #0x00C00000		@ load value for turning LEDs 2 and 1 on first
	B BLINK03				@ then branch into the procedure for switching to LEDs 3 and 0 on

@ blink the USR LEDs 3 and 0
BLINK03:
	STR R7,[R3]				@ put LED 2 and 1 high value into the CLEARDATAOUT
	ADD R7,R7,#0x00600000	@ add to get value for setting LEDs 3 and 0
	STR R7,[R4]				@ put LED 3 and 0 high value into the SETDATAOUT		
	MOV R10,#0x00400000		@ delay value
	B DELAY
	
@ blink the USR LEDs 2 and 1
BLINK12:
	STR R7,[R3]				@ put LED 3 and 0 high value into the CLEARDATAOUT
	SUB R7,R7,#0x00600000	@ subtract to get value for setting LEDs 1 and 2	
	STR R7,[R4]				@ put LED 2 and 1 high value into the SETDATAOUT
	MOV R10,#0x00400000		@ delay value
	B DELAY
@ loop for 2 seconds
DELAY:
	SUBS R10,#1				@ countdown
	BNE DELAY
	@ branch to wait for interrupt loop
	LDMFD SP!, {R0-R3,LR}	@ restore registers
	SUBS PC, LR, #4			@ return from IRQ interrupt procedure
.align 2
SYS_IRQ:	.WORD 0			@ location for system's IRQ address
.data
.align 2
STACKSVC:	.rept 1024
			.word 0x0000
			.endr
STACKIRQ:	.rept 1024
			.word 0x0000
			.endr
.END 
