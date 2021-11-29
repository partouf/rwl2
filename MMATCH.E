--   Multimatch by PQ
-- Copyright 2000 by PQ

global function multimatch(sequence str,sequence cstr)
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
