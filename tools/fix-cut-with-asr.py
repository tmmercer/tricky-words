# For each key, try cut points around the expected start of the 2nd copy in t2/raw_<k>.wav and
# keep the first one whose transcript (with a spoken carrier for single words) matches exactly.
import shutil,wave,array,math,subprocess,re,sys,os
T='/tmp/tts';B=T+'/sherpa-onnx-v1.13.8-linux-x64-shared';W=T+'/sherpa-onnx-whisper-base.en'
env=dict(os.environ,LD_LIBRARY_PATH=B+'/lib')
CHAIN='silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse,loudnorm=I=-16:TP=-1.5,afade=t=in:d=0.01,areverse,afade=t=in:d=0.04,areverse'
items={l.split('\t')[0]:l.split('\t')[1] for l in open('items.tsv') if l.strip()}
norm=lambda s:re.sub(r"[^a-z' ]","",s.lower().replace('-',' ').replace('\\"','')).split()
def load(f):
    x=wave.open(f);return array.array('h',x.readframes(x.getnframes())),x.getparams()
def envl(a,fr=240): return [20*math.log10(max(1,math.sqrt(sum(v*v for v in a[i:i+fr])/max(1,len(a[i:i+fr]))))) for i in range(0,len(a),fr)]
def span(D):
    th=max(D)-40; s=next(j for j,d in enumerate(D) if d>th); e=len(D)-next(j for j,d in enumerate(reversed(D)) if d>th); return s,e
def asr(f):
    o=subprocess.run([B+'/bin/sherpa-onnx-offline','--whisper-encoder='+W+'/base.en-encoder.int8.onnx','--whisper-decoder='+W+'/base.en-decoder.int8.onnx','--tokens='+W+'/base.en-tokens.txt','--num-threads=2',f],capture_output=True,text=True,env=env)
    m=re.search(r'"text": "(.*?)", "timestamps',o.stdout+o.stderr); return m.group(1) if m else ''
for k in sys.argv[1:]:
    word=not(k.startswith('s_') or k.startswith('_'))
    a,p=load('t2/raw_%s.wav'%k); E=envl(a); S=envl(load('/home/claude/gen2/wav/%s.wav'%k)[0])
    ss,se=span(S); es,ee=span(E); exp=ee-int((se-ss)-14)
    ok=None
    for off in [0,-2,2,-4,4,-6,6,-8,8,-10,10,-12,12,-15,15,-18,18]:
        c=exp+off
        o=wave.open('/tmp/sc.wav','wb');o.setparams(p);o.writeframes(a[c*240:].tobytes());o.close()
        subprocess.run(['ffmpeg','-loglevel','error','-y','-i','/tmp/sc.wav','-af',CHAIN,'-ac','1','-ar','24000','-b:a','48k','/tmp/sc.mp3'])
        f='/tmp/sc.mp3'
        if word:
            subprocess.run(['ffmpeg','-loglevel','error','-y','-i',T+'/carrier.wav','-i','/tmp/sc.mp3','-filter_complex','[0]aresample=24000[a];[1]aresample=24000[b];[a][b]concat=n=2:v=0:a=1','/tmp/scc.wav']); f='/tmp/scc.wav'
        r=asr(f); expn=norm(('My favorite word is ' if word else '')+items[k])
        if norm(r)==expn:
            ok=c; os.replace('/tmp/sc.wav','t3/%s.wav'%k); shutil.copy('/tmp/sc.mp3','/home/claude/repo/audio/%s.mp3'%k); break
    print(k,'OK cut %d'%ok if ok is not None else 'NO MATCH (last: %s)'%r, flush=True)
