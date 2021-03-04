#!/bin/bash  

PROJECT=$1
BRANCH=$2
TAG=$3
UPDATE_ID=$4
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

function Create_ManifestBranch(){
	cd $ROOTPATH
		if [ -d manifest ];then
			rm -rf manifest
			git clone ssh://gerrit.mot.com/home/repo/dev/platform/android/platform/${MANIFEST} manifest
		else 
			git clone ssh://gerrit.mot.com/home/repo/dev/platform/android/platform/${MANIFEST} manifest
		fi


		cd ./manifest
			git checkout $TAG
			git checkout -b $BRANCH
			git push origin $BRANCH:$BRANCH

			cp sha1_embedded_manifest.xml  $XML
			git add $XML
			git commit -m "pull point branch on $BRANCH"
			git push origin HEAD:refs/heads/$BRANCH
		cd -
	cd -
}

function Pull_Branch(){
	cd $ROOTPATH/manifest
		if [ $UPDATE_ID ];then
			REVISION1=`cat $XML | grep "motorola/build_ids" | grep -aoe "revision=[a-zA-Z0-9\.\"\"\/\-]*" | awk -F'"' '{print $2}'`
			UPSTREAM1=`cat $XML | grep "motorola/build_ids" | grep -aoe "upstream=[a-zA-Z0-9\.\"\"\/\-]*" | awk -F'"' '{print $2}'`
			#删掉最后一个/  及其左边的字符串
			UP=${UPSTREAM1##*/}
			P="home\/repo\/dev\/platform\/android\/motorola\/build_ids"
			if [ "$POINT" == "False" ];then
				ssh -p 29418 gerrit.mot.com gerrit create-branch home/repo/dev/platform/android/motorola/build_ids $BRANCH $REVISION1
				if [ $?==0 ];then
					echo "CREATE BUILD ID BRANCH SUCESSFULLY"
				fi
				echo "begin update xml"
				echo $REVISION1
				echo $UPSTREAM2
				sed -i "s#revision=\"$REVISION1\"#revision=\"$BRANCH\"#" $XML
				sed -i "/$P\"/s#upstream=\"$UPSTREAM1\"##"  $XML
				git diff $XML
			else
				ssh -p 29418 gerrit.mot.com gerrit create-branch home/repo/dev/platform/android/motorola/build_ids $BRANCH/$UP $REVISION1
				if [ $? == 0 ];then
					echo "CREATE BUILD ID BRANCH SUCESSFULLY"
				fi
				sed -i "s#revision=\"$REVISION1\"#revision=\"$BRANCH\/$UP\"#" $XML
				sed -i "/$P\"/s#upstream=\"$UPSTREAM1\"##" $XML
				git diff $XML
			fi
		else 
			continue
		fi
	cd -
}

function Pull_Branch_Main(){
	cd $ROOTPATH/manifest
		REVISION2=`cat $XML | grep -w $PROJECT\" | grep -aoe "revision=[a-zA-Z0-9\.\"\"\/\-]*" | awk -F'"' '{print $2}'`
		UPSTREAM2=`cat $XML | grep -w $PROJECT\" | grep -aoe "upstream=[a-zA-Z0-9\.\"\"\/\-]*" | awk -F'"' '{print $2}'`
		#删掉最后一个/  及其左边的字符串
		UP=${UPSTREAM2##*/}
		P=${PROJECT//\//\\/}

		if [ "$POINT" == "False" ];then
			ssh -p 29418 gerrit.mot.com gerrit create-branch $PROJECT $BRANCH $REVISION2
			if [ $?==0 ];then
				echo "分支创建成功！"
			fi
			echo "begin update xml"
			echo $REVISION2
			echo $UPSTREAM2
			sed -i "s#revision=\"$REVISION2\"#revision=\"$BRANCH\"#" $XML
			#sed -i "/$P\"/s#upstream=\"$UPSTREAM\"#upstream=\"$BRANCH\"#"  $XML
			sed -i "/$P\"/s#upstream=\"$UPSTREAM2\"##"  $XML
			git diff $XML
		else
			ssh -p 29418 gerrit.mot.com gerrit create-branch $PROJECT $BRANCH/$UP $REVISION2
			if [ $? == 0 ];then
				echo "分支创建成功！"
			fi
			sed -i "s#revision=\"$REVISION2\"#revision=\"$BRANCH\/$UP\"#" $XML
			sed -i "/$P\"/s#upstream=\"$UPSTREAM2\"##" $XML
			git diff $XML
		fi
	cd -
}


################################################
Create_ManifestBranch
Pull_Branch
Pull_Branch_Main
