----------------------------------
-- 	ASM to RaW-Libary 2	--
--	Copyright 2000 by PQ	--
----------------------------------

include readfil.e
include asm.e
include mmatch.e
include pp.e		-- PreProcessor

integer hnd,membyte
sequence asmstr,PROCS,filestr,COMPERR

COMPERR=""
asmstr=""
PROCS={}


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


function reverse(sequence s) 
integer lower, n 
sequence t 
 n = length(s) 
 t = repeat(0, n) 
 lower = 1 
 for upper = n to floor(n/2)+1 by -1 do 
  t[upper] = s[lower] 
  t[lower] = s[upper] 
  lower += 1 
 end for 
return t 
end function 

procedure remcom()
object tmp
for a=1 to length(filestr) do
 tmp=match("//",filestr[a])
 if tmp !=0 then
  filestr[a]=filestr[a][1..tmp-1]
 end if 
end for
end procedure

function trimParam(sequence str)
sequence newstr
newstr=""
 for a=1 to length(str) do
  if str[a] !=32 and str[a] !=9 then
   newstr&=str[a]
  end if
 end for
return newstr
end function


procedure findprocs()
integer proc,tmp,tmp2,tmp3,cnt,begin,ende
sequence tmp4,tmp5
proc=0
cnt=0
 for a=1 to length(filestr) do
  if proc=0 then
   tmp=match("proc ",filestr[a])
   if tmp !=0 then
    cnt+=1
    tmp2=find(':',filestr[a])
    if tmp2 !=0 then
     PROCS=append(PROCS,{filestr[a][tmp+5..tmp2-1],"",{}})
     proc=1
    else
     COMPERR&="Line "&sprintf("%.10g",a)&", ':' expected.\n"
     exit
    end if
    tmp2=find('(',filestr[a])
    if tmp2 !=0 then
     PROCS[cnt][1]=filestr[a][tmp+5..tmp2-1]
     tmp3=find(')',filestr[a])
     tmp4=multimatch(",",filestr[a])
     if tmp3 !=0 then
      for z=1 to length(tmp4)+1 do
       if z=1 then
        begin=tmp2+1
        if length(tmp4)=0 then
         ende=tmp3-1
        else
         ende=tmp4[z]-1
        end if
       elsif z=length(tmp4)+1 then
        begin=tmp4[z-1]+1
        ende=tmp3-1
       else
        begin=tmp4[z-1]+1
        ende=tmp4[z]-1
       end if
       for x=1 to length(REG) do
        tmp2=match(REG[x][1],filestr[a][begin..ende])
        if tmp2 then
         tmp5=trimParam(filestr[a][begin+2..ende])
         if length(tmp5) !=3 then
          COMPERR&="Line "&sprintf("%.10g",a)&",Length parameter must be 3.\n"
          exit
         else
          PROCS[cnt][3]=append(PROCS[cnt][3],{tmp5,REG[x][2]})
          exit
         end if
        end if
       end for
      end for
     else
      COMPERR&="Line "&sprintf("%.10g",a)&", ')' expected.\n"
      exit
     end if
    end if
   end if
  elsif proc=1 then
   tmp=match("end proc",filestr[a])
   if tmp !=0 then
    proc=0
   else
    PROCS[length(PROCS)][2]&=filestr[a]&32
   end if
  end if
 end for
 if proc=1 then
  COMPERR&="Warning: 'end proc' not found\n"
 end if
end procedure

procedure createLib(sequence name)
sequence newstr
atom tmp
 tmp=0
 hnd=open(name[1..find('.',name)]&"RWL","wb")
 if hnd !=-1 then
  puts(hnd,"RWL2"&length(PROCS))
  for a=1 to length(PROCS) do
   asmstr=""
   newstr=""
   tmp=0
   puts(1,PROCS[a][1]&": ")
   if length(PROCS[a][1])>8 then
    COMPERR&="Length of ProcName must be 8 or less\n"
    exit
   else
    for b=1 to 8-length(PROCS[a][1]) do
     PROCS[a][1]&=32
    end for
   end if

   PROCS[a][2]=pp(PROCS[a][2])

   if not match("RET",PROCS[a][2]) then
    PROCS[a][2]&=" RET "
   end if
   tmp=get_asm(PROCS[a][2])
   membyte=peek(tmp)
   while membyte !=195 do
    asmstr&=membyte
    tmp+=1
    membyte=peek(tmp)
   end while
   free(tmp-length(asmstr))
   puts(hnd,PROCS[a][1])
   puts(hnd,length(PROCS[a][3]))
   for b=1 to length(PROCS[a][3]) do
    puts(hnd,PROCS[a][3][b][1])
    puts(hnd,PROCS[a][3][b][2][1])
   end for
   puts(hnd,length(asmstr))
   puts(hnd,asmstr)
   puts(1,"+\n")
  end for
 else
  COMPERR&="Unable to create RWL file\n"
 end if
 close(hnd)
end procedure


sequence file,cl

puts(1,"\nRWL2 Compiler - Copyright 2000 by QC\n\n")

cl=command_line()
if length(cl)>=3 then
 file=cl[3]
else
 puts(1,"Enter file to compile: ")
 file=gets(0)
 file=file[1..length(file)-1]
 puts(1,"\n")
end if

if open(file,"r") then
 puts(1,"Compiling "&file&"\n")
 filestr=readFile(file)
 if length(filestr)=0 then
  COMPERR="File is empty\n"
 else
  remcom()
  findprocs()
 end if
 createLib(file)
 if length(COMPERR)=0 then
  puts(1,"No errors found\n")
 end if
else
 COMPERR="File does not exist"
end if

if length(COMPERR)=0 then
 puts(1,"\nRWL succesfully compiled\n")
else
 puts(1,COMPERR)
end if

puts(1,"\n\n")
