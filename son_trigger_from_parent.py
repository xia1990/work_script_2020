#!/usr/bin/python3
#_*_coding:utf-8_*_
import jenkins
import sys

server = jenkins.Jenkins('http://192.168.137.19:8080',username="jenkins",password="jenkins",timeout=10)
JOB_BUILD_ID=sys.argv[1]
print(JOB_BUILD_ID)
JOB_NAME="HELLO_WORLD"
SON_JOB="SON_JOB"

def getBuildResult(job_name,job_build_id):
	try:
		result=server.get_build_info(job_name,int(job_build_id))
		return result
	except jenkins.JenkinsException:
		print("%s build %s in the queue;stop this job" % (JOB_NAME,JOB_BUILD_ID))
		sys.exit(0)

result=getBuildResult(JOB_NAME,JOB_BUILD_ID)
if result["result"] == "SUCCESS":
	print("start son")
	server.build_job(SON_JOB)
elif result["result"] == "FAILED":
	result1=getBuildResult(JOB_NAME,int(JOB_BUILD_ID)+1)
	if result1["result"] == "SUCCESS":
		print("start son")
		server.build_job(SON_JOB)
	elif result1["result"] == "FAILED":
		result2=getBuildResult(JOB_NAME,int(JOB_BUILD_ID)+2)
		if result2["result"] == "SUCCESS":
			print("start son")
			server.build_job(SON_JOB)
		elif result2["result"] == "FAILED":
			pass
		else:
			print("job 还在编译,还没有结果")
			sys.exit(0)
	else:
		print("job 还在编译,还没有结果")
		sys.exit(0)
else:
	print("job 还在编译,还没有结果")
	sys.exit(0)
