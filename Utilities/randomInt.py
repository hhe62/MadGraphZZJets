import random,sys
random.seed(1)
randlist=[]
njobs=int(sys.argv[1])

while len(randlist)<njobs:
    entry=random.randint(10000,100000)
    if not entry in randlist:
        randlist.append(entry)

with open('seed_list.txt','w') as fseed:
    for entry in randlist:
        fseed.write(str(entry)+"\n")
