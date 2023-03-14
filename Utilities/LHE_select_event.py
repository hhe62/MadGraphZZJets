import random,json
import sys,pdb

# The script combines the reweight and unweight(accept/reject) in one reading of file.
with open('xsecs.json') as json_file:
    xsecdict = json.load(json_file)

fin = open("combineEventTemp")#("test_sample_event.lhe")
fout = open("Events_merged.lhe",'w')
seed = int(sys.argv[1])
random.seed(seed)
nevts01j = int(sys.argv[2]) #50000 #enought 01j events so that the max weight abs(xsec)/nevt is from 2j events, so the accept/reject process keep 100% 2j events
nevts2j = int(sys.argv[3]) #20000
wgt01jStr = str(xsecdict['01j'])#"4.5340621e+01"
wgt2jStr = str(xsecdict['2j'])#"2.1026600e+01"
absxsec01j = float(wgt01jStr) #the weight is equal to absxsec with sign attached due to chosen normalization
absxsec2j = float(wgt2jStr)
totalabsxsecStr = format(absxsec01j+absxsec2j,".7e") # a choice for weight value in the final unweighted merge sample
newwgt01jStr = format(absxsec01j/nevts01j,".7e")
newwgt2jStr = format(absxsec2j/nevts2j,".7e")
maxweight = max(absxsec01j/nevts01j,absxsec2j/nevts2j) #Two unweighted samples, so only two weight values without signs)  

print("Weight Strings",newwgt01jStr,newwgt2jStr)
print("max Weight",maxweight)

#temp variable ================================
nevt = 0
oldwgtStr = ''
newwgtStr = ''
doRwgt = False
evttype = 1 #1 for 01j, 2 for 2j
linestore = ''
skipEvent = False
#==============================================

totalEvt1 =0. #type1 for 01j, 2 for 2j. Total processed and preserved events
totalEvt2 =0.
evtPr1 = 0.
evtPr2 = 0.

for line in fin:
    if "<event" in line:
        doRwgt = True
        linestore = line
        continue #jump to next line which should contain XWGTUP

    if "</event" in line:
        if not skipEvent:
            fout.write(line)
        skipEvent = False #reset 
        continue

    if doRwgt:
        doRwgt = False #reset
        if wgt01jStr in line:
            evttype = 1
            totalEvt1 +=1
            nevt = nevts01j
            oldwgtStr = wgt01jStr
            newwgtStr = newwgt01jStr
        elif wgt2jStr in line:
            evttype = 2
            totalEvt2 +=1
            nevt = nevts2j
            oldwgtStr = wgt2jStr
            newwgtStr = newwgt2jStr
        else:
            print ("Something wrong with XWGTUP")
            raise ValueError
            #sys.exit()


        skipEvent = random.random() >= float(newwgtStr)/maxweight #accept/reject method
        if not skipEvent:
            fout.write(linestore) #write back <event...> header
            line = line.replace(oldwgtStr,totalabsxsecStr) #Set the new weight of choice. Should work for both positive and negative since we only replace the value part
            fout.write(line)
            if evttype ==1:
                evtPr1 +=1
            if evttype ==2:
                evtPr2 +=1
            continue
        else:
            continue

    if not skipEvent and "<wgt id=" in line:
        extraRwgtStr = line.split('> ')[1].split(' <')[0]
        extraRwgtStrNew = format(float(extraRwgtStr)/float(oldwgtStr)*float(totalabsxsecStr),"+.7e") #scale other rwgt value as well
        line = line.replace(extraRwgtStr, extraRwgtStrNew)
        fout.write(line)
        continue

    if not skipEvent:
        fout.write(line)
        continue

eff1 = evtPr1/totalEvt1
eff2 = evtPr2/totalEvt2
print("Processed 01j and 2j events %s and %s, preserve events %s and %s, efficiency %s and %s"%(totalEvt1,totalEvt2,evtPr1,evtPr2,eff1,eff2))

fout=open("genEvents.txt","w")
nevents = str(int(evtPr1+evtPr2))
fout.write(nevents)
'''
f_frag=open("fragment_py_GEN_SIM.py")
fout=open("RunConfig.py","w")
nevents = str(int(evtPr1+evtPr2))
seedstr = str(seed)
for line in f_frag:
    line = line.replace("63136",nevents).replace("Corrected_final_merged012j_decayed",seedstr).replace("Corrected_shower_merged012j_nholder",seedstr)
    fout.write(line)
'''
