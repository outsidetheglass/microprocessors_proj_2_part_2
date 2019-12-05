.text
.global _start
_start:
	MOV R7, #0x00C00000		@ load value for turning LEDs 2 and 1 on first
	@ TODO MOV R7,#0x01200000 		@ value for turning on high LEDs 3 and 0
	@ TODO MOV R8,#0x00C00000		@ value for turning on high LEDs 2 and 1
	ADD R7,R7,#0x00600000	@ add to get value for setting LEDs 3 and 0
	TST R7,#0x01200000
	BNE BLINK03
	BEQ BLINK12
BLINK03:
		NOP	
BLINK12:
		NOP
.END