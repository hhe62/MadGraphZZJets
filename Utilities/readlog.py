import pdb
eventcount=0
errcount=0
passed=False
phrase = "Final miniAOD events: "

with open("tmpLoglist") as loglist:
    for line in loglist:
        passed=False
        with open("log/"+line.strip()) as f:
            for l in f:
                if phrase in l:
                    passed = True
                    #pdb.set_trace()
                    nevt = int(l.strip().split(phrase)[1])
                    eventcount+=nevt
        if not passed:
            print("File %s has error"%line)
        
print("Total events:%s"%eventcount)
