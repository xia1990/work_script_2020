#!/usr/bin/pyhton

import xlrd
import xlwt
import subprocess
import os
from optparse import OptionParser
import sys

usage="usage: <yourscript> -c current_tag -l last_tag"
optparser=OptionParser(usage=usage)
optparser.add_option('-c','--current_tag',type="string",dest="current_tag",help="current tag")
optparser.add_option('-l','--last_tag',type="string",dest="last_tag",help="last tag")

project_index_array=[]
current_dir=os.getcwd()
def write_excel_head():
	global f
	global sheet1
	f=xlwt.Workbook(encoding="utf-8")
	sheet1=f.add_sheet("change_list",cell_overwrite_ok=True)
	row0=[u'Repo',u'Release tag',u'commit id',u'change id',u"description",u"Owning Team	SME",u'Commit Author']
	for row in range(0,len(row0)):
		sheet1.write(0,row,row0[row])

def main():
	global flist
	f1=open("changelist.log","r")
	flist=f1.readlines()
	count=0
	for index,line in enumerate(flist):
		if line!="":
			if line.startswith("project"):
				project_index_array.append(index)

def test():
	total_line=len(flist)
	count=0
	for project_index_index,project_index in enumerate(project_index_array):
		name=flist[project_index].split()[1]
		commit_list=[]
		message_list=[]
		if project_index_index==len(project_index_array)-1:
			commit_message=flist[project_index+1:total_line]
			for i in commit_message:
				commit_list.append(i.split()[0])
				message_list.append(i[40:])
		else:
			commit_message=flist[project_index+1:project_index_array[project_index_index+1]-2+1]
			for i in commit_message:
				commit_list.append(i.split()[0])
				message_list.append(i[40:])

		#count=0
		for i,commit in enumerate(commit_list):
			#name=flist[project_index].split()[1]
			tag="qc/LA.UM.9.16.r1-08300-MANNAR.QSSI12.0"
			os.chdir(name)
			cmd1="git log -1 %s | grep 'Change-Id'" % (commit)
			process=subprocess.Popen(cmd1,shell=True,stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
			process.wait()
			changeid=process.stdout.read()
			os.chdir(current_dir)
			description=message_list[i]
			print(description)
			#print(name,count)
			sheet1.write(count+1,0,name)
			sheet1.write(count+1,1,tag)
			sheet1.write(count+1,2,commit)
			sheet1.write(count+1,3,changeid)
			sheet1.write(count+1,4,description)
			count=count+1
	f.save("qcom_changelist.xls")

if __name__=="__main__":
	write_excel_head()
	main()
	test()
