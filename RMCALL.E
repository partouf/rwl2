-- NAME: poke_t.e
-- OBJECT: define procedures and functions to poke and peek different data type
-- CREATION DATE: july 9th, 1997
-- BY: Jacques Deschenes, Baie-Comeau, Canada, email:desja@globetrotter.com
--

global procedure poke_word(atom addr, object w) -- poke 16 bits unsigned int
    if atom(w) then
      poke(addr,{remainder(w,256),floor(w/256)})
    else
      for i = 1 to length(w) do
	poke(addr+(i-1)*2,{remainder(w,256),floor(w/256)})
      end for
    end if
end procedure

global function peek_word(object o)  -- peek 16 bits word(s)
atom addr
sequence words
    if atom(o) then
      return peek(o)+peek(o+1)*256
    else    
      words = {}
      addr = o[1]
      for i = 0 to o[2]-1 do
	words = words & peek(addr+i*2)+peek(addr+1+i*2)*256
      end for
      return words
    end if
end function

global procedure poke_int(atom addr, object o) -- poke integer
sequence n
integer a
    if atom(o) then
      n = {}
      for j = 1 to 4 do
	n = n & remainder(o,256)
	o = floor(o/256)
      end for
      poke(addr,n)
    else
      for i = 1 to length(o) do
	n = {}
	a = o[i]
	for j = 1 to 4 do
	  n = n & remainder(a,256)
	  a = floor(a/256)
	end for
	poke(addr+(i-1)*4,n)
      end for       
    end if
end procedure

global function peek_int(object o) -- peek integer(s)
sequence s, integers
atom addr
integer n
    if atom(o) then
      s = peek({o,4})
      n = 0
      if s[4] < 128 then
	for i = 4 to 1 by -1 do
	  n =  n *256+ s[i]
	end for
      else
	for i = 4 to 1 by -1 do
	  n = n*256+255-s[i]
	end for
	n = -n-1
      end if
      return n
    else
      addr = o[1]
      integers = {}
      for j = 0 to o[2]-1 do
	s = peek({addr + j*4, 4})
	n = 0
	if s[4] < 128 then
	  for i = 4 to 1 by -1 do
	    n =  n *256+ s[i]
	  end for
	else
	  for i = 4 to 1 by -1 do
	    n = n*256+255-s[i]
	  end for
	  n = -n-1
	end if
	integers = integers & n
      end for
      return integers
    end if
end function

global function peek_sint(object o) -- peek short integer 16 bits
sequence s, s_int
atom addr
integer a   
  if atom(o) then
    s = peek({o,2}) 
    if s[2] < 128 then
	return s[2]*256+s[1]
    else
	return -((255-s[2])*256 + (255-s[1])) - 1
    end if
  else
    addr = o[1]
    s_int = {}
    for i = 0 to o[2]-1 do
      s = peek({addr+i*2,2})
      if s[2] < 128 then
	a = s[2]*256+s[1]
      else
	a = -((255-s[2])*256 + (255-s[1])) - 1
      end if
      s_int = s_int & a
    end for
    return s_int
  end if
end function

global procedure poke_pointer(atom address, atom p)
-- convert linear address to real mode pointer and poke it in memory
atom seg, ofs
   seg = floor(p/16)
   ofs = remainder(p,16)
   poke_word(address,ofs)
   poke_word(address+2,seg)
end procedure -- poke_pointer()

global function peek_pointer(atom address)
-- peek a real mode integer and convert to linear
integer ofs, seg
    ofs = peek_word(address)
    seg = peek_word(address+2)
    return seg*16+ofs
end function


-- NAME: rmcall.e
-- PURPOSE: calling code running in real mode from protected mode.
-- CREATION DATE: June 27 th, 1997
-- BY: Jacques Deschenes, Baie-Comeau, Canada, email: desja@quebectel.com
--
--          as euphoria interpreter run in protected mode as well as the
--          assembler code called withing it,  one need to use translation
--          service of the DPMI server (causeway)  to run real mode code.
--          The translation service used here is number 0301h.
--

