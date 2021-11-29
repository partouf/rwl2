--
-- RWL-Library Support
--
-- * Completely rewritten
-- * RWL1 & RWL2 Support
--
-- Copyright 2000 by PQ
--

without warning

include machine.e
include rmcall.e


-- Supported registers for argumenting
constant REG=
{
	{"AL",{176,0}},
	{"CL",{177,0}},
	{"DL",{178,0}},
	{"BL",{179,0}},

	{"AH",{180,0}},
	{"CH",{181,0}},
	{"DH",{182,0}},
	{"BH",{183,0}},

	{"AX",{184,0,0,0,0}},
	{"CX",{185,0,0,0,0}},
	{"DX",{186,0,0,0,0}},
	{"BX",{187,0,0,0,0}},

	{"SP",{188,0,0,0,0}},
	{"BP",{189,0,0,0,0}},
	{"SI",{190,0,0,0,0}},
	{"DI",{191,0,0,0,0}}
}

atom regdump
regdump=0

sequence RWLLIST
RWLLIST={}

integer BIG,RET,SAFE
BIG=1					-- 32bit argumenting and adressing ON
RET=1					-- Return registers ON
SAFE=1					-- Push and Pop outside coding ON

global sequence MEMLIST			-- List of Memory adresses to be cleared
MEMLIST={}

------------------------------------------
global procedure set16Bit()		-- Let RWL2.E use 16bit arguments and adresses
 BIG=0
end procedure

global procedure set32Bit()		-- Let RWL2.E use 32bit arguments and adresses
 BIG=1
end procedure

global procedure setReturn(integer state)	-- Set return registest ON(1)/OFF(0)
 RET=state
end procedure

global procedure setSafe(integer state)		-- Set safe ON(1)/OFF(0)
 SAFE=state
end procedure
------------------------------------------

procedure initRegDump()
 if BIG then
  regdump=allocate(8)
  MEMLIST=append(MEMLIST,regdump)
 else
  regdump=allocate_low(8)
  MEMLIST=append(MEMLIST,regdump)
 end if
end procedure

function getRegInfo(integer regid)
 if regid>=184 and regid<=191 then
  if BIG then
   return {{regid,0,0,0,0},{1,4}}
  else
   return {{regid,0,0},{1,2}}
  end if
 end if
 return {{regid,0},{1,1}}
end function

function trimspace(sequence str)
 for a=length(str) to 1 by -1 do
  if str[length(str)]=32 then
   str=str[1..length(str)-1]
  else
   exit
  end if
 end for
return str
end function

function processParms(sequence rwlstr)		-- Process & Implement parameters
integer cnt				-- Param place-count
sequence tmp,trc
 for proc=1 to length(rwlstr) do			-- Loop for Procs
  cnt=0
  for parm=1 to length(rwlstr[proc][3]) do			-- Loop for Parms
   for a=1 to length(REG) do					-- Loop for RegisterCheck
    if rwlstr[proc][3][parm][2]=REG[a][2][1] then				-- If it matches
     tmp=getRegInfo(REG[a][2][1])
     trc=rwlstr[proc][2][1..cnt]&tmp[1]&rwlstr[proc][2][cnt+1..length(rwlstr[proc][2])]
     rwlstr[proc][2]=rwlstr[proc][2][1..cnt]&tmp[1]&rwlstr[proc][2][cnt+1..length(rwlstr[proc][2])]
     trc={cnt+tmp[2][1],tmp[2][2]}
     rwlstr[proc][3][parm][2]={cnt+tmp[2][1],tmp[2][2]}
     cnt+=length(tmp[1])
     exit
    end if
   end for
  end for
 end for
return rwlstr
end function

