#!/bin/bash
set +x

top_dir=$(pwd)

export PATH=/apps/android/bin:${HOME}/bin:${PATH}
export PATH=/apps/android/jdk1.6.0_24/bin:/apps/android/python-2.7.1-x64/bin:/apps/tools/scm_tools/hudson_tools/artifactory:$PATH 

# Clean-out
rm -rf ${top_dir}/platform
rm -rf ${top_dir}/release
rm -rf ${top_dir}/manifest

cd ${top_dir}
mkdir -p ${top_dir}/platform
mkdir -p ${top_dir}/release


echo "SMR for ${TARGET_PRODUCT} "



function usage {
       echo "The following parameters are mandatory: "
       echo "e.g mlmp-mr1-stable5"
       echo "e.g LPH23.116-13"
       echo "TARGET_PRODUCT: "
       echo "e.g clark_retus"       
       exit 1
}

# Make sure all parameters have values
if [[ -z ${NEW_MANIFEST_BRANCH} ]] || [[ -z ${BASE_BUILD_ID} ]] || [[ -z ${TARGET_PRODUCT} ]] || [[ -z ${NEW_BUILDID_BRANCH} ]] || [[ -z ${NEW_MANIFEST_XML} ]]|| [[ -z ${BLUR_VALUE} ]]
then
   usage
   exit 1
fi

# Make sure manifest branch is a stable branch
if [[ "${NEW_MANIFEST_BRANCH}" != *stable* ]]
then
   echo "TA_MANIFEST_BRANCH needs to be a stable branch"
   usage
   exit 1
fi 



export TARGET_DEVICE=${TARGET_PRODUCT%%_*}
export TARGET_REGION=${TARGET_PRODUCT#*_}


# Both parameters are defined
# mmnc_stable1_<base_buildid>
cd ${top_dir}/platform

case ${NEW_MANIFEST_BRANCH%%-*} in
  
  mo)
     export MANIFEST=manifest/o
     BLUR_MAJOR_NUMBER=27
     ;;     
  momr1)
     export MANIFEST=manifest/o
     BLUR_MAJOR_NUMBER=28
     ;;
  mp)
     export MANIFEST=manifest/o
     BLUR_MAJOR_NUMBER=29
     ;;
  mq)
     export MANIFEST=manifest/q
     BLUR_MAJOR_NUMBER=30
     ;;
  prodq)
     export MANIFEST=manifest/q
     BLUR_MAJOR_NUMBER=30
     ;;
  mr)
     export MANIFEST=manifest/r
     BLUR_MAJOR_NUMBER=31
     ;;
esac



# Clone manifest repo to check if manifest branch exists ...
echo "Clone manifest repo to check if manifest branch exists ..."
cd ${top_dir}

# Init from the base tag
git clone ssh://gerrit.mot.com/home/repo/dev/platform/android/platform/${MANIFEST} -b ${BASE_BUILD_ID}-${TARGET_DEVICE^^}-SHA1 manifest
cd manifest
[[ "$(cat sha1_embedded_manifest.xml|grep review|grep remote|grep origin)" != *home* ]] && export reference=home/repo/dev/platform/android/

   cd ${top_dir}/platform
   echo "Initializing workspace using refs/tags/${BASE_BUILD_ID}-${TARGET_DEVICE^^}-SHA1 ... "
   repo init --manifest-url=ssh://gerrit.mot.com/home/repo/dev/platform/android/platform/${MANIFEST} \
--repo-url=ssh://gerrit.mot.com/home/repo/dev/platform/android/repo.git --manifest-branch=refs/tags/${BASE_BUILD_ID}-${TARGET_DEVICE^^}-SHA1 \
--manifest-name=sha1_embedded_manifest.xml >> ${top_dir}/release/repo_sync.log 2>&1
echo "init over"

