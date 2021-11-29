
--------------------
    RaW-Library

     RWL by PQ
Copyright 2000 by PQ
--------------------

Report bugs, tips & comments to QUISTNET@HETNET.NL


-----------------------------------------------------
This package includes:

RWL-ASM Compiler
 - RWLASM2.EX	-->	ASM Compiler
 - ASM.E	-->	ASM Handling by Pete Eberlein
 - READFIL.E	-->	File Handling
 - MMATCH.E	-->	Multi-Matching

RWL Handling
 - TECH.TXT	-->	Technical information
 - RWL2.E	-->	RWL1 & RWL2 Handling
 - INFO.TXT	-->	Documentation on RWL2.E

Demos
 - TEST1.EX	-->	Example: Test for CONTROL.RWL
 - SPEED.EX	-->	Example: Speed comparison
 - TEST2.EX	-->	Example: Test for CONTROL.RWL
 - CONTROL.ASM	-->	Example: RWL-ASM Source
-----------------------------------------------------

Bug report:
-	Proof that I'm extremely stupid, I assigned a memory adress to an integer.
	(Reported by Caballero Rojo)
-	Name of multiple arguments were taken with 2 letters extra.
-	Removed *= and /= arguments since their not possible that way.
-	Fixed 32-Bit argumenting, NASM told me that e.g. 102d was needed but it isn't.
-	Fixed Push/Pop sequence, wrong combinations.

Why created?
I wanted to have a collection of .COM files which can be
called as a .DLL


Current features:
-	Preprocessor for ASM-Programming.
-	Support for AL,CL,DL,BL,AH,CH,DH,BH,AX,CX,DX,BX,SP,BP,SI,DI argumenting.
-	Return of registers: AL,CL,DL,BL,AH,CH,DH,BH. by default on.
-	Safe switch for pushing and popping registers outside the code, by default on.
-	Possible: Optional 16bit, by default 32bit.
		  16bit calling is currently not supported for some odd reason.
-	PreSettable values of arguments.


To do for next release:
- Better error control
- Better preprocessor

Thanks to:
- RDS, for Euphoria
- Pete Eberlein, for ASM.E
- Jacques Deschenes, for RMCALL.E

