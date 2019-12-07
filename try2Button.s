.text
.global _start
.global INT_DIRECTOR
_start:
@ stack logic
	LDR R13, =STACK1		@ point to base of stack1
	ADD R13, R13, #0x1000
	CPS #0x12
	LDR R13, =STACK2		@ point to base of stack2
	ADD R13, R13, #0x1000
	CPS #0x13
@ turn on GPIO1 clock
	LDR R0, =#0x02
	LDR R1, =0x44E000AC
	STR R0, [R1]
@ GPIO registers and their logic
	LDR R11, =0x4804C000 	@ base address for GPIO1
	MOV R4, #0xC00000		@ high value for LEDs 2 and 1
	STR R4, [R11, #0x190]	@ store LEDs 2 and 1 high value into EA = base address + CLEARDATAOUT offset 
	ADD R4, R4, #0x600000	@ value for increasing R7 to LEDs 3 and 0 high
	STR R4, [R11, #0x194]	@ store LEDs 3 and 0 high value into base address + SETDATAOUT offset 
@ GPIO1_OE logic for USR LEDS 0 through 3
	LDR R5, =0xFE1FFFFF
	STR R5, [R11, #0x0134]
@ set up GPIO_FALLINGEDGE
	MOV R2,	#0x20000000
	STR R2, [R11, #0x14C]	@ store high for pin 29 into EA = base address + FALLINGEDGE offset
	
@ use IRQ, POINTER PEND 1
	STR R2,[R11, #0x2C]			@ enable pointer pend for GPIO1_29 pin
@ initialize INTC
	LDR R1, =0x48200010		@ new base address, for INTC_CONFIG
	MOV R3, #0x2			@ reset INTC_CONFIG register
	STR R3, [R1]			@ write the value in to EA = base address + INTC_CONFIG offset
	MOV R2, #0x04			@ unmasking value
	STR R2, [R1, #0xD8]		@ write unmasking value in to EA of offset for MIR_CLEAR3 = INTC_CONFIG + D8
@ CPSR enable for IRQ
	MRS R3, CPSR			@ copy CPSR to R3
	BIC R3, #0x80			@ clear bit 7
	MSR CPSR_c, R3			@ write to CPSR	
@ loop blinking LEDs 1 and 2 til we get interrupted, 
@ on interruption switch to blinking LEDS 3 and 0, and so on
BLINK_OFF:
	STR R4,[R11, #0x190]	@ put LEDs high value into the CLEARDATAOUT
	MOV R5,#0x000000004		@ delay value 1 second
	B DELAY1
BLINK_ON:
	STR R4,[R11, #0x194]	@ put LEDs high value into the SETDATAOUT
	MOV R5,#0x00000004		@ delay value 1 second
	B DELAY2
@ loop for 1 second
DELAY1:
	SUBS R5,#1				@ countdown
	BNE DELAY1
	B BLINK_ON
DELAY2:
	SUBS R5,#1				@ countdown
	BNE DELAY2
	B BLINK_OFF		

@ IRQ for the button
INT_DIRECTOR:
	STMFD SP!, {R0-R3, LR}	@ push registers on stack
CHECK_INTC:
	LDR R0,=0x482000F8		@ address for INTC PENDING IRQ3 register
	LDR R2,[R0]				
	TST R2,#0x4				@ test R2 against unmask
	BNE CHECK_GPIO			@ go to check button if so
	B	PASS_ON				@ else go to pass on
CHECK_GPIO:	
	LDR R2, [R11, #0x2C]	@ check IRQ
	TST R2, #0x2			@ test it is equal
	BNE BUTTON_SVC			@ if so, go to button service
	B PASS_ON				@ else go to pass on
PASS_ON:
	LDR R0, =0x48200048		@ Address of INTC_CONTROL register
	MOV R1, #0x1				@ Value to clear bit 0
	STR R1, [R0]				@ Write to INTC_CONTROL register
	LDMFD SP!, {R0-R3, LR}	@ restore registers
	SUBS PC, LR, #4			@ Pass execution to blinking loop	
BUTTON_SVC:
	@ turn off IRQ request
	MOV R2, #0x40000000			@ turn off ringer value
	STR R2, [R11, #0x2C]			@ ringer off value put into IRQ
	
	@ turn off bit in INTC_CONTROL
	LDR R0, =0x48200048		@ Address of INTC_CONTROL register
	MOV R1, #0x1			@ Value to clear bit 0
	STR R1, [R0]			@ Write to INTC_CONTROL register
	LDR R2, [R0, #0x13C]	
	TST R2, #0x1			@ test if LEDs 3 and 0 are on
	BNE BLINK_21			@ if so, start blinking LEDs 2 and 1
	STR R2, [R1]				
	B BLINK_30				@ else start blinking LEDs 3 and 0
BLINK_21:
	STR R4, [R11, #0x190]	@ first set LEDs 3 and 0 to off
	SUB R4, R4, #0x600000	@ then move value to LED 2 and 1 high
	B BLINK_OFF				@ and branch to blinking loops
BLINK_30:
	STR R4, [R11, #0x190]	@ first set LEDs 2 and 1 to off
	ADD R4, R4, #0x600000	@ then move value to LED 3 and 0 high
	B BLINK_OFF				@ and branch to blinking loops

.data
.align 2
STACK1:	.rept 1024
	.word 0x0000
	.endr
STACK2:	.rept 1024
	.word 0x0000
	.endr
.END