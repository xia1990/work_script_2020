#!/bin/bash  

PROJECT=$1
BRANCH=$2
MANIFEST="R"
POINT="False"
PRODUCT="IBIZA"
ROOTPATH=`pwd`

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
    if [ $PRODUCT=="IBIZA" ];then
    	NEW_MANIFEST="r-qsm2021.xml"
    elif [ $PRODUCT=="CAPRI" ];then
    	NEW_MANIFEST="r-qsm2020.xml"
    elif [ $PRODUCT=="CAPRIP" ];then
    	NEW_MANIFEST="r-qsm2020.xml"
    else
    	echo "$NEW_MANIFEST"
    fi
    ;;  
esac

if [ -d manifest ];then
	rm -rf manifest
	git clone ssh://gerrit.mot.com/home/repo/dev/platform/android/platform/${MANIFEST} -b $BRANCH manifest
else 
	git clone ssh://gerrit.mot.com/home/repo/dev/platform/android/platform/${MANIFEST} -b $BRANCH manifest
fi

function main(){
	cd $ROOTPATH/manifest
		REVISION=`cat $NEW_MANIFEST | grep -w $PROJECT\" | grep -aoe "revision=[a-zA-Z0-9\.\"\"\/\-]*" | awk -F'"' '{print $2}'`
		UPSTREAM=`cat $NEW_MANIFEST | grep -w $PROJECT\" | grep -aoe "upstream=[a-zA-Z0-9\.\"\"\/\-]*" | awk -F'"' '{print $2}'`
		#删掉最后一个/  及其左边的字符串
		UP=${UPSTREAM##*/}
		#把PROJECT中的/全部替换成\/
		P=${PROJECT//\//\\\/}

		if [ "$POINT" == "False" ];then
			ssh -p 29418 gerrit.mot.com gerrit create-branch $PROJECT $BRANCH $REVISION
			if [ $?==0 ];then
				echo "分支创建成功！"
			fi
			echo "begin update xml"
			echo $REVISION
			echo $UPSTREAM
			sed -i "s#revision=\"$REVISION\"#revision=\"$BRANCH\"#" $NEW_MANIFEST
			P=${PROJECT//\//\\\/}
			#sed -i "/$P\"/s#upstream=\"$UPSTREAM\"#upstream=\"$BRANCH\"#"  $NEW_MANIFEST
			sed -i "/$P\"/s#upstream=\"$UPSTREAM\"##"  $NEW_MANIFEST
			git diff $NEW_MANIFEST
		else
			ssh -p 29418 gerrit.mot.com gerrit create-branch $PROJECT $BRANCH/$UP $REVISION
			if [ $?==0 ];then
				echo "分支创建成功！"
			fi
			sed -i "s#revision=\"$REVISION\"#revision=\"$BRANCH\/$UP\"#" $NEW_MANIFEST
			sed -i "/$P\"/s#upstream=\"$UPSTREAM\"##" $NEW_MANIFEST
			git diff $NEW_MANIFEST
		fi

	cd -
}


################################################
main
