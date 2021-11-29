
function mmatch(sequence str,sequence cstr)
object loc,pl,temp1,temp2,temp3,lngt,t1,t2
 temp1=""
 temp2=cstr
 pl=0
 lngt=length(str)
 loc=match(str,temp2)
  while loc do
   temp3=loc+pl*lngt
   temp1=temp1 & temp3
   t1=temp2[1..loc-1]
   t2=temp2[loc+lngt..length(temp2)]
   temp2=t1 & t2
   loc=match(str,temp2)
   pl+=1
  end while
return temp1
end function


constant SHORTS=
{
	{":=","MOV"},
	{"+=","ADD"},
	{"-=","SUB"},

	{"==","LEA"},
	{"<>","XCHG"}
}

constant EXEPTS=
{
	{"++","ADC","INC"},
	{"--","SBB","DEC"}
}

constant IFS=		-- Unsigned
{
	{"!=","JNE"},
	{"<=","JBE"},
	{">=","JAE"},
	{"=","JE"},
	{"<","JB"},
	{">","JA"}
}


function pp3(sequence str)
sequence tmp1
integer beg
 for a=1 to length(EXEPTS) do
  tmp1=mmatch(EXEPTS[a][1],str)
  for b=1 to length(tmp1) do
   tmp1=mmatch(EXEPTS[a][1],str)

   beg=tmp1[1]

   while 1 do
    beg-=1
    if beg<=0 then
     beg=1
     exit
    end if
    if str[beg]=32 or str[beg]=9 then
     beg+=1
     exit
    end if
   end while

   if beg=tmp1[1] then
    str=str[1..beg-1]&EXEPTS[a][3]&" "&str[tmp1[1]+length(EXEPTS[a][1])..length(str)]
   else
    str=str[1..beg-1]&EXEPTS[a][2]&" "&str[beg..tmp1[1]-1]&","&str[tmp1[1]+length(EXEPTS[a][1])..length(str)]
   end if

  end for
 end for
return str
end function

function pp2(sequence str)
sequence tmp1
integer beg,ende
 for a=1 to length(IFS) do
  tmp1=mmatch(IFS[a][1],str)
  for b=1 to length(tmp1) do
   tmp1=mmatch(IFS[a][1],str)

   beg=tmp1[1]
   ende=tmp1[1]

   while 1 do
    beg-=1
    if beg<=0 then
     puts(1,"PP: No begin of equation\n")
     abort(0)
    end if
    if str[beg]='(' then
     exit
    end if
   end while

   while 1 do
    ende+=1
    if ende>length(str) then
     puts(1,"PP: No end of equation\n")
     abort(0)
    end if
    if str[ende]=')' then
     exit
    end if
   end while

   str=
	str[1..beg-1]&
	"CMP "&
	str[beg+1..tmp1[1]-1]&
	","&
	str[tmp1[1]+length(IFS[a][1])..ende-1]&
	" "&
	IFS[a][2]&
	" "&
	str[ende+1..length(str)]

  end for
 end for
return str
end function

global function pp(sequence str)
sequence tmp1
integer beg
 for a=1 to length(SHORTS) do
  tmp1=mmatch(SHORTS[a][1],str)
  for b=1 to length(tmp1) do
   tmp1=mmatch(SHORTS[a][1],str)

   beg=tmp1[1]

   while 1 do
    beg-=1
    if beg<=0 then
     beg=1
     exit
    end if
    if str[beg]=32 or str[beg]=9 then
     beg+=1
     exit
    end if
   end while

   str=str[1..beg-1]&SHORTS[a][2]&" "&str[beg..tmp1[1]-1]&","&str[tmp1[1]+length(SHORTS[a][1])..length(str)]

  end for
 end for

 str=pp3(str)
 str=pp2(str)

return str
end function
