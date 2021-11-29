
include rwl2.e
include wildcard.e


global constant	SYSTEM_RWL = openRWL("CONTROL.RWL")
if SYSTEM_RWL=0 then
 puts(1,"Cannot open Library CONTROL.RWL\n")
 abort(0)
end if
global constant RWL_SetDRV = getProcID(SYSTEM_RWL,"SetDRV")
global constant RWL_DRV = getParmID(SYSTEM_RWL,RWL_SetDRV,"DRV")
RWLProc2MEM(SYSTEM_RWL,RWL_SetDRV)

constant disk='c'
sequence mregs

global procedure set_drive(integer letter)
   letter = upper(letter)
   if letter < 'A' or letter > 'Z' then
      return
   end if
   mregs = repeat(0,10)
   mregs[REG_AX] = #E00
   mregs[REG_DX] = letter - 'A'
   mregs = dos_interrupt(#21, mregs)
end procedure

atom t0,t1,t2


t0=time()
for a=1 to 10000 do
 callRWLProc(SYSTEM_RWL,RWL_SetDRV,{{RWL_DRV,disk}})
end for
t0=time()-t0

presetParms(SYSTEM_RWL,RWL_SetDRV,{{RWL_DRV,disk}})
t1=time()
for a=1 to 10000 do
 callRWLProc(SYSTEM_RWL,RWL_SetDRV,{})
end for
t1=time()-t1

t2=time()
for a=1 to 10000 do
 set_drive(disk)
end for
t2=time()-t2


puts(1,  "10000 SetDrive Calls\n")
puts(1,  "--------------------\n")
printf(1,"EU DOS-INT   :\t%.2f\n",{t2})
printf(1,"RWL2         :\t%.2f\n",{t0})
printf(1,"RWL2 (Preset):\t%.2f\n",{t1})

if machine_func(26,0) then end if
