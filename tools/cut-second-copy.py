# Input: "text, text." in one breath. Keep the second copy: cut at the end of the
# longest quiet stretch near the middle (the comma pause).
import wave,array,math,sys
src,dst=sys.argv[1],sys.argv[2]
w=wave.open(src);sr=w.getframerate();a=array.array('h',w.readframes(w.getnframes()));p=w.getparams()
fr=int(sr*0.01);db=[20*math.log10(max(1,math.sqrt(sum(x*x for x in a[i:i+fr])/len(a[i:i+fr])))) for i in range(0,len(a),fr)]
pk=max(db);th=pk-38
s=next(j for j,d in enumerate(db) if d>th); e=len(db)-next(j for j,d in enumerate(reversed(db)) if d>th)
L=e-s; lo=s+int(L*0.38); hi=s+int(L*0.66)
runs=[];j=lo
while j<hi:
    if db[j]<th:
        k=j
        while k<len(db) and db[k]<th: k+=1
        runs.append((k-j,j,k)); j=k
    else: j+=1
if not runs:
    sm=[sum(db[max(0,j-1):j+2])/3 for j in range(len(db))]; c=min(range(lo,hi),key=lambda j:sm[j]); runs=[(0,c,c)]
n,j,k=max(runs)
cut=max(j,k-3)
o=wave.open(dst,'wb');o.setparams(p);o.writeframes(a[cut*fr:].tobytes());o.close()
print(src.split('/')[-1],'gap %d frames, cut %.2f/%.2f'%(n,cut/100,len(db)/100))
