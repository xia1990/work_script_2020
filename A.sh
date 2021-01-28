#!/usr/bin/python


import jenkins
import requests
import sys
import os

#JENKINS_URL="http://jenkins.mot.com"
JENKINS_URL="http://192.168.56.101:8088/"
USER="jenkins"
PASSWORD="jenkins"
JOB_NAME=os.environ["JOB_NAME"]
NEW_JOB_NAME=os.environ["NEW_JOB_NAME"]
BUILD_ID=os.environ["BUILD_ID"]


#得到jenkins服务
server=jenkins.Jenkins(JENKINS_URL,username=USER, password=PASSWORD)

def main():
	print("主函数开始")
    #得到指定构建JOB的结果
	result=server.get_build_info(JOB_NAME,int(BUILD_ID))['result']
	if result=="SUCCESS":
	#启动一个JOB，并将当前构建成功的job id传给新job
		print("启动daily job")
		param_dict={'para1': BUILD_ID}
		server.build_job(NEW_JOB_NAME,parameters=BUILD_ID)
	elif result=="FAILURE":
		result=server.get_build_info(JOB_NAME,int(BUILD_ID+1))['result']
		if result=="SUCCESS":
			server.build_job(NEW_JOB_NAME,{'para1': BUILD_ID})
		elif result=="FAILURE":
			result=server.get_build_info(JOB_NAME,int(BUILD_ID+2))['result']
			if result=="SUCCESS":
				server.build_job(NEW_JOB_NAME,{'para1': BUILD_ID})
			else:
				print("代码错误，请检查!")


if __name__=="__main__":
	main()