#Create build_ids branch and update manifest
   cd ${top_dir}/platform
   repo sync -c -j16 motorola/build_ids >> ${top_dir}/release/repo_sync1.log 2>&1
   cd motorola/build_ids
   git commit -a -m "[SCM]: Set BUILD_ID variable for  MR"
   git push origin HEAD:refs/heads/$NEW_BUILDID_BRANCH
   echo "Buildid brnach pushed $NEW_BUILDID_BRANCH"
   # Change the manifest to pick up that branch for motorola/build_ids
   cd ${top_dir}/platform/.repo/manifests
   # Need to copy manifest name to NEW_MANIFEST_XML
   cp sha1_embedded_manifest.xml $NEW_MANIFEST_XML.xml
   export MOT_BUILD_ID="<project groups=\"sdk,default\" name=\"${reference}motorola/build_ids\" path=\"motorola/build_ids\" revision=\"$NEW_BUILDID_BRANCH\"/>"
   perl -p -i -e 's#<project.*motorola/build_ids.*#$ENV{MOT_BUILD_ID}#' $NEW_MANIFEST_XML.xml

#Create manifest branch
   cd ${top_dir}/platform/.repo/manifests
   cp $NEW_MANIFEST_XML.xml ${top_dir}/release
   git checkout -b $NEW_MANIFEST_BRANCH 
   git commit -a -m "[SCM]: Base Branch for Point line: $NEW_MANIFEST_BRANCH"
   git push origin HEAD:refs/heads/$NEW_MANIFEST_BRANCH
   echo " manifest branch created : $NEW_MANIFEST_BRANCH"
   
 cd -  
# Init from the dummy tag
git clone ssh://gerrit.mot.com/home/repo/dev/platform/android/platform/${MANIFEST} -b ${DUMMY_BASE_TAG_SHA1}-${TARGET_DEVICE^^}-SHA1 manifest
cd manifest
[[ "$(cat sha1_embedded_manifest.xml|grep review|grep remote|grep origin)" != *home* ]] && export reference=home/repo/dev/platform/android/

   cd ${top_dir}/platform
   echo "Initializing workspace using dummy base tag refs/tags/${DUMMY_BASE_TAG_SHA1}-${TARGET_DEVICE^^}-SHA1 ... "
   repo init --manifest-url=ssh://gerrit.mot.com/home/repo/dev/platform/android/platform/${MANIFEST} \
--repo-url=ssh://gerrit.mot.com/home/repo/dev/platform/android/repo.git --manifest-branch=refs/tags/${DUMMY_BASE_TAG_SHA1}-${TARGET_DEVICE^^}-SHA1 \
--manifest-name=sha1_embedded_manifest.xml >> ${top_dir}/release/repo_sync.log 2>&1
echo "init over"
cd .repo/manifests
#Create a dummy base tag to speed up continuous build
   git tag -a ${DUMMY_TAG_SHA1}-${TARGET_DEVICE^^}-SHA1 -f -m "SCM: Base Tag for ${TARGET_DEVICE^^} point line" && git push origin tag ${DUMMY_TAG_SHA1}-${TARGET_DEVICE^^}-SHA1
   echo "Dummy tag pushed from" $DUMMY_BASE_TAG_SHA1


#Create a dummy base tag to speed up continuous build
   git tag -a ${DUMMY_TAG_SHA1_NEXT}-${TARGET_DEVICE^^}-SHA1 -f -m "SCM: Base Tag for ${TARGET_DEVICE^^} point line" && git push origin tag ${DUMMY_TAG_SHA1_NEXT}-${TARGET_DEVICE^^}-SHA1
   echo "Dummy tag pushed from" $DUMMY_BASE_TAG_SHA1


TAG_INFO=/proj/hudson01/hudson-test/workspace/hudson_build_config/${DUMMY_TAG_SHA1}-${TARGET_DEVICE}_tag_info.txt
echo "Reached tag"
# If the tag info file does not already exist, create it - Initialization - ONCE only
echo "CONVENTION               := STABLE
VERSION_BUILD            := ${VERSION_BUILD}
VERSION_BASE             := ${VERSION_BASE}
VERSION_SHA1             := ${TARGET_DEVICE^^}-SHA1
VERSION_PREVIOUS_TAG     := ${DUMMY_TAG_SHA1}-${TARGET_DEVICE^^}-SHA1
VERSION_MAJOR            := ${BLUR_MAJOR_NUMBER}
VERSION_MINOR            := $(echo "$BLUR_VALUE + 2" | bc)
VERSION_MINOR_SIGNED_CID := $(echo "$BLUR_VALUE + 1" | bc)
VERSION_MINOR_USERDEBUG  := $(echo "$BLUR_VALUE" | bc)" > ${TAG_INFO}