function processRWL(sequence str)		-- Process RWL-String to readable-structure
sequence	str2				-- Destination string
integer	cnt					-- Position-Counter
cnt=1
str2={}
 if equal(str[1..4],"RWL1") then		-- If it's a RWL1
  cnt+=4
  str2=repeat({"",{},{}},str[cnt])			-- Number of Procs
  cnt+=1
  for proc=1 to length(str2) do			-- Loop for Procs
   str2[proc][1]=trimspace(str[cnt..cnt+7])			-- Name of Proc
   cnt+=8
   str2[proc][2]=str[cnt+1..cnt+1+str[cnt]]			-- Store string
   cnt+=str[cnt]+1
  end for
 elsif equal(str[1..4],"RWL2") then		-- If it's a RWL2
  cnt+=4
  str2=repeat({"",{},{}},str[cnt])			-- Number of Procs
  cnt+=1
  for proc=1 to length(str2) do				-- Loop for Procs
   str2[proc][1]=trimspace(str[cnt..cnt+7])			-- Name of Proc
   cnt+=8
   str2[proc][3]=repeat({"",0},str[cnt])			-- Number of parameters
   cnt+=1
   for a=1 to length(str2[proc][3]) do			-- Loop for Params
    str2[proc][3][a][1]=str[cnt..cnt+2]				-- Name of Param
    str2[proc][3][a][2]=str[cnt+3]				-- Register
    cnt+=4
   end for
   str2[proc][2]=str[cnt+1..cnt+str[cnt]]			-- Store string
   cnt+=str[cnt]+1
  end for
 end if
str2=processParms(str2)
return str2
end function

