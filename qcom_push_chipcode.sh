#!/bin/bash
export TOP_DIR=$(pwd)


export PATH=/usr/bin:$PATH
export PATH=/apps/android/bin:$PATH
#export PATH=/apps/android/python-3.7.3-x64/bin:$PATH

#This as conflict with the qcom build script
unset WORKSPACE
unset BUILD_ID

QCOM_CHIPCODE_URL=https://chipmaster2.qti.qualcomm.com/home2/git/motorola-mobility-llc
QCOM_CHIPCODE_MIRROR_URL=ssh://ilclbld116/home/hudsonmd/slave_workspace/qcom_repos
BUILT_SUPPORT_TOOL=ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/qcom/qcom_msm8960/non-HLOS/build_support.git

# Function to fetch chipcode 
Fetch_chipcode () {
	#Download the chipcode release from qcom mirror
	echo "Fetching ${QCOM_CHIPCODE_TAG}"
	if [ ! -z "${QCOM_CHIPCODE_SOURCE_NAME}" ]; then
    	#Try to download from mirror firstly, there is only source mirror so far
		git clone -b ${QCOM_CHIPCODE_TAG} ${QCOM_CHIPCODE_MIRROR_URL}/${QCOM_CHIPCODE_SOURCE_NAME} source
    	if [ $? -ne 0 ]; then
			#Then download from qcom chipcode website
			time git clone -b ${QCOM_CHIPCODE_TAG} --depth 1 ${QCOM_CHIPCODE_URL}/${QCOM_CHIPCODE_SOURCE_NAME} source
			if [ $? -ne 0 ]; then
        		echo "The following command failed:"
        		echo "time git clone -b ${QCOM_CHIPCODE_TAG} --depth 1 ${QCOM_CHIPCODE_URL}/${QCOM_CHIPCODE_SOURCE_NAME} source"
				return 1
			fi
    	fi
	fi
	if [ ! -z "${QCOM_CHIPCODE_PREBUILT_NAME}" ]; then
		#Download prebuilt from chipcode website
		time git clone -b ${QCOM_CHIPCODE_TAG} --depth 1 ${QCOM_CHIPCODE_URL}/${QCOM_CHIPCODE_PREBUILT_NAME} prebuilt
		if [ $? -ne 0 ]; then
			echo "The following command failed:"
			echo "time git clone -b ${QCOM_CHIPCODE_TAG} --depth 1 ${QCOM_CHIPCODE_URL}/${QCOM_CHIPCODE_PREBUILT_NAME} prebuilt"
			return 1
		fi
	fi
	if [ ! -z "${QCOM_CHIPCODE_CAMX_NAME}" ]; then
		#Download camx from chipcode website
		time git clone -b ${QCOM_CHIPCODE_TAG} --depth 1 ${QCOM_CHIPCODE_URL}/${QCOM_CHIPCODE_CAMX_NAME} camx
		if [ $? -ne 0 ]; then
			echo "The following command failed:"
			echo "time git clone -b ${QCOM_CHIPCODE_TAG} --depth 1 ${QCOM_CHIPCODE_URL}/${QCOM_CHIPCODE_CAMX_NAME} camx"
			return 1
		fi
	fi
	if [ ! -z "${QCOM_CHIPCODE_CAMX_LIB_STATS}" ]; then
		#Download camx-lib-stats from chipcode website
		time git clone -b ${QCOM_CHIPCODE_TAG} --depth 1 ${QCOM_CHIPCODE_URL}/${QCOM_CHIPCODE_CAMX_LIB_STATS} camx-lib-stats
		if [ $? -ne 0 ]; then
			echo "The following command failed:"
			echo "time git clone -b ${QCOM_CHIPCODE_TAG} --depth 1 ${QCOM_CHIPCODE_URL}/${QCOM_CHIPCODE_CAMX_LIB_STATS} camx-lib-stats"
			return 1
		fi
	fi
	if [ ! -z "${QCOM_CHIPCODE_CAMSDK_NAME}" ]; then
		#Download chi-cdk from chipcode website
		time git clone -b ${QCOM_CHIPCODE_TAG} --depth 1 ${QCOM_CHIPCODE_URL}/${QCOM_CHIPCODE_CAMSDK_NAME} chi-cdk
		if [ $? -ne 0 ]; then
			echo "The following command failed:"
			echo "time git clone -b ${QCOM_CHIPCODE_TAG} --depth 1 ${QCOM_CHIPCODE_URL}/${QCOM_CHIPCODE_CAMSDK_NAME} chi-cdk"
			return 1
		fi
	fi
	if [ ! -z "${QCOM_CHIPCODE_CAM3A_NAME}" ]; then
		#Download cam-3a from chipcode website
		time git clone -b ${QCOM_CHIPCODE_TAG} --depth 1 ${QCOM_CHIPCODE_URL}/${QCOM_CHIPCODE_CAM3A_NAME} cam-3a
		if [ $? -ne 0 ]; then
			echo "The following command failed:"
			echo "time git clone -b ${QCOM_CHIPCODE_TAG} --depth 1 ${QCOM_CHIPCODE_URL}/${QCOM_CHIPCODE_CAM3A_NAME} cam-3a"
			return 1
		fi
	fi
    
}

