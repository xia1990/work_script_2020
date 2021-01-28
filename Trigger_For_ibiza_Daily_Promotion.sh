#!/usr/bin/python

import jenkins
import requests
import sys
import os

JENKINS_URL="http://jenkins.mot.com"
USER="zhangl19"
PASSWORD="poiuyt@8"
P_JOB=os.environ["P_JOB"]
S_JOB=os.environ["S_JOB"]
BUILD_ID=os.environ["BUILD_ID"]


#得到jenkins服务
server=jenkins.Jenkins(JENKINS_URL,username=USER, password=PASSWORD)
param_dict={'BUILD_NUM_PROMOTION': BUILD_ID}

def main():
	print("主函数开始")
    #得到指定构建JOB的结果
	result=server.get_build_info(P_JOB,int(BUILD_ID))['result']
	if result=="SUCCESS":
	#启动一个JOB，并将当前构建成功的job id传给新job
		print("启动daily job")
		server.build_job(S_JOB,parameters=param_dict)
	elif result=="FAILURE":
		result=server.get_build_info(P_JOB,int(BUILD_ID+1))['result']
		if result=="SUCCESS":
			server.build_job(S_JOB,param_dict=param_dict)
		elif result=="FAILURE":
			result=server.get_build_info(P_JOB,int(BUILD_ID+2))['result']
			if result=="SUCCESS":
				server.build_job(S_JOB,param_dict=param_dict)
			else:
				print("代码错误，请检查!")


if __name__=="__main__":
	main()
