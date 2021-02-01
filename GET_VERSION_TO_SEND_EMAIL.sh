#!/bin/bash

echo "========================获取版本号操作====================="
cd $PWD
    echo "---------"
    pwd
    echo "---------"
    dir="build_ids"
    if [ ! -d $dir ]
    then
    	git clone ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/motorola/build_ids -b 	mr-2021-q1/br-4350
    else
    	rm -rf  $dir
        git clone ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/motorola/build_ids -b 	mr-2021-q1/br-4350
    fi
	cd ./build_ids
    	echo "------------------"
        pwd
    	NEXT_VERSION=`cat build_id-br-ibiza.mk | grep "BUILD_ID=\$(BUILD_ID_PREFIX)" | awk -F'-' '{print $2}' `
        #CURRENT_VERSION=RRF31.Q1-$((NEXT_VERSION-1))
        CURRENT_VERSION=RRF31.Q1-$NEXT_VERSION
        echo $CURRENT_VERSION
        
        echo "VERSION=$CURRENT_VERSION" > $WORKSPACE/ENV.txt
    cd -   
	
cd -
echo "========================获取版本号操作====================="


