--    ReadFile by PQ
-- Copyright 2000 by PQ

global function readFile(sequence file)
object tmp,handler,txt
tmp={}
 handler=open(file,"r")
 if handler !=-1 then
  while 1 do
   txt=gets(handler)
   if compare(-1,txt) !=0 then
    if txt[length(txt)]='\n' then
     tmp=append(tmp,txt[1..length(txt)-1])
    else
     tmp=append(tmp,txt)
    end if
   else
    exit
   end if
  end while
  close(handler)
 else
 end if
return tmp
end function
