
include rwl2.e

set32Bit()


constant RWLFIL=openRWL("control.rwl")

if RWLFIL=0 then
 puts(1, "Please compile CONTROL.ASM first before testing.\n")
 abort(0)
end if

--    Not necessary, but causes speeding	--
-----------------------------------------------------
constant DispTXT=getProcID(RWLFIL,"Puts2")
constant TXT=getParmID(RWLFIL,DispTXT,"TXT")
constant DES=getParmID(RWLFIL,DispTXT,"DES")
constant CLR=getParmID(RWLFIL,DispTXT,"CLR")
constant XXX=getParmID(RWLFIL,DispTXT,"XXX")
constant YYY=getParmID(RWLFIL,DispTXT,"YYY")
constant ClearAll=getProcID(RWLFIL,"ClearAll")
RWLProc2MEM(RWLFIL,DispTXT)
RWLProc2MEM(RWLFIL,ClearAll)
-----------------------------------------------------

constant str="Euphoria!"

presetParms(RWLFIL,DispTXT,{{TXT,str},{DES,#B8000},{CLR,7},{XXX,80-length(str)},{YYY,24}})
setReturn(0)

atom t1

t1=time()
for a=1 to 10000 do
 callRWLProc(RWLFIL,DispTXT,{})
 callRWLProc(RWLFIL,ClearAll,{})
end for
t1=time()-t1

printf(1,"%.2f",{t1})


if machine_func(26,0) then end if

