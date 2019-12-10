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
	MOV R4, #0x00C00000		@ high value for LEDs 2 and 1
	STR R4, [R11, #0x190]	@ store LEDs 2 and 1 high value into EA = base address + CLEARDATAOUT offset 
	ADD R5, R4, #0x00600000	@ value for increasing R4 to LEDs 3 and 0 high
	STR R5, [R11, #0x194]	@ store LEDs 3 and 0 high value into base address + SETDATAOUT offset 
@ GPIO1_OE logic for USR LEDS 0 through 3
	LDR R6, =0xFE1FFFFF
	STR R6, [R11, #0x134]
@ set up GPIO_FALLINGEDGE
	MOV R2,	#0x20000000
	STR R2, [R11, #0x14C]	@ store high for pin 29 into EA = base address + FALLINGEDGE offset
	
@ use IRQ, POINTER PEND 1
	STR R2,[R11, #0x34]			@ enable pointer pend for GPIO1_29 pin
@ initialize INTC
	LDR R1, =0x48200010		@ new base address, for INTC_CONFIG
	MOV R3, #0x2			@ reset INTC_CONFIG register
	STR R3, [R1]			@ write the value in to EA = base address
	MOV R2, #0x04			@ unmasking value
	STR R2, [R1, #0xD8]		@ write unmasking value in to EA of offset for MIR_CLEAR3 = INTC_CONFIG + D8
	
@ CPSR enable for IRQ
	MRS R3, CPSR			@ copy CPSR to R3
	BIC R3, #0x80			@ clear bit 7
	MSR CPSR_c, R3			@ write to CPSR	
	
@ flag bit for if LEDs blinking are on or not
	MOV R10, #0x01			@ 1 is on, 0 is off


@ From here, loop blinking LEDs 1 and 2 and then LEDS 3 and 0, and so on

@ this first tests if the flag bit is set

@ if flag is set, then go into BLINK_30 and blink LEDs 3 and 0
@ then delay 2 seconds with DELAY1
@ then go to BLINK_21 and blink LEDs 2 and 1
@ then use DELAY2 to delay another 2 seconds, then go back to BLINK_30
@ repeat this until interrupted

@ if flag is not set, then go to LEDS_OFF
@ run a delay in DELAY3 to keep them off while waiting for an interrupt

LOOP:
	NOP
	TST R10, #0x01			@ test if LEDs blinking is set right now
	BEQ LEDS_OFF			@ if they are blinking, turn them off
	BNE BLINK_21			@ if they aren't, pass this and go into Blinking
BLINK_21:
	STR R5, [R11, #0x190]	@ first set LEDs 3 and 0 to off
	STR R4, [R11, #0x194]	@ put LEDs 2 and 1 high value into the SETDATAOUT
	MOV R6, #0x00400000		@ delay  
	B DELAY1				@ then go delay 
DELAY1:
	TST R10, #0x01			@ test if LEDs blinking is set right now
	BEQ LEDS_OFF			@ if they are blinking, turn them off
	SUBS R6,#1				@ countdown
	BNE DELAY1
	B BLINK_30
BLINK_30:
	STR R4, [R11, #0x190]	@ first set LEDs 2 and 1 to off
	STR R5, [R11, #0x194]	@ put LEDs 3 and 0 high value into the SETDATAOUT
	MOV R6, #0x00400000		@ delay 
	B DELAY2				@ then go delay
DELAY2:
	SUBS R6,#1				@ countdown
	BNE DELAY2
	B LOOP	
	
LEDS_OFF:
	MOV R9, #0x01E00000		@ all USR LEDS high value 
	STR R9, [R11, #0x190]	@ put LEDs high value into the CLEARDATAOUT
	MOV R6, #0x00400000		@ delay
	B DELAY3
DELAY3:
	SUBS R6,#1				@ countdown
	BNE DELAY3
	MOV R6, #0x00000400
	TST R10, #0x01			@ test if LEDs blinking is set right now
	BNE BLINK_21			@ if they aren't, pass this and go into Blinking
	B DELAY3	
	B LOOP	

@ IRQ for the button
INT_DIRECTOR:
	STMFD SP!, {R0-R3, LR}	@ push registers on stack
CHECK_INTC:
@ base address for the INTC
	LDR R0,=0x48200000
	LDR R2, [R0, #0xF8]		@ read into R2 from the EA of base address + INTC PENDING IRQ3 register offset		
	TST R2, #0x4				@ test R2 against unmask
	BNE CHECK_GPIO			@ go to check button if so
	BEQ	PASS_ON				@ else go to pass on
CHECK_GPIO:	
	LDR R2, [R11, #0x2C]	@ check IRQ
	TST R2, #0x20000000		@ test it is equal
	BNE BUTTON_SVC			@ if so, go to button service
	B PASS_ON				@ else go to pass on
PASS_ON:
	LDMFD SP!, {R0-R3, LR}	@ restore registers
	SUBS PC, LR, #4			@ Pass execution to blinking loop	
BUTTON_SVC:
	@ turn off IRQ request
	MOV R2, #0x20000000		@ turn off ringer value
	STR R2, [R11, #0x2C]	@ ringer off value put into GPIO1_IRQSTATUS
	MOV R1, #0x01			@ to clear bit 0
	STR R1, [R0, #0x48]		@ ringer off value write to INTC_control
	TST R10, #0x01			@ test if LEDs blinking is set right now
	BNE TURN_OFF			@ if so, turn blinking LEDs off
	BEQ TURN_ON				@ and go to pass on
TURN_OFF:
	MOV R10, #0x00			@ set flag bit to show LEDs are off
	B PASS_ON
TURN_ON:
	MOV R10, #0x01			@ set flag bit to show LEDs are off
	B PASS_ON @ LIGHT instead of PASSON
@ DELAY loop
	@ Check IRQ status_0
	@ read it
	@ test for button push
	@ BNE go to button SVC
	@ BEQ goes to outside lights (3 and 0)
	@ else go to inside lights (2 and 1)
	@ 



.data
.align 2
STACK1:	.rept 1024
	.word 0x0000
	.endr
STACK2:	.rept 1024
	.word 0x0000
	.endr
.END