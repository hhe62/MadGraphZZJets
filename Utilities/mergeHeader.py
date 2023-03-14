import json

f1=open("01jHeader")
f2=open("2jHeader")
fout = open("combinedHeader",'w')

start = False
start2 = False
nskip = 0
nline = 0
extraline = ''
absxsec01j = 0.
absxsec2j = 0.
totalabs = 0.
totalabsstr = ''

for line in f2:
    if '<init>' in line:
        start = True
        continue

    if start:
        if nskip<1:
            nskip+=1
            continue
        else:
            extraline = line
            print("Extra line: %s"%extraline)
            start = False
f2.close()

absxsec2j = float(extraline.strip().split(' ')[2])
print(absxsec2j)

for line in f1:

    if start:
        line = line.replace('-4   2', '-4   3')
        start = False
        fout.write(line+'')
        continue

    if start2:
        nline +=1
        string = line.strip().split(' ')[2]
        absxsec01j = float(line.strip().split(' ')[2])
        print(absxsec01j)
        totalabsstr = format(absxsec01j + absxsec2j,".7e")
        line = line.replace(string,totalabsstr)
        fout.write(line+'')
        
        if nline ==2:
            string2 = extraline.strip().split(' ')[2]
            extraline2 = extraline.replace(string2, totalabsstr)
            fout.write(extraline2+'')
            start2 = False
        continue

    fout.write(line+'')
    if line.strip() == 'add process p p > z z j [QCD] @1':
        fout.write('add process p p > z z j j [QCD] @2'+'\n')
    
    if "<init>" in line:
        start = True
        start2 = True
        continue

xsecdict={}
xsecdict['01j'] =format(absxsec01j,".7e")
xsecdict['2j'] =format(absxsec2j,".7e")

with open("xsecs.json",'w') as output_file:
    json.dump(xsecdict,output_file,indent=4)
