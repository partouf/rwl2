# RaW Library Technical Notes

### Notes:
* All numbers here are Decimals
* \*  means Optional


# RWL File Structures

## RWL1

```
Offset	Length	Description		Example
--------------------------------------------------
1	4	Header			"RWL1"
5	1	Number of procedures	2

*6	8	1st ProcName		"HideMSE "
*14	1	Length of procstring	6
*15	[14]	Procedure String	{201,184,2,0,205,51}

*6	8	2nd ProcName		"ShowMSE "
*14	1	Length of procstring	6
*15	[14]	Procedure String	{201,184,1,0,205,51}
```

## RWL2
```
Offset	Length	Description		Example
--------------------------------------------------
1	4	Header			"RWL2"
5	1	Number of Procedures	2

*6	8	1st ProcName		"ModeIt  "
*14	1	Number of Parameters	1
**15	3	1st Param Name		"MDE"
**18	1	Parameter type		184
*19	1	Length of procstring	2
*20	[19]	Procedure String	{205,16}

*21	8	2nd ProcName		"Mouse   "
*29	1	Number of Parameters	1
**30	3	1st Param Name		"HSM"
**33	1	Parameter Type		184
*34	1	Length of procstring	2
*35	[34]	Procedure String	{205,51}
```


## Parameter Types (32b)
```
ID	Name	Machine string	Meaning
--------------------------------------------------
176	AL	{176,0}		MOV AL,0
177	CL	{177,0}		MOV CL,0
178	DL	{178,0}		MOV DL,0
179	BL	{179,0}		MOV BL,0

180	AH	{180,0}		MOV AH,0
181	CH	{181,0}		MOV CH,0
182	DH	{182,0}		MOV DH,0
183	BH	{183,0}		MOV BH,0

184	AX	{184,0,0,0,0}	MOV EAX, #0000:0000
185	CX	{184,0,0,0,0}	MOV ECX, #0000:0000
186	DX	{184,0,0,0,0}	MOV EDX, #0000:0000
187	BX	{184,0,0,0,0}	MOV EBX, #0000:0000

188	SP	{188,0,0,0,0}	MOV ESP, #0000:0000
189	BP	{189,0,0,0,0}	MOV EBP, #0000:0000
190	SI	{190,0,0,0,0}	MOV ESI, #0000:0000
191	DI	{191,0,0,0,0}	MOV EDI, #0000:0000
```


## RWL-ASM Stucture
```
//		Commenting Inside & Outside Procedures
```

### NON-ARGUMENTED PROCEDURES (RWL1-ASM & RWL2-ASM)
```
proc		Anounce Procedure folowed by
 [NAME]		Name, length<=8
 :		End of Procedure anouncement
end proc	End of Procedure
```

### ARGUMENTED PROCEDURES (RWL2-ASM)
```
proc		Anounce Procedure folowed by
 [NAME]		Name, length<=8
 (		Argument Anouncement
  [REG]		Register Name (E.G. AX)
  [NAME]	Argument Name, Length=3
  ,		Optional argument separation
 )		End of Arguments
 :		End of Procedure anouncement
end proc	End of Procedure
```

### PREPROCESSOR TRANSLATIONS
```
SYMBOL	MEANING		EG.		MEANING
---------------		--------------------------
:=	MOV		AX:=1		MOV AX,1
+=	ADD		AX+=1		ADD AX,1
-=	SUB		AX-=BX		SUB AX,BX

==	LEA		EAX==[EAX*2]	LEA EAX,[EAX*2]
<>	XCHG		AX<>BX		XCHG AX,BX
```

### PREPROCESSOR EQUATIONS
```
STRUCTURE
---------
(		Begin equation
 [X]		Value or name
 [Equation]	Equation
 [X]		Value or name
)		End equation
[Name Label]	Jump if equation is true
```

### EQUATIONS
```
SYMBOL	MEANING
---------------
=	JE	(Equal)
!=	JNE	(Not Equal)
<	JB	(Below)
<=	JBE	(Below or Equal)
>	JA	(Above)
>=	JAE	(Above or Equal)
```

### MULTIPLE MEANING TRANSLATIONS
```
SYMBOL	MEANING		EG.		MEANING
---------------		--------------------------
++	ADC		AX++BX		ADC AX,BX
++	INC		++BX		INC BX
--	SBB		BX--AX		SBB BX,AX
--	DEC		--AX		DEC AX
```
