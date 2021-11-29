

// Video Routines at Int 10h
// MDE=
//	E.G.
//	#00 v 0		Mode 0
//	#12 v 18	Mode 18
//	#13 v 19	Mode 19
//	#101 v 257	Mode 257
proc ModeIt(AX MDE):
	INT #10
end proc


// Mouse Routines at Int 33h
// HSM=
//	#01		Show Mouse
//	#02		Hide Mouse
proc Mouse(AX HSM):
	INT #33
end proc


// Fast pixel proc for mode 13h (19d)
// btw, #A0000 / 8 = #14000
// XXX = X-Coord	EBX
// YYY = Y-Coord	EDX
// CCC = Color		CL
proc Pixel13h(BX XXX,DX YYY,CL CCC):
	EDX==[EDX+EDX*4]	// LEA EDX,[EDX+EDX*4]
	EDX==[EDX*8+#14000]	// LEA EDX,[EDX*8+#14000]
	[EBX+EDX*8]:=CL		// MOV [EBX+EDX*8],CL
end proc


// Set Current Drive to DL(DRV)
// DRV: 0-25 or 'A'-'Z' or 'a'-'z'
proc SetDRV(DL DRV):
	(DL<=25)DoIt		// If DL<=25 goto DoIt
	(DL<=57)STRA		// If DL<='9' goto STRA
	(DL>=65)BIGA		// If DL>='A' goto BIGA
	JMP Error
STRA:
	(DL>=48)STR		// If DL>='0' goto STR
	JMP Error
STR:
	DL-=48			// DL=DL-'0'
	JMP DoIt
BIGA:
	(DL<=90)BIG		// If DL<='Z' goto BIG
	(DL>=97)SMLA		// If DL>='a' goto SMLA
	JMP Error
SMLA:
	(DL<=122)SMALL		// If DL<='z' goto SMALL
	JMP Error
SMALL:
	DL-=97			// DL=DL-'a'
	JMP DoIt
BIG:
	DL-=65			// DL=DL-'A'
DoIt:
	AH:=#0E			// AH=#0E
	INT #21			// Call Int #21
Error:
end proc


// CopyTXT(Source-Adress,Destination-Adress)
// Original: CALLMACH.EX
proc CopyTXT(AX SRC,DX DES):
L1:
	BL:=[EAX]		// MOV BL,[AX]	// BL=peek(AX)
	(BL=0)Exit		// CMP BL,0	// if BL=0 then Exit
				// JE Exit
	[EDX]:=BL		// MOV [DX],BL	// poke(DX,BL)
	++EAX			// INC AX	// AX+=1
	++EDX			// INC DX	// DX+=1
	JMP L1			// JMP L1
Exit:
end proc

proc Puts2(SI TXT,DI DES,CL CLR,DH XXX,DL YYY):
	JMP Init
ADDIT:			// EDI+=DH
	(DH=0)L1
	--DH
	++EDI
	JMP ADDIT
Init:
	EAX:=160	// EAX=80*2=160
	MUL DL		// EAX*=DL
	SHL DH,1	// DH*=2
	EDI+=EAX
	XOR EAX,EAX	// EAX=0
	CLD		// Clear Direction
	AH:=CL
	JMP ADDIT
L1:
	LODSB
	(AL=0)Exit	// if AL=0 then Exit()
	STOSW
	JMP L1
Exit:
end proc


proc ClearAll:
	INT #11		// Get Equipment
	AND AL,24	// Bit 4 and 5 checked means 80*25 Mono Text
	(AL=24)Mono
Color:
	EDI:=#B8000	// EDI:=VIDEO_ADRESS_TEXT&COLOR
	JMP Begin
Mono:
	EDI:=#B0000	// EDI:=VIDEO_ADRESS_TEXT&MONO
Begin:
	ECX:=2000	// Set counter to 2000 (25*80*2)
	AL:=32		// AL=' '
	AH:=7		// AH=White_on_Black
	CLD		// Clear Direction: Forward
	REP STOSW	// Repeat StoreStringWord {AL,AH}, CX-times
end proc


