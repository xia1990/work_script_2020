#!/bin/bash -x 

case $MANIFEST in
q)
    MANIFEST="manifest/q"
    NEW_MANIFEST="r-6125.xml"
    ;;  
r)
    MANIFEST="manifest/r"
    NEW_MANIFEST="r-qsm2021.xml"
    ;;  
esac


git clone ssh://gerrit.mot.com/home/repo/dev/platform/android/platform/${MANIFEST} -b $TAG manifest
exit
cd manifest
	git checkout -b $BRANCH
    git push origin $BRANCH:$BRANCH
    
    cp sha1_embedded_manifest.xml  $NEW_MANIFEST
    git add $NEW_MANIFEST
    git commit -m "pull point branch on $BRANCH"
    git push origin HEAD:refs/heads/$BRANCH
    
    REVISION=`cat $NEW_MANIFEST | grep "$PROJECT" | grep -aoe "revision=[a-zA-Z0-9\.\"\"\/\-]*" | awk -F'"' '{print $2}'`
    UPSTREAM=`cat $NEW_MANIFEST | grep "$PROJECT" | grep -aoe "upstream=[a-zA-Z0-9\.\"\"\/\-]*" | awk -F'"' '{print $2}'`
    #删掉最后一个/  及其左边的字符串
    UP=${UPSTREAM##*/}
    if [ $POINT == "false" ];then
		ssh -p 29418 gerrit.mot.com gerrit create-branch $PROJECT $BRANCH $REVISION
    else
    	ssh -p 29418 gerrit.mot.com gerrit create-branch $PROJECT $BRANCH/$UP $REVISION
    fi
cd -