#Checkout/update the current workspace
Checkout_chipcode () {
	echo "Check-out ${QCOM_CHIPCODE_TAG}"
	if [ -d source ]; then 
		(cd source; git reset --hard; git clean -xdf; git checkout ${QCOM_CHIPCODE_TAG})
		python build_support/bin/qc_version_stamp.py source
    fi
	if [ -d prebuilt ]; then 
		(cd prebuilt; git reset --hard; git clean -xdf; git checkout ${QCOM_CHIPCODE_TAG})
		python build_support/bin/qc_version_stamp.py prebuilt
    fi
	if [ -d camx ]; then 
		(cd camx; git reset --hard; git clean -xdf; git checkout ${QCOM_CHIPCODE_TAG})
		python build_support/bin/qc_version_stamp.py camx
    fi
	if [ -d camx_lib_stats ]; then 
		(cd camx_lib_stats; git reset --hard; git clean -xdf; git checkout ${QCOM_CHIPCODE_TAG})
		python build_support/bin/qc_version_stamp.py camx_lib_stats
    fi
	if [ -d chi-cdk ]; then 
		(cd chi-cdk; git reset --hard; git clean -xdf; git checkout ${QCOM_CHIPCODE_TAG})
		python build_support/bin/qc_version_stamp.py chi-cdk
    fi
 	if [ -d cam-3a ]; then 
		(cd cam-3a; git reset --hard; git clean -xdf; git checkout ${QCOM_CHIPCODE_TAG})
		python build_support/bin/qc_version_stamp.py cam-3a
    fi
	if [ ! -z "${COMMON_DISTRO_PATH}" ]; then
		for each_common_distro_path in $(echo ${COMMON_DISTRO_PATH} | sed "s/,/ /g")
		do
			cp -t source/${each_common_distro_path}/common source/about.html source/${each_common_distro_path}/*.xml || true
			cp -t prebuilt/${each_common_distro_path}/common prebuilt/about.html prebuilt/${each_common_distro_path}/*.xml || true
		done
	else
		cp -t source/common source/about.html source/*.xml || true
		cp -t prebuilt/common prebuilt/about.html prebuilt/*.xml || true        
	fi
	if [ ! -z "${APSS_BRANCH}" ]; then
		if [ -f source/${APSS_BRANCH}/LINUX/android/vendor/qcom/proprietary/vendorsetup.sh ]; then
			cp source/${APSS_BRANCH}/LINUX/android/vendor/qcom/proprietary/vendorsetup.sh source/LINUX/android/vendor/qcom/proprietary/common
		fi
		# Add the prebuilt.mk build id file
		echo "### DO NOT MODIFY - MOTOROLA AUTO-GENERATED!!!" > source/${APSS_BRANCH}/LINUX/android/vendor/qcom/proprietary/prebuilt_HY11/prebuilt.mk
		echo "### This file is automatically regenerated by Motorola" >> source/${APSS_BRANCH}/LINUX/android/vendor/qcom/proprietary/prebuilt_HY11/prebuilt.mk
		echo "### each QCOM merge.  All modifications will be lost." >> source/${APSS_BRANCH}/LINUX/android/vendor/qcom/proprietary/prebuilt_HY11/prebuilt.mk
		echo "" >> source/${APSS_BRANCH}/LINUX/android/vendor/qcom/proprietary/prebuilt_HY11/prebuilt.mk
		echo "# QCOM AP build ID" >> source/${APSS_BRANCH}/LINUX/android/vendor/qcom/proprietary/prebuilt_HY11/prebuilt.mk
		echo "PRODUCT_PROPERTY_OVERRIDES += \\"  >> source/${APSS_BRANCH}/LINUX/android/vendor/qcom/proprietary/prebuilt_HY11/prebuilt.mk
		echo "    ro.vendor.build.version.qcom=${TAG}" >> source/${APSS_BRANCH}/LINUX/android/vendor/qcom/proprietary/prebuilt_HY11/prebuilt.mk
	fi
}

#Check in
Checkin_chipcode () {
	/apps/android/python-3.7.3-x64/bin/python ${TOP_DIR}/${CHIPSET_FAMILY}/build_support/bin/qc_checkin.py checkin -v${QCOM_CHIPCODE_TAG} -l"${QCOM_CHIPCODE_TAG}" -c build_support/bin/${QCOM_CHECKIN_CFG}
	if [ $? -ne 0 ]; then
		echo "Cmd as below failed::::"
		echo "python ${TOP_DIR}/${CHIPSET_FAMILY}/build_support/bin/qc_checkin.py checkin -v${QCOM_CHIPCODE_TAG} -l${QCOM_CHIPCODE_TAG} -c build_support/bin/${QCOM_CHECKIN_CFG}"
		return 1
	fi
	return 0
}

#Push it
Push_chipcode () {
	/apps/android/python-3.7.3-x64/bin/python ${TOP_DIR}/${CHIPSET_FAMILY}/build_support/bin/qc_checkin.py push -c build_support/bin/${QCOM_CHECKIN_CFG}
	if [ $? -ne 0 ]; then
		echo "Cmd as below failed::::"
		echo "python ${TOP_DIR}/${CHIPSET_FAMILY}/build_support/bin/qc_checkin.py push -c build_support/bin/${QCOM_CHECKIN_CFG}"
		return 1
	fi
	return 0
}


printf "\n=== Parameters ===\nCheck in:\t${QCOM_CHIPCODE_TAG}\nFor:\t${CHIPSET_FAMILY}\nUsing config file:\t${QCOM_CHECKIN_CFG}\n==================\n\n"

#Clean up the workspace
rm -rf ${TOP_DIR}/${CHIPSET_FAMILY}
mkdir -p ${TOP_DIR}/${CHIPSET_FAMILY}
cd ${TOP_DIR}/${CHIPSET_FAMILY}
#Prepare build_support
git clone ${BUILT_SUPPORT_TOOL} -b master
#git clone ${BUILT_SUPPORT_TOOL} -b sandbox/zhangx21/sh2019-3.0

##test yaml change begin
#cd build_support
#git fetch ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/qcom/qcom_msm8960/non-HLOS/build_support refs/changes/74/1806274/2 && git cherry-pick FETCH_HEAD
#git fetch ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/qcom/qcom_msm8960/non-HLOS/build_support refs/changes/21/1770021/1 && git cherry-pick FETCH_HEAD
#git fetch ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/qcom/qcom_msm8960/non-HLOS/build_support refs/changes/39/1724539/1 && git checkout FETCH_HEAD -f
#git fetch ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/qcom/qcom_msm8960/non-HLOS/build_support refs/changes/29/1734729/3 && git cherry-pick FETCH_HEAD
#git fetch ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/qcom/qcom_msm8960/non-HLOS/build_support refs/changes/39/1724539/3 && git cherry-pick FETCH_HEAD
#cd -
##test yaml change end


#Fetch firstly
Fetch_chipcode
if [ $? -ne 0 ]; then
	echo "Failed to fetch the drop"
	exit 1
fi

#Workspace update
Checkout_chipcode
if [ $? -ne 0 ]; then
	echo "Failed to checkout the drop"
	exit 1
fi


##yangqh5 start##
cp -rf /localrepo/hudson/workspace/qcom_push_chipcode/SM2021/source/Mannar.LA.1.0/common/sectools /localrepo/hudson/workspace/qcom_push_chipcode/SM2021/source/ADSP.VT.5.4.2/adsp_proc
cp -rf /localrepo/hudson/workspace/qcom_push_chipcode/SM2021/source/Mannar.LA.1.0/common/sectools /localrepo/hudson/workspace/qcom_push_chipcode/SM2021/source/CDSP.VT.2.4.2/cdsp_proc
cp -rf /localrepo2/hudson/workspace/qcom_push_chipcode/SM2021/source/Mannar.LA.1.0/common/sectools /localrepo2/hudson/workspace/qcom_push_chipcode/SM2021/source/ADSP.VT.5.4.2/adsp_proc
cp -rf /localrepo2/hudson/workspace/qcom_push_chipcode/SM2021/source/Mannar.LA.1.0/common/sectools /localrepo2/hudson/workspace/qcom_push_chipcode/SM2021/source/CDSP.VT.2.4.2/cdsp_proc
###yangqh5 end##


#Checkin
Checkin_chipcode
if [ $? -ne 0 ]; then
	echo "Failed to check in the drop"
	exit 1
fi

#Push
Push_chipcode
if [ $? -ne 0 ]; then
	echo "Failed to push the drop"
	exit 1
fi