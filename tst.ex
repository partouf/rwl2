
include rwl2.e
include graphics.e

set32Bit()

constant RWLFIL=openRWL("control.rwl")

if RWLFIL=0 then
 puts(1, "Please compile CONTROL.ASM first before testing.\n")
 abort(0)
end if

--    Not necessary, but causes speeding	--
-----------------------------------------------------
constant DispTXT=getProcID(RWLFIL,"Puts")
constant SRC=getParmID(RWLFIL,DispTXT,"SRC")
constant DES=getParmID(RWLFIL,DispTXT,"DES")
RWLProc2MEM(RWLFIL,DispTXT)
-----------------------------------------------------


sequence vc
vc = video_config()

atom screen
if vc[VC_COLOR] then
    screen = #B8000 -- color
else
    screen = #B0000 -- mono
end if
screen = screen + 11*80*2 + 64

constant str=
	{'E', 7, 'u', 7, 'p', 7, 
	 'h', 7, 'o', 7, 'r', 7,
	 'i', 7, 'a', 7, '!', 7}

presetParms(RWLFIL,DispTXT,{{SRC,str},{DES,screen}})

callRWLProc(RWLFIL,DispTXT,{})

if machine_func(26,0) then end if

