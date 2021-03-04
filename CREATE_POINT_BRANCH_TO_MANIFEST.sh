#!/bin/bash -x 

BRANCH=$1
TAG=$2
MANIFEST="R"
POINT=False
PRODUCT="IBIZA"

case $MANIFEST in
Q)
    MANIFEST="manifest/q"
    XML="r-6125.xml"
    ;;  
R)
	MANIFEST="manifest/r"
    if [ $PRODUCT=="IBIZA" ];then
    	XML="r-qsm2021.xml"
    elif [ $PRODUCT=="CAPRI" ];then
    	XML="r-qsm2020.xml"
    elif [ $PRODUCT=="CAPRIP" ];then
    	XML="r-qsm2020.xml"
    else
    	echo "$XML"
    fi
    ;;
esac

if [ -d manifest ];then
	rm -rf manifest
	git clone ssh://gerrit.mot.com/home/repo/dev/platform/android/platform/${MANIFEST} manifest
else
	git clone ssh://gerrit.mot.com/home/repo/dev/platform/android/platform/${MANIFEST} manifest
fi

cd manifest
	git checkout $TAG
	git checkout -b $BRANCH
    git push origin $BRANCH:$BRANCH
    
    cp sha1_embedded_manifest.xml  $XML
    git add $XML
    git commit -m "pull point branch on $BRANCH"
    git push origin HEAD:refs/heads/$BRANCH
    
    REVISION=`cat $XML | grep "motorola/build_ids" | grep -aoe "revision=[a-zA-Z0-9\.\"\"\/\-]*" | awk -F'"' '{print $2}'`
    UPSTREAM=`cat $XML | grep "motorola/build_ids" | grep -aoe "upstream=[a-zA-Z0-9\.\"\"\/\-]*" | awk -F'"' '{print $2}'`
    #删掉最后一个/  及其左边的字符串
    UP=${UPSTREAM##*/}

    if [ $POINT == "True" ];then
    	ssh -p 29418 gerrit.mot.com gerrit create-branch home/repo/dev/platform/android/motorola/build_ids $BRANCH/$UP $REVISION
        if [ $? == 0 ];then
        	echo "BUILD_ID分支创建成功！"
        fi

		echo "begin update xml"
		sed -i "s#revision=\"$REVISION\"#revision=\"$BRANCH\/$UP\"#" $XML
		sed -i "#build_ids#s#upstream=\"$UPSTREAM\"##" $XML
	else
    	ssh -p 29418 gerrit.mot.com gerrit create-branch home/repo/dev/platform/android/motorola/build_ids $BRANCH $REVISION
		if [ $? == 0 ];then
			echo "BUILD ID BRANCH CREATE SUCESS"
		fi

		echo "begin update xml"
		sed -i "s#revision=\"$REVISION\"#revision=\"$BRANCH\"#" $XML
		sed -i "/build_ids/s#upstream=\"$UPSTREAM\"##" $XML
    fi

cd -
