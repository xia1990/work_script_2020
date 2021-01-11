#!/bin/bash -x 

if [[ -z $PROJECT ]] || [[ -z $BRANCH ]]
then
	echo "请输入要拉取的分支名称和PROJECT名称"
    exit 1
fi

case $MANIFEST in
Q)
    MANIFEST="manifest/q"
    NEW_MANIFEST="r-6125.xml"
    ;;  
R)
    MANIFEST="manifest/r"
    NEW_MANIFEST="r-qsm2021.xml"
    ;;  
esac

git clone ssh://gerrit.mot.com/home/repo/dev/platform/android/platform/${MANIFEST} -b $BRANCH manifest

function main(){
	cd manifest
    REVISION=`cat $NEW_MANIFEST | grep "$PROJECT" | grep -aoe "revision=[a-zA-Z0-9\.\"\"\/\-]*" | awk -F'"' '{print $2}'`
    UPSTREAM=`cat $NEW_MANIFEST | grep "$PROJECT" | grep -aoe "upstream=[a-zA-Z0-9\.\"\"\/\-]*" | awk -F'"' '{print $2}'`
    #删掉最后一个/  及其左边的字符串
    UP=${UPSTREAM##*/}
    if [ $POINT == "false" ];then
		ssh -p 29418 gerrit.mot.com gerrit create-branch $PROJECT $BRANCH $REVISION
    else
    	ssh -p 29418 gerrit.mot.com gerrit create-branch $PROJECT $BRANCH/$UP $REVISION
    fi

	echo "begin update xml"
		sed -i "s/revision=\"$REVISION\"/revision=\"$BRANCH\/$UP\"/" $XML
		sed -i "s/upstream=\"$UPSTREAM\"//" $XML
		echo "==========================="
		git status
        git diff $NEW_MANIFEST
		git add $NEW_MANIFEST
	cd -
}


################################################
main
