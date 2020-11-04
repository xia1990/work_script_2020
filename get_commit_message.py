#!/usr/bin/python
#_*_ coding:utf-8 _*_
f = file("abc.txt")

flist=f.readlines() #存放文件内容的list, flist下标最大值是比 len(flist) 小1的哦

index_list=[] #用来存放 flist中 changed from 和 project 所在flist位置的list ,里面放的都是 对flist有意义的下标

total_line=len(flist) #文件总行数

for index,line in enumerate(flist):
    if line != "":
        if line.find("changed from") != -1:
            index_list.append(index)  #将changed from 在 flist中的下标 放到新的 index_list 中

for index_list_index,file_list_index in enumerate(index_list): #从index_list 中取出 index_list自己的下标, 和存放的 flist中 changed from 的下标

    project=flist[file_list_index].split()[0]

    if not index_list_index == len(index_list) -1: #如果是最后一行changed from
        print flist[file_list_index+1:index_list[index_list_index+1]-2 + 1]  # -2 是 commit_id 所在行 在下一个changed from 的上2行,+1 是 切片必须比实际位置多一个才能包含实际位置
        #列表切片表示法
        commit_list=flist[file_list_index+1:index_list[index_list_index+1]-2 + 1]
        if (len(commit_list)) == 0: #打印commit 空行
            print file_list_index+1
            print commit_list[0]
    else:
        print flist[file_list_index+1:total_line - 1 - 1 + 1][0].split()[1] # -1 是因为 total_line 比flist最大下标是大1的  : -1 是因为文件最后一行 上一行才是 commit_id : +1 是 切片必须比实际位置多一个才能包含实际位置
