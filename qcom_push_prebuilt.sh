#!/bin/bash
export top_dir=$(pwd)
export PATH=/usr/bin:$PATH
export PATH=/apps/android/bin:$PATH

#GREASE_SERVER="199.106.109.59"
GREASE_SERVER="grease-sd-stg.qualcomm.com"

printf "\n=== Parameters ===\ntag:\t\t${TAG}\ntarget branch:\t${BRANCH}\nqssi_tag:\t\t${QSSI_TAG}\nqssi_target branch:\t${QSSI_BRANCH}\nrelease:\t${RELEASE}\ngit path:\t${PREBUILT_PATH}\n==================\n\n"
#If sepcify QSSI tag, then perform check in QSSI prebuilt and merge with vendor prebuilt
if [[ $QSSI_BRANCH ]];
then
   export check_in_qssi_prebuilt=true
fi

function remove_existed_prebuilt_grease {
    rm -rf ${top_dir}/platform/vendor/qcom/proprietary/
    mkdir -p ${top_dir}/platform/vendor/qcom/proprietary/
    cd ${top_dir}/platform/vendor/qcom/proprietary/
    git clone ssh://gerrit.mot.com:29418/$PREBUILT_PATH $PREBUILT_NAME
}

function check_in_prebuilt_grease {
    p_branch=$1
    p_tag=$2
    printf "\n=== Check in ===\n Branch:\t${p_branch}\n Tag:\t${p_tag}\n==================\n\n"

    cd $top_dir
    wget --continue --no-check-certificate --user=motorola --password=lyc0hP1J https://${GREASE_SERVER}/binaries/outgoing/CDR006/$p_branch/prebuilt_CDR006_$p_tag.tar.xz

    cd ${top_dir}/platform/vendor/qcom/proprietary/$PREBUILT_NAME
    export branch_exists=`git branch -r --list origin/qc/$p_branch`

    if [[ $branch_exists ]];
    then
        git checkout origin/qc/$p_branch    
    fi

    cd ${top_dir}/platform/
    # Remove the current prebuilts

    if [[ -d ${top_dir}/platform/vendor/qcom/proprietary/${PREBUILT_NAME} ]];
    then
        rm -rf ${top_dir}/platform/vendor/qcom/proprietary/${PREBUILT_NAME}/*    
    fi

    tar -xvf ../prebuilt_CDR006_$p_tag.tar.xz

    cd ${top_dir}/platform/vendor/qcom/proprietary/$PREBUILT_NAME

    # Remove the symbols. They're too big to check in.
    for dir in target/product/*/
    do
        dir=${dir%*/}
        echo ${dir##*/}

        rm -rf  target/product/${dir##*/}/symbols
    done

    # Add the prebuilt.mk build id file
    echo "### DO NOT MODIFY - MOTOROLA AUTO-GENERATED!!!" > prebuilt.mk
    echo "### This file is automatically regenerated by Motorola" >> prebuilt.mk
    echo "### each QCOM merge.  All modifications will be lost." >> prebuilt.mk
    echo "" >> prebuilt.mk
    echo "# QCOM AP build ID" >> prebuilt.mk
    echo "PRODUCT_PROPERTY_OVERRIDES += \\"  >> prebuilt.mk
    if [[ $p_branch == *"QSSI"* ]]; then
        echo "    ro.system.build.version.qcom=${p_tag}" >> prebuilt.mk
    else
        echo "    ro.vendor.build.version.qcom=${p_tag}" >> prebuilt.mk
    fi

    git add -A
    git commit -m "QCOM $RELEASE $p_tag"
    git push origin HEAD:refs/heads/qc/$p_branch

    git tag qc/$p_tag -a -m "$p_tag"
    git push origin tag qc/$p_tag
}

function merge_qssi_vendor_prebuilt {
    p_branch=$1
    p_tag=$2
    p_qssi_branch=$3
    p_qssi_tag=$4
    printf "\n=== Merge ===\nVendor tag:\t\t${p_tag}\nQssi tag:\t${p_qssi_tag}\n==================\n\n"

    cd ${top_dir}/platform/vendor/qcom/proprietary/${PREBUILT_NAME}

    #Commit merge
    git checkout qc/${p_tag}
    git checkout qc/${p_qssi_tag} target/product/qssi
    # Update the prebuilt.mk build id file
    echo "PRODUCT_PROPERTY_OVERRIDES += \\"  >> prebuilt.mk
    echo "    ro.system.build.version.qcom=${p_qssi_tag}" >> prebuilt.mk
    git add -A
    git commit -m "Merge ${p_tag} with ${p_qssi_tag}"
    git merge -Xours origin/qc/${p_branch}_${p_qssi_branch}
    git push origin HEAD:refs/heads/qc/${p_branch}_${p_qssi_branch}

    #Commit tag
    git tag qc/${p_tag}_${p_qssi_tag} -a -m "${p_tag}_${p_qssi_tag}"
    git push origin tag qc/${p_tag}_${p_qssi_tag}
}

#Clean current workspace
remove_existed_prebuilt_grease
check_in_prebuilt_grease ${BRANCH} ${TAG}

#Perform check in QSSI prebuilt and merge with vendor prebuilt
if [[ "$check_in_qssi_prebuilt" ]];
then
    check_in_prebuilt_grease ${QSSI_BRANCH} ${QSSI_TAG}
    merge_qssi_vendor_prebuilt ${BRANCH} ${TAG} ${QSSI_BRANCH} ${QSSI_TAG}
fi