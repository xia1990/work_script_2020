#!/usr/bin/python3
#_*_coding:utf-8_*_
import jenkins
import sys
import time
import os

server = jenkins.Jenkins('http://192.168.56.101:8088',username="jenkins",password="jenkins",timeout=10)
JOB_BUILD_ID=os.environ["JOB_BUILD_ID"]
JOB_BUILD_ID=int(JOB_BUILD_ID)
JOB_NAME=os.environ["JOB_NAME"]
SON_JOB=os.environ["SON_JOB"]
level=0 #这个就是当前build失败后,用来定位下一个build的
print(type(JOB_BUILD_ID))


def getBuildQueueStatus(job_name):  #看看是否这个JOB在排队
	queue_list=server.get_queue_info()
	if len(queue_list) == 0: #没有任何JOB排队
		return false
	else:
		for item in queue_list:
			if item["task"]["name"] == job_name:
				return true #排队JOB里有一个我们的JOB (有一个就可以了)
		return false   #排队的JOB里没有我们这个JOB

#getBuildResult("continuous",32)
def getBuildResult(job_name,job_build_id):
	try:
		result=server.get_build_info(job_name,int(job_build_id))
		return result
	except jenkins.JenkinsException:  #没有找到这个BUILD,可能是在排队,或者真的这的没有编
		if getBuildQueueStatus(job_name):
			print("parent %s build %s in the queue;stop this thirdpartjob" % (job_name,job_build_id))  #真的在排队
			sys.exit(0)
		else:
			print("can not file %s %s" % (job_name,job_build_id)) #没有找到这个 BUILD
			sys.exit(0)
		print("*********************")	

def build_son(result,level):
	print(JOB_NAME,JOB_BUILD_ID+level,result["result"]) #打印当前build是否成功执行
	Flag="false"
	param_dict={'BUILD_NUM_PROMOTION':JOB_BUILD_ID+level}
	time.sleep(1)
	level=level+1
	if result["result"] == "SUCCESS":
		print("start son")
		server.build_job(SON_JOB,parameters=param_dict)
		Flag="true"
		if Flag=="true":
			print("-"*100)
			server.disable_job(JOB_NAME)
			sys.exit(0)
        #可以启动你需要启动的JOB
	elif result["result"] == "FAILURE": 
		subresult=getBuildResult(JOB_NAME,JOB_BUILD_ID+level)
		build_son(subresult,level)
	elif result["result"] == "ABORTED":
		print("job aborted")
		subresult=getBuildResult(JOB_NAME,JOB_BUILD_ID+level)
		build_son(subresult,level)
	else:
		print("build %s still building,please wait" % str(JOB_BUILD_ID+level-1))
		sys.exit(0)

if __name__ == "__main__":
	result=getBuildResult(JOB_NAME,JOB_BUILD_ID)
	build_son(result,level)
