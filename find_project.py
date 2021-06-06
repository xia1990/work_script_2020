#!/usr/bin/python

f1=open("1.txt")
lf1=f1.readlines()
f1.close()

f2=open("2.txt")
lf2=f2.readlines()
f2.close()

for line in lf2:
    if line in lf1:
        print("pass")
    else:
        print("error")
