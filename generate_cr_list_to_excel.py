#!/usr/bin/python
#_*_ coding:utf-8 _*_
#此脚本用来导出两个版本快照之间所有的CR


import xlwt
import xlrd
import subprocess
import json
import re
import requests
import os
import sys

f1=open("change_list.txt","r")
flist=f1.readlines()
# 存放changed from
change_from_number_array=[]
#the file total line
total_line=len(flist)
gerrit_server="gerrit.mot.com"
username="gaoyx9"
password="gyx050400??"
root=os.getcwd()
commit_list=[]

def set_style(name,height,bold=False):
    style=xlwt.XFStyle()
    pattern=xlwt.Pattern()
    pattern.pattern=xlwt.Pattern.SOLID_PATTERN
    #设置背景颜色
    pattern.pattern_fore_colour=17
    style.pattern=pattern
    #设置边框(为实线)
    borders=xlwt.Borders()
    borders.left=xlwt.Borders.THIN
    borders.right=xlwt.Borders.THIN
    borders.top=xlwt.Borders.THIN
    borders.bottom=xlwt.Borders.THIN
    style.borders=borders
	
    font=xlwt.Font()
    font.bold=bold
    font.size=500
    return style

def write_excel_head():
	global f
	global sheet1
	f=xlwt.Workbook(encoding="utf-8")
	sheet1=f.add_sheet("change_list",cell_overwrite_ok=True)
	row0=[u'CR',u'DESCRIPTION',u'COMPONENTS',u'ASSIGN',u"REPO PATH",u"COMMIT"]

    #写入表格的头部
	for row in range(0,len(row0)):
		sheet1.write(0,row,row0[row],set_style('Times New Roman',400,True))

    #将changed_from的行的下标放入数组中
	for index,line in enumerate(flist):
		if line!="":
			if "changed from" in line:
				change_from_number_array.append(index)

def get_commit():
    #change_from_number_array 中取出 change_from_number_array自己的下标, 和存放的 flist中 changed from 的下标
	commit_index=0
	for change_index,change_number_index in enumerate(change_from_number_array):
		commit_list=[]
		project_path=flist[change_number_index].split()[0]
		ssh1="repo list -n %s" % (project_path)
		process=subprocess.Popen(ssh1,shell=True,stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
		process.wait()
		project_name=process.stdout.read()

		#the last changed_from line
		if change_index==len(change_from_number_array)-1:
			#print("the last changed from index:",change_number_index)
			commit_message=flist[change_number_index+1:total_line-1-1+1]
			for commit_line in commit_message:
				commit_list.append(commit_line.split()[1])			
		else:
			commit_message=flist[change_number_index+1:change_from_number_array[change_index+1]-2+1]
			if len(commit_message)==0:
				print("no commit")
				commit_list=[]
			else:
				for commit_line in commit_message:
					commit_list.append(commit_line.split()[1])

        #遍历每一个changed from行下的commit列表
		for commit in commit_list:
			cmd1="ssh -p 29418 %s gerrit query commit:%s --format JSON | egrep 'project|branch|subject' | awk 'NR==1'" % (gerrit_server,commit)
			process=subprocess.Popen(cmd1,shell=True,stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
			process.wait()
			content=process.stdout.read()
            #如果从gerrit上未查到此笔commit信息，代码此commit未进行code review,所以需要到本地仓库中查找
			if content=="":
				if os.path.isdir(project_path):
					os.chdir(project_path)
					a1="git log %s -n 1 --format='%s'" % (commit,"%s")
					process=subprocess.Popen(a1,shell=True,stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
					process.wait()
					subject=process.stdout.read()
					os.chdir(root)
                    #正则表达式匹配CR号
					cr=re.findall(r'IK[A-Z]*-[0-9]*',subject)
					if len(cr)==0:
						print("no content:no cr")
					else:
                        cr=cr=re.findall(r'IK[A-Z]*-[0-9]*',subject)[0]
						cr_url="https://idart.mot.com/browse/%s" % (cr)
                        #根据CR号查询每一个CR的详细信息
						url="http://idart.mot.com/rest/api/2/issue/%s" % (cr)
						response=requests.get(url,auth=(username,password)).json()
						cr_description=response["fields"]["summary"]
						cr_component=response["fields"]["components"]
						if len(cr_component)==0:
							print("no component")
							sheet1.write(commit_index+1,2,"")	
						else:
							cr_component=response["fields"]["components"][0]["name"]
						cr_assign=response["fields"]["assignee"]["displayName"]
						sheet1.write(commit_index+1,0,cr)
						sheet1.write(commit_index+1,1,cr_description)
						sheet1.write(commit_index+1,2,cr_component)
						sheet1.write(commit_index+1,3,cr_assign)
						sheet1.write(commit_index+1,5,commit)
                        #每写一行，下标就加一
						commit_index+=1
			else:
				message=json.loads(content)
				repo_path=message["project"]
				subject=message["subject"]
                #正则表达式匹配CR号
				cr=re.findall(r'IK[A-Z]*-[0-9]*',subject)
				if len(cr)==0:
					print("no cr")
				else:
                    #正则表达式匹配CR号
					cr=cr=re.findall(r'IK[A-Z]*-[0-9]*',subject)[0]
					cr_url="https://idart.mot.com/browse/%s" % (cr)
					url="http://idart.mot.com/rest/api/2/issue/%s" % (cr)
					response=requests.get(url,auth=(username,password)).json()
					cr_description=response["fields"]["summary"]
					cr_component=response["fields"]["components"]
					if len(cr_component)==0:
						print("no component")
					else:
						cr_component=response["fields"]["components"][0]["name"]
					cr_assign=response["fields"]["assignee"]["displayName"]
					#print(line_index+1,cr,cr_description,cr_component,cr_assign)
					sheet1.write(commit_index+1,0,cr)
					sheet1.write(commit_index+1,1,cr_description)
					sheet1.write(commit_index+1,2,cr_component)
					sheet1.write(commit_index+1,3,cr_assign)
					sheet1.write(commit_index+1,4,repo_path)
					sheet1.write(commit_index+1,5,commit)
					commit_index+=1
		f.save("cr_list.xls")

#==============================================
if __name__=="__main__":
	write_excel_head()
	get_commit()