procedure setParm(integer RWLID,integer PROCID,integer PARMID,object value)
object tmp
--   0 (#00): Zero-Terminated-String
-- 195 (#C3): RET
-- 207 (#CF): IRET
 if sequence(value) then
  if value[length(value)] !=0 and value[length(value)] !=195 and value[length(value)] !=207 then
   value&=0
  end if
  tmp=value
  if BIG then
   value=allocate(length(value))
   MEMLIST=append(MEMLIST,value)
  else
   value=allocate_low(length(value))
   MEMLIST=append(MEMLIST,value)
  end if
  if value !=0 then
   poke(value,tmp)
  end if
 end if
 tmp=int_to_bytes(value)
 tmp=tmp[1..RWLLIST[RWLID][PROCID][3][PARMID][2][2]]
 poke(RWLLIST[RWLID][PROCID][2]+RWLLIST[RWLID][PROCID][3][PARMID][2][1],tmp)
end procedure

------------------------------------------
--	     Global routines		--
------------------------------------------

global function openRWL(sequence file)		-- Open RWLFile
sequence	str				-- File Content string
integer	char,				-- Buffer Char
	hnd				-- File id
str=""
 hnd=open(file,"rb")				-- Open file to read-bytes it
 if hnd !=-1 then				-- If file exist
  char=getc(hnd)				-- Read first char of file
  while char !=-1 do				-- Loop to read file
   str&=char					-- Add char to string
   char=getc(hnd)					-- Read next char of file
  end while
  close(hnd)				-- Close File
 end if
 if length(str) then				-- If there is content
  RWLLIST=append(RWLLIST,processRWL(str))	-- Add Processed RWL-String to RWL-List
  return length(RWLLIST)			-- Return RWL-ID
 else
  return 0					-- Error, no content or does not exist
 end if
end function


global function getProcID(integer RWLID,sequence PROCNAME)
 for a=1 to length(RWLLIST[RWLID]) do
  if equal(RWLLIST[RWLID][a][1],PROCNAME) then
   return a
  end if
 end for
 return 0
end function

global function getParmID(integer RWLID,integer PROCID,sequence PARMNAME)
 for a=1 to length(RWLLIST[RWLID][PROCID][3]) do
  if equal(RWLLIST[RWLID][PROCID][3][a][1],PARMNAME) then
   return a
  end if
 end for
 return 0
end function

global procedure RWLProc2MEM(integer RWLID, integer PROCID)
atom memadr,size
sequence adr,str,tmp,BEGINNING,ENDING,RETURN
 if sequence(RWLLIST[RWLID][PROCID][2]) then

  if regdump=0 then
   initRegDump()
   if regdump=0 then
    return
   end if
  end if
  adr=int_to_bytes(regdump)
  tmp=getRegInfo(191)
  str=tmp[1][1..tmp[2][1]]&adr[1..tmp[2][2]]

  BEGINNING={}
  ENDING={}
  if SAFE then
   for a=1 to 8 do
    BEGINNING&=#50+a-1		-- PUSH AX, BX, CX, DX, SP, BP, SI, DI
    ENDING&=#58+8-a		-- POP DI, SI, BP, SP, DX, CX, BX, AX
   end for
  end if

  if RET then
   RETURN=str&{#AA}&{#88,#C8,#AA}&
	{#88,#D0,#AA}&{#88,#D8,#AA}&{#88,#E0,#AA}&
	{#88,#E8,#AA}&{#88,#F0,#AA}&{#88,#F8,#AA}
  else
   RETURN={}
  end if

  size=length(RWLLIST[RWLID][PROCID][2])
  if RWLLIST[RWLID][PROCID][2][size] !=195 then
   RWLLIST[RWLID][PROCID][2]=
   BEGINNING&
   RWLLIST[RWLID][PROCID][2]&
   RETURN&
   ENDING&195
  else
   RWLLIST[RWLID][PROCID][2]=
   BEGINNING&
   RWLLIST[RWLID][PROCID][2][1..size-1]&
   RETURN&
   ENDING&195
  end if

  --  fixParms() --
  for a=1 to length(RWLLIST[RWLID][PROCID][3]) do
   RWLLIST[RWLID][PROCID][3][a][2][1]+=length(BEGINNING)
  end for
  -----------------

  size=length(RWLLIST[RWLID][PROCID][2])
  if BIG then
   memadr=allocate(size)
   MEMLIST=append(MEMLIST,memadr)
  else
   memadr=allocate_low(size)
   MEMLIST=append(MEMLIST,memadr)
  end if
  if memadr !=0 then
   poke(memadr,RWLLIST[RWLID][PROCID][2])
  end if
  RWLLIST[RWLID][PROCID][2]=memadr
 end if
end procedure

global procedure callRWLProc(integer RWLID,object PROC,sequence PARMS)
integer tmp
object dmp
 if RWLID>=1 and RWLID<=length(RWLLIST) then
  if sequence(PROC) then
   PROC=getProcID(RWLID,PROC)
   if PROC=0 then
    return
   end if
  end if
  RWLProc2MEM(RWLID,PROC)
  for a=1 to length(PARMS) do
   if sequence(PARMS[a][1]) then
    tmp=getParmID(RWLID,PROC,PARMS[a][1])
   else
    tmp=PARMS[a][1]
   end if
   setParm(RWLID,PROC,tmp,PARMS[a][2])
  end for
  if RWLLIST[RWLID][PROC][2] then
   if BIG then
    call(RWLLIST[RWLID][PROC][2])
   else
    dmp=CallRealMode(RWLLIST[RWLID][PROC][2],repeat(0,17),0)
--    call(RWLLIST[RWLID][PROC][2])
   end if
  end if
 end if
end procedure

global procedure presetParms(integer RWLID, object PROC, sequence PARMS)
integer tmp
 if RWLID>=1 and RWLID<=length(RWLLIST) then
  if sequence(PROC) then
   PROC=getProcID(RWLID,PROC)
   if PROC=0 then
    return
   end if
  end if
  RWLProc2MEM(RWLID,PROC)
  for a=1 to length(PARMS) do
   if sequence(PARMS[a][1]) then
    tmp=getParmID(RWLID,PROC,PARMS[a][1])
   else
    tmp=PARMS[a][1]
   end if
   setParm(RWLID,PROC,tmp,PARMS[a][2])
  end for
 end if
end procedure

global function getRWLProc(integer id,object proc)
integer membyte
atom tmp
sequence asmstr
asmstr=""
 if sequence(proc) then
  proc=getProcID(id,proc)
  if proc=0 then
   return {}
  end if
 end if
 if sequence(RWLLIST[id][proc][2]) then
  asmstr=RWLLIST[id][proc][2]
 else
  tmp=RWLLIST[id][proc][2]
  if tmp !=0 then
   membyte=peek(tmp)
   while membyte !=195 do
    asmstr&=membyte
    tmp+=1
    membyte=peek(tmp)
   end while
  end if
 end if
return asmstr
end function

global function getParamNames(integer id,object proc)
sequence list
list={}
 if sequence(proc) then
  proc=getProcID(id,proc)
  if proc=0 then
   for a=1 to length(RWLLIST[id][proc][3]) do
    list=append(list,RWLLIST[id][proc][3][a][1])
   end for
  end if
 end if
return list
end function

global function getProcNames(integer id)
sequence list
list={}
 for a=1 to length(RWLLIST[id]) do
  list=append(list,RWLLIST[id][a][1])
 end for
return list
end function

-- Returns state of registers:
-- {AL,CL,DL,BL,AH,CH,DH,BH}
global function getRegs()
sequence list
list={}
 if regdump=0 then
  return {}
 end if
 for a=0 to 7 do
  list&=peek(regdump+a)
 end for
 return list
end function

