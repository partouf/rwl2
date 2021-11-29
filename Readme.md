# RaW-Library
## RWL by PQ
### Copyright 2000 by PQ

Don't report bugs, tips & comments, because this is super old.

# This package includes

## RWL-ASM Compiler
 - RWLASM2.EX	-->	ASM Compiler
 - ASM.E	-->	ASM Handling by Pete Eberlein
 - READFIL.E	-->	File Handling
 - MMATCH.E	-->	Multi-Matching

## RWL Handling
 - TECH.TXT	-->	Technical information
 - RWL2.E	-->	RWL1 & RWL2 Handling
 - INFO.TXT	-->	Documentation on RWL2.E

## Demos
 - TEST1.EX	-->	Example: Test for CONTROL.RWL
 - SPEED.EX	-->	Example: Speed comparison
 - TEST2.EX	-->	Example: Test for CONTROL.RWL
 - CONTROL.ASM	-->	Example: RWL-ASM Source


# Why?
I wanted to have a collection of .COM files which can be
called as a .DLL


# Current features
-	Preprocessor for ASM-Programming.
-	Support for AL,CL,DL,BL,AH,CH,DH,BH,AX,CX,DX,BX,SP,BP,SI,DI argumenting.
-	Return of registers: AL,CL,DL,BL,AH,CH,DH,BH. by default on.
-	Safe switch for pushing and popping registers outside the code, by default on.
-	Possible: Optional 16bit, by default 32bit.
		  16bit calling is currently not supported for some odd reason.
-	PreSettable values of arguments.


# Thanks to
- RDS, for Euphoria
- Pete Eberlein, for ASM.E
- Jacques Deschenes, for RMCALL.E