-- Real mode caller code
constant sRealModeCode={
  #60,			-- pushad
  #06,			-- push es
  #1E,			-- push ds
  #07,			-- pop  es
  #BB,#25,#00,#00,#00,	-- mov  ebx, offset exit_code (5)
  #BF,#00,#00,#00,#00,	-- mov  EDI, offset callstruct(10)
  #66,#B8,#01,#03,	-- mov  ax, 0301h
  #B7,#01,		-- mov  bh, 1
  #66,#B9,#00,#00,	-- mov cx, 0
  #CD,#31,		-- int  31
  #C6,#03,#00,		-- mov   [byte ptr ebx],0
  #73,#07,#90,#90,#90,#90,-- jnc  @exit
  #C6,#03,#01,		-- mov  [byte ptr ebx],1
			-- @exit:
  #07,			-- pop  es
  #61,			-- popad
  #C3,			-- ret
  0			-- exit_code db ? 
}

global constant NBR_REGS = 17
global type x_regs(sequence s)   -- extended cpu registers
    return length(s) = NBR_REGS
end type

-- index and offset of call structure members
global constant
    iR_EDI = 1,  R_EDI = 0,	-- DWORD   
    iR_ESI = 2,  R_ESI = 4,	-- DWORD
    iR_EBP = 3,  R_EBP = 8,	-- DWORD
    iR_SYS = 4,  R_SYS = 12,	-- DWORD reserved  dpmi server internal use.
    iR_EBX = 5,  R_EBX = 16,	-- DWORD
    iR_EDX = 6,  R_EDX = 20,	-- DWORD
    iR_ECX = 7,  R_ECX = 24,	-- DWORD
    iR_EAX = 8,  R_EAX = 28,	-- DWORD
    iFLAGS = 9,  FLAGS = 32,	-- WORD
    iR_ES =10,   R_ES = 34,	-- WORD
    iR_DS =11,   R_DS = 36,	-- WORD
    iR_FS =12,   R_FS = 38,	-- WORD
    iR_GS =13,   R_GS = 40,	-- WORD
    iR_IP =14,   R_IP = 42,	-- WORD
    iR_CS =15,   R_CS = 44,	-- WORD
    iR_SP =16,   R_SP = 46,	-- WORD
    iR_SS =17,   R_SS = 48	-- WORD

global constant REGS_OFS={R_EDI,R_ESI,R_EBP,R_SYS,R_EBX,R_EDX,R_ECX,R_EAX,FLAGS,
R_ES,R_DS,R_FS,R_GS,R_IP,R_CS,R_SP,R_SS}


constant STRUC_SIZE = 50

atom pCallStruc, pExitCode

pCallStruc = allocate(STRUC_SIZE)
mem_set(pCallStruc,0,STRUC_SIZE)
lock_memory(pCallStruc,STRUC_SIZE)

atom pRealModeCall
pRealModeCall = allocate(length(sRealModeCode))
poke(pRealModeCall,sRealModeCode)
pExitCode = pRealModeCall+length(sRealModeCode)-1
poke_int(pRealModeCall+5,pExitCode)
poke_int(pRealModeCall+10,pCallStruc)

global constant DSIZE_16=0, DSIZE_32=1
global function CallRealMode(object FctAddr,	-- real mode function linear address
					-- or sequence {seg,ofs}
			     x_regs regs,	-- cpu extended registers
			     integer size	-- data size 0 for 16 bits, 1 for 32
			     )
   for i = 1 to 8  do
      poke_int(pCallStruc+REGS_OFS[i],regs[i])
   end for
   for i = 9 to NBR_REGS  do
      poke_word(pCallStruc+REGS_OFS[i],regs[i])
   end for
   if atom(FctAddr) then
     poke_word(pCallStruc+R_CS,floor(FctAddr/16))
     poke_word(pCallStruc+R_IP,remainder(FctAddr,16))
   else
    poke_word(pCallStruc+R_CS,FctAddr[1])
    poke_word(pCallStruc+R_IP,FctAddr[2])
   end if
   call(pRealModeCall)
   if peek(pExitCode) then
      return {}
   end if
   for i = 1 to 8 do
     if size then
       regs[i] = peek_int(pCallStruc+REGS_OFS[i])	-- peek 32 bits integers
     else
       regs[i] = peek_sint(pCallStruc+REGS_OFS[i])	-- peek short int (16 bits)
     end if
   end for
   for i = 9 to NBR_REGS do
     regs[i] = peek_word(pCallStruc+REGS_OFS[i])
   end for
   return regs
end function  

