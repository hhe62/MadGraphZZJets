
with open("errfile") as ferr:
    for line in ferr:
        if "interrupted with error" in line:
            print("MadGraph interrupted with error")
            raise ValueError
        
            
    print("MadGraph output seems fine")
    
