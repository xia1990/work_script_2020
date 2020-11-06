#!/usr/bin/python
#_*_ coding:utf-8 _*_

from xml.etree import ElementTree as ET
import xlwt


tree=ET.parse("sha1_embedded_manifest.xml")
root=tree.getroot()


def parse_ManifestXml():
	#遍历project节点
	index=0
	for project in root.iter("project"):
		index+=1
		name=project.attrib.get("name")
		path=project.attrib.get("path")
		revision=project.attrib.get("revision")
		worksheet.write(index,0,name)
		worksheet.write(index,1,path)
		worksheet.write(index,2,revision)
	workbook.save("repo_list.xls")

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

def write_excel():
	global workbook
	global worksheet
	workbook=xlwt.Workbook()
	worksheet=workbook.add_sheet('My Sheet')
	title=["REPO NAME","REPO PATH","REVISION"]
	#写入表格头部
	for t in range(0,len(title)):
		worksheet.write(0,t,title[t],set_style('Times New Roman',400,True))
	workbook.save("repo_list.xls")
		

#################################################################################
if __name__=="__main__":
	write_excel()
	parse_ManifestXml()
