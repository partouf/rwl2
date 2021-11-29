
include rwl2.e

set32Bit()

integer RWLFIL,ModeIt,Mouse,MDE,HSM
RWLFIL=openRWL("control.rwl")

sequence mregs

if RWLFIL=0 then
 puts(1, "Please compile CONTROL.ASM first before testing.\n")
 abort(0)
end if

--    Not necessary, but causes speeding	--
-----------------------------------------------------
ModeIt=getProcID(RWLFIL,"ModeIt")
Mouse=getProcID(RWLFIL,"Mouse")
MDE=getParmID(RWLFIL,ModeIt,"MDE")
HSM=getParmID(RWLFIL,Mouse,"HSM")
RWLProc2MEM(RWLFIL,ModeIt)
RWLProc2MEM(RWLFIL,Mouse)
-----------------------------------------------------

callRWLProc(RWLFIL,ModeIt,{{MDE,18}})
callRWLProc(RWLFIL,Mouse,{{HSM,1}})


if machine_func(26,0) then end if
