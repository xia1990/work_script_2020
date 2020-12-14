#!/bin/bash
#create for sofiap+

PROJECT=$1
BRANCH=$2
XML="r-6125.xml"
SSH_URL="ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/platform/manifest/q"

function usage(){
	echo "arge1:PROJECT"
	echo "arge2:BRANCH"
	echo "./create_branch.sh PROJECT BRANCH"
}

function git_clone(){
	if [ ! -d "q" ];then
		git clone $SSH_URL -b $BRANCH
	else
		rm -rf q
		git clone $SSH_URL -b $BRANCH
	fi
}

function main(){
	cd q
		REVISION=`cat $XML | grep "$PROJECT" | grep -aoe "revision=[a-zA-Z0-9\.\"\"\/\-]*" | awk -F'"' '{print $2}'`
		UPSTREAM=`cat $XML | grep "$PROJECT" | grep -aoe "upstream=[a-zA-Z0-9\.\"\"\/\-]*" | awk -F'"' '{print $2}'`
		echo "$rev:upstream"

		if [ $PROJECT != "" and $BRANCH != "" and $REVISION != "" ];then
			echo "begin create branch"
			ssh -p 29418 gerrit.mot.com gerrit create-branch $PROJECT $BRANCH/$UPSTREAM $REVISION
		else
			echo "args error"
			exit
		fi

		len_rev=${#rev}
		if [ $rev == $len_rev ];then
			echo "$BRANCH/$upstream"
			sed -i "s/revision=\"$revision\"/revision=\"$BRANCH\/$upstream\"/" $XML
			sed -i "s/upstream=\"$upstream\"/upstream=\"$BRANCH\/$upstream\"/" $XML
			echo "$BRANCH/$upstream"
			echo "==========================="
			git status
			cat r-6125.xml
			git add r-6125.xml
		fi
	cd -
}


################################################
if [ $# == 2 ];then
	git_clone
	#main
else
	echo "please input PROJECT and BRANCH"
	usage
	exit
fi
