# Documentation on RWL2.E

```
global procedure setSafe(integer state)
-- state= 0 or 1
-- Default: 1
-- if SAFE (1) then AX, CX, DX, BX, SP, BP, SI and DI are
--  safely pushed and popped outside the code
```

```
global procedure set16Bit()
-- Uses with parameters 16bit registers and allocates RM-Memory
-- Currently not safe to use
```

```
global procedure set32Bit()
-- Uses with parameters 32bit registers and allocates PM-Memory
-- Default
```

```
global function openRWL(sequence file)
-- Open RWLFile (RWL1 or RWL2)
-- Returns ID of RWL-File
```

```
global function getProcID(integer RWLID,sequence PROCNAME)
-- Returns ID of RWL-Proc
```

```
global function getParmID(integer RWLID,integer PROCID,sequence PARMNAME)
-- Returns ID of Parameter
```

```
global procedure RWLProc2MEM(integer RWLID, integer PROCID)
-- Load RWLProc into Memory (4 Byte Adress)
```

```
global procedure callRWLProc(integer RWLID,object PROC,sequence PARMS)
-- PROC may be sequenced-name or the id
-- PARMS[x][1] may be sequenced-name or the id
-- PARMS[x][2] can be an atom or:
--     Zero-Terminated-String
--     RET-Terminated-String
--     IRET-Terminated-String
-- Call the code
```

```
global procedure presetParms(integer RWLID, object PROC, sequence PARMS)
-- PROC may be sequenced-name or the id
-- PARMS[x][1] may be sequenced-name or the id
-- PARMS[x][2] can be an atom or:
--     Zero-Terminated-String
--     RET-Terminated-String
--     IRET-Terminated-String
-- Pre-Set the proc without calling it
```

```
global function getRWLProc(integer RWLID,object PROC)
-- PROC may be sequenced-name or the id
-- Returns asmstr
```

```
global function getParamNames(integer RWLID,object PROC)
-- PROC may be sequenced-name or the id
-- Return list
```

```
global function getProcNames(integer RWLID)
-- Return list
```

```
global function getRegs()
-- Returns state of registers:
-- {AL,CL,DL,BL,AH,CH,DH,BH}
```
