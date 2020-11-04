#!/usr/bin/python
#_*_ coding:utf-8 _*_
import subprocess
import json
import re
import sys
import xlwt
import time
reload(sys)
sys.setdefaultencoding('utf-8')
query_str=sys.argv[1]
def set_style(name,height,color,back_color,bold,horz,vert):
	style = xlwt.XFStyle() # 创建样式对象
 
	font = xlwt.Font() # 创建字体对象
	font.name = name # 字体名称 'Times New Roman'
	font.bold = bold #字体粗体
	#font.italic = True # 斜体
	#font.underline = 10 # 下划线 数字代表不同下划线类型 98的时候是双下划线
	#font.struck_out =True # 横线（比如：在一个字中 画上一横）
	font.colour_index = color #字体颜色 数字代表不同颜色
	#0黑 1白 2红 3绿 4蓝 6红紫 7亮蓝
	font.height = height #字体高度
 	
	# NO_LINE： 官方代码中NO_LINE所表示的值为0，没有边框
	# THIN： 官方代码中THIN所表示的值为1，边框为实线
	borders= xlwt.Borders() #创建边框对象
	borders.left= 1 #数字代表不同边框类型，详情自己去baidu
	borders.right= 1
	borders.top= 1
	borders.bottom= 1

	pattern = xlwt.Pattern() # 设置背景颜色
	pattern.pattern = xlwt.Pattern.SOLID_PATTERN #设置背景颜色的模式
	pattern.pattern_fore_colour = back_color # 背景颜色
	
	
	alignment = xlwt.Alignment()
	#alignment.horz = 0x01 #水平靠左
	alignment.horz = horz #0x02水平居中
	#alignment.horz = 0x03 #水平靠右
	
	#alignment.vert =  0 #垂直偏上 
	alignment.vert =  vert #垂直居中
	#alignment.vert =  2 #垂直偏下

	style.alignment = alignment
	style.pattern = pattern 
	style.font = font
	style.borders = borders
 
	return style

def translate_str():
	global query_str
	query_str=query_str.replace('merged','MERGED')
	query_str=query_str.replace('open','NEW')
	query_str=query_str.replace('abandoned','ABANDONED')


def create_worksheet():
	global workbook,worksheet
	#style=set_style('Times New Roman',440,0x7F00,False)
	head_style=set_style('Arial',440,4,3,False,2,1)
	workbook = xlwt.Workbook(encoding = 'utf-8')
	worksheet = workbook.add_sheet('My Worksheet')
	worksheet.col(0).width=256*18 #列宽
	worksheet.col(1).width=256*100 #列宽
	worksheet.col(2).width=256*18 #列宽
	worksheet.col(3).width=256*50 #列宽
	worksheet.col(4).width=256*18 #列宽
    worksheet.row(0).set_style(xlwt.easyxf('font:height 720;')) #行高
	worksheet.write(0,0, 'number',head_style)
	worksheet.write(0,1, 'subject',head_style)
	worksheet.write(0,2, 'domain',head_style)
	worksheet.write(0,3, 'project',head_style)
	worksheet.write(0,4, 'track_id',head_style)

def get_total_result():
	sshstring='ssh -p 29418 androidhub.harman.com gerrit query %s --format JSON --current-patch-set | grep -v runTimeMilliseconds >temp.txt' % query_str
	process = subprocess.Popen(sshstring, shell=True,stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
	process.wait()

def save_workbook():
	cell_style=set_style('Arial',220,0,1,False,2,1)
	na_cell_style=set_style('Arial',220,0,2,False,2,1)
	index=0
	with open('temp.txt') as input_file:
		for i in input_file:
			if i is not None:
				number=json.loads(i)['number']
				subject=json.loads(i)['subject']
				commit_line=json.loads(i)['commitMessage'].splitlines()
				project_name=json.loads(i)['project']
				index +=1
				print index
				print number
				#time.sleep(0.1)
				domain_flag=False
				for line in commit_line:
					#if len(re.findall(r'Domain[ :]',line,re.I)) != 0:
					if len(re.findall(r'Domain[ :]',line)) != 0:
						domain=re.split('[ :]',line)[-1]
						if not domain:
							print "error,can not find domain for %s" % number
							#sys.exit()
							domain='NA'
						domain_flag=True
						worksheet.write(index,2,domain,cell_style)
						break
				if domain_flag == False:
					worksheet.write(index,2,'NA',na_cell_style)
				worksheet.write(index,0,number,cell_style)
				worksheet.write(index,1,subject,set_style('Arial',220,0,1,False,1,1))
				worksheet.write(index,3,project_name,set_style('Arial',220,0,1,False,1,1))
				track_id_flag=False
				for line in commit_line:
					if len(re.findall(r'Tracki+ng-Id[ :]|Tracked-On[ :]',line)) != 0:
						track_id=re.split('[ :]',line)[-1]
						if not track_id:
							print "error,can not find track_id for %s" % number
							track_id='NA'
						if track_id == 'NA' or track_id == 'None':
							worksheet.write(index,4,track_id,na_cell_style)
						else:
							worksheet.write(index,4,track_id,cell_style)
						track_id_flag=True
						break
				if track_id_flag == False:
					worksheet.write(index,4,'NA',na_cell_style)
						

	workbook.save('search_result.xls')
	print "生成物:search_result.xls"

if __name__ == "__main__":
	translate_str()
	print query_str
	get_total_result()
	create_worksheet()
	save_workbook()
