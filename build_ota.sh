#!/bin/bash

# Function to isolate a zip file from a given string
# It will be used to get a real zip file from the string
# (i.e: A file that ends with zip) out from a string that
# may have a txt file with 'zip' in name. 
# For example:
#    string="file1.zip file2.zip.info.txt"
# It will return "file1.zip"
function get_zip_file(){
  full_line=$(echo $1 | tr ' ' '\n')
  for line in `echo $full_line`
  do
    if [[ "$line" == *.zip ]]; then
        echo $line
        break;
    fi
  done
}

#Send signal to devops on start of  ota creation
echo "Sending start signal to Devops"

echo "OTA_BUILD_ID=${OTA_BUILD_ID}"
echo "Curl to Devops1"
curl -X POST -H "Content-Type: application/json" -d "{\"BUILD_NUMBER\": ${BUILD_NUMBER}}" "http://devops.mot.com/ota/create_started/${OTA_BUILD_ID}?token=559cd9e4ccf77f1b484e090bfu01ced33efc9155" || true
echo "Curl to Devops2"
curl -X POST -H "Content-Type: application/json" -d "{\"BUILD_NUMBER\": ${BUILD_NUMBER}}" "http://ilcldevops02.mot.com/api/ota/create_started/${OTA_BUILD_ID}?token=ImFwcGRldm9wIg.7uarwvQhUJL3vrwmgTOC04Wd6sQ" || true


# set the value to map if this is a test run or production run
# if TEST run then set TEST_RUN="TRUE" else set it to FALSE 
export TEST_RUN="FALSE"

if  [ -z "${TEST_RUN// }" ];
then
    echo 'Decide if you are running test run or production look into TEST_RUN variable'
    exit 1
fi

export bota_script_success=""

# Export ADDITIONAL_COMMAND 
export ADDITIONAL_COMMAND=$additional_commands


# Clean workspace
top_dir=${WORKSPACE}
if  [ -z "${top_dir// }" ];
then
    echo 'dangerous zone top_dir is null or it has only spaces'
    exit 1
else
    rm -rf ${top_dir}/*
fi

# Create working directories

mkdir -p ${top_dir}/platform
mkdir -p ${top_dir}/release
mkdir -p ${top_dir}/platform/release
mkdir -p ${top_dir}/base_buildprop
mkdir -p ${top_dir}/target_buildprop
# Creating temp directory, to be used by ota.bash script
# Without it, the server's /tmp will be used and can lead
# to a out of space error.
mkdir -p ${top_dir}/temp
exec &> >(tee -a "${top_dir}/ota_generation_log.txt")


echo "product_variant             = ${product_variant}"
echo "source_artifactory_url      = ${source_artifactory_url}"
echo "destination_artifactory_url = ${destination_artifactory_url}"
echo "manifest_url                = ${manifest_url}"
echo "manifest_branch             = ${manifest_branch}"
echo "manifest_file               = ${manifest_file}"
echo "build_type                  = ${build_type}"
echo "build_config                = ${build_config}"
echo "signed_cid_value            = ${signed_cid_value}"
echo "destBlurVersion             = ${destBlurVersion}"
echo "SHA1_TAG                    = ${SHA1_TAG}"
echo "package_type                = ${package_type}"


# Mapping to existing variable
BASE_SERVER="production"
TARGET_SERVER="production"

if [[ ${source_artifactory_url} == "http://artifacts-test.mot.com"* ]]
then
   source_build_id=`echo ${source_artifactory_url} |awk -F'/' '{print $8}'`
else
   source_build_id=`echo ${source_artifactory_url} |sed 's/\/\//\//g' |awk -F'/' '{print $6}'`
fi


if [[ ${destination_artifactory_url} == "http://artifacts-test.mot.com"* ]]
then
   target_build_id=`echo ${destination_artifactory_url} |awk -F'/' '{print $8}'`
else
   target_build_id=`echo ${destination_artifactory_url} |sed 's/\/\//\//g' |awk -F'/' '{print $6}'`
fi


if [[ ${source_artifactory_url} == "https://artifacts-sa.mot.com"* ]]
then
   source_build_id=`echo ${source_artifactory_url} |awk -F'/' '{print $8}'`
   BASE_SERVER="shipping"
fi


if [[ ${destination_artifactory_url} == "https://artifacts-sa.mot.com"* ]]
then
   target_build_id=`echo ${destination_artifactory_url} |awk -F'/' '{print $8}'`
   TARGET_SERVER="shipping"
   server_to_upload=
fi


PRODUCT_CARRIER=${product_variant}
BRANCH=${manifest_branch}
BASE_FASTBOOT=`echo ${source_artifactory_url} |awk -F'artifactory/' '{print $NF}' | sed 's/\/\//\//g'`
TARGET_FASTBOOT=`echo ${destination_artifactory_url} |awk -F'artifactory/' '{print $NF}' | sed 's/\/\//\//g'`
SIGN_TYPE=${build_config}
UPLOAD_ARTI="OTA_FROM_"${source_build_id}"_TO_"${target_build_id}${package_sufix}
MANIFEST_FILE="sha1_embedded_manifest.xml"
NOGptCheck=""


# START CR IKSWP-22622 
# Fix for aljeter: If it is a BOTA from Android O to P, we need to add '--noGptCheck'
# But it may be already present, if the user have added it
if [[ $PRODUCT_CARRIER == *jeter* && $source_artifactory_url == *O[P,D,C]P*27* && $destination_artifactory_url == *P[P,D,C]P*29* ]]; then
   if [[ ! $ADDITIONAL_COMMAND =~ "--noGptCheck" ]]; then
       ADDITIONAL_COMMAND="$ADDITIONAL_COMMAND --noGptCheck "
       echo "**************** WARNING *******************"
       echo "*                                          *" 
       echo "* Adding '--noGptCheck' to the OTA command *"
       echo "*                                          *" 
       echo "********************************************" 
       NOGptCheck="with noGptCheck"
       
   fi
fi
# END CR IKSWP-22622 


if [[ $BASE_FASTBOOT == griffin/6.0* ]] && [[ $TARGET_FASTBOOT == griffin/7.0* ]]; then
    ADDITIONAL_COMMAND="$ADDITIONAL_COMMAND --product gpt"
fi

if [[ $BASE_FASTBOOT == lux/6.0* ]] && [[ $TARGET_FASTBOOT == lux/7.1.1* ]]; then
    if [[ $PRODUCT_CARRIER == lux_ret* ]]; then    
        ADDITIONAL_COMMAND="$ADDITIONAL_COMMAND -2"
    fi
fi

# Abort executiob if branch is for mediatek products
if [[ $BRANCH == prodn* ]]; then
    echo "**************************************************************"
    echo "ERROR: This job does not work for MediaTek products. Aborting."
    echo "**************************************************************"
    exit 1
fi

# if destBlurVersion is not null 

echo "source_build_id    =  ${source_build_id}"
echo "target_build_id    =  ${target_build_id}"
echo "PRODUCT_CARRIER    =  ${PRODUCT_CARRIER}"
echo "BRANCH             =  ${BRANCH}"
echo "BASE_FASTBOOT      =  ${BASE_FASTBOOT}"
echo "TARGET_FASTBOOT    =  ${TARGET_FASTBOOT}"
echo "SIGN_TYPE          =  ${SIGN_TYPE}"
echo "ADDITIONAL_COMMAND =  ${ADDITIONAL_COMMAND}"
echo "UPLOAD_ARTI        =  ${UPLOAD_ARTI}"
echo "MANIFEST_FILE      =  ${MANIFEST_FILE}"
echo "BASE_SERVER        =  ${BASE_SERVER}"
echo "TARGET_SERVER      =  ${TARGET_SERVER}"

##########################################

echo "Set build description as .: <font color=Maroon><b>${OTA_BUILD_ID} : ${product_variant}-${build_type} ${source_build_id} to  ${target_build_id} ${NOGptCheck} </b></font>"

## Define constants

test_artifact_server="http://artifacts-test.mot.com/artifactory/"
prod_artifact_server="http://artifacts.mot.com/artifactory/"

# This HOME setting will use filer to clone the repos

#export PATH=/apps/android/bin:${HOME}/bin:${PATH}
export PATH=/apps/android/git-1.8.0/bin:/apps/android/bin:${HOME}/bin:${PATH}
export PYTHON_HOME=/apps/android/python-2.7.14-x64/bin/python

git clone ssh://gerrit.mot.com/home/repo/scm/pre_build_scripts.git -b converge

echo "pre_build_scripts.git  is cloned"

cd ${top_dir}

export PATH=/apps/android/python-2.7.14-x64/bin:/apps/tools/scm_tools/hudson_tools/artifactory:$PATH 
#export PATH=/apps/tools/scm_tools/hudson_tools/artifactory:$PATH 

echo "**** Path env variable: $PATH"

export base_filepath=`echo $BASE_FASTBOOT |sed 's/\:/\//'`
export target_filepath=`echo $TARGET_FASTBOOT |sed 's/\:/\//'`

export base_filename=`echo $BASE_FASTBOOT |awk -F'/' '{print $NF}'`
export target_filename=`echo $TARGET_FASTBOOT |awk -F'/' '{print $NF}'`

export base_buildprop_path=`echo $BASE_FASTBOOT |sed -e "s/${base_filename}/build.prop/"`
export target_buildprop_path=`echo $TARGET_FASTBOOT |sed -e "s/${target_filename}/build.prop/"`

if [[ $TEST_RUN == TRUE ]]; then
    export upload_path="sandbox-public/"${target_filepath%/*}
else
    export upload_path=${target_filepath%/*}
fi

echo $upload_path

echo "Download fastboot and build.prop"

echo "execute download -artifactory_path="${base_filepath}" -local_location ${top_dir} -server="${BASE_SERVER}""
execute download -artifactory_path="${base_filepath}" -local_location ${top_dir} -server="${BASE_SERVER}" || (echo "**** ERROR TO DOWNLOAD SOURCE FASTBOOT ****" && exit 1)

echo "execute download -artifactory_path="${target_filepath}" -local_location ${top_dir} -server="${TARGET_SERVER}""
execute download -artifactory_path="${target_filepath}" -local_location ${top_dir} -server="${TARGET_SERVER}"  || (echo "**** ERROR TO DOWNLOAD TARGET FASTBOOT ****" && exit 1)

#export base_blurver=`cat ${top_dir}/base_buildprop/build.prop | grep ro.build.version.full | cut -d = -f2 | sed -e 's/Blur_Version.//' | grep -o -E '^[0-9]+.[0-9]+.[0-9]+' | head -1 | sed -e 's/^0\+//' `
#export target_blurver=`cat ${top_dir}/target_buildprop/build.prop | grep ro.build.version.full | cut -d = -f2 | sed -e 's/Blur_Version.//' | grep -o -E '^[0-9]+.[0-9]+.[0-9]+' | head -1 | sed -e 's/^0\+//' `

#echo "base_blurver is $base_blurver"
#echo "target_blurver is $target_blurver"

#export base_major=`echo $base_blurver |cut -d . -f1 `
#export target_major=`echo $target_blurver |cut -d . -f1 `

#export base_minor=`echo $base_blurver |cut -d . -f2 `
#export target_minor=`echo $target_blurver |cut -d . -f2 `

#export base_num=`echo $base_blurver |cut -d . -f3 `
#export target_num=`echo $target_blurver |cut -d . -f3 `

export good_blurver="true"

#if [[ $ADDITIONAL_COMMAND != *--destBlurVersion* ]] ; then
#if (( $target_major > $base_major )) ; then
#    echo Target blur version is higher than base, proceed to OTA generation
#    export good_blurver="true"
#elif (( $target_major < $base_major )) ; then
#   echo ERROR Target major blur version is less than base. Pls increment target BVS or set --destBlurVersion in ADDITIONAL_COMMAND
#    export good_blurver="false"
#elif (( $target_major == $base_major )) ; then
#        if (( $target_minor > $base_minor )) ; then
#            echo Target blur version is higher than base, proceed to OTA generation
#             export good_blurver="true"
#         elif (( $target_minor < $base_minor )) ; then
#             echo ERROR Target minor blur version is less than base. Pls increment target BVS or set --destBlurVersion in ADDITIONAL_COMMAND
#             export good_blurver="false"
#         elif (( $target_minor == $base_minor )) ; then
#                if (( $target_num <= $base_num )) ; then
#                    echo ERROR Target blur version is not higher than base. Pls increment target BVS or set --destBlurVersion in ADDITIONAL_COMMAND
#                    export good_blurver="false"
#                else
#                    echo Target blur version is higher than base, proceed to OTA generation
#                    export good_blurver="true"
#               fi
#         fi
#fi
#fi

if [ ! -z "${destBlurVersion}" ]; then

      BLUR_MAJOR=$(echo $destBlurVersion | awk -F . '{print $1}')
     BLUR_MIDDLE=$(echo $destBlurVersion | awk -F . '{print $2}')
      BLUR_MINOR=$(echo $destBlurVersion | awk -F . '{print $3}')
     ADDITIONAL_COMMAND="$ADDITIONAL_COMMAND --oemTargetBlur 0=$BLUR_MAJOR:1=$BLUR_MIDDLE:2=$BLUR_MINOR"
     #ADDITIONAL_COMMAND="$ADDITIONAL_COMMAND --destBlurVersion $destBlurVersion"
     
fi

echo $ADDITIONAL_COMMAND    

if [[ $good_blurver == true ]]; then
{
 export DELTA_SYSTEM=${top_dir}/$base_filename
 export SOURCE_SYSTEM=${top_dir}/$target_filename
 #echo BOTA between $base_filename and $target_filename
 echo BOTA for $UPLOAD_ARTI

if [[ $PRODUCT_CARRIER == quark* ]]; then
    ADDITIONAL_COMMAND="$ADDITIONAL_COMMAND --product quark"
fi


if (( $PRODUCT_CARRIER != "athene_retail_df")) || (( $PRODUCT_CARRIER == "griffin" )) || (( $PRODUCT_CARRIER == "athene" )) ; then
    if [[ $SIGN_TYPE == *release* ]]; then
        ADDITIONAL_COMMAND="$ADDITIONAL_COMMAND --noHabCheck"
    fi
fi


if [ "$ADDITIONAL_COMMAND" != "" ]; then
    # When triggering from platform dashboard, white spaces are replaced by %20.
    # So, lets change it back to white space
    export ADDITIONAL_COMMAND=`echo "$ADDITIONAL_COMMAND" | sed 's/%20/ /g'`
fi

cd ${top_dir}/platform

# THIS IS A MAJOR HACK - Use manifest_file
MANIFEST_REPO="home/repo/dev/platform/android/platform/manifest"
if [[ $BRANCH == mmnc* ]]; then
    MANIFEST_REPO="home/repo/dev/platform/android/platform/manifest/m"
fi
# THIS IS A MAJOR HACK - Use manifest_file
if [[ $BRANCH == mn* ]]; then
    MANIFEST_REPO="home/repo/dev/platform/android/platform/manifest/m"
fi
# THIS IS A MAJOR HACK - Use manifest_file
if [[ $BRANCH == zuk/* ]]; then
    MANIFEST_REPO="home/repo/dev/platform/android/platform/manifest/m"
fi

if [[ $BRANCH == "zuk-mp" ]]; then
    MANIFEST_REPO="home/repo/dev/platform/android/platform/manifest/o"
fi

if [[ $BRANCH == prodp* ]]; then
    MANIFEST_REPO="home/repo/dev/platform/android/platform/manifest/o"
fi

# THIS IS A MAJOR HACK - Use manifest_file
if [[ $BRANCH == mo* ]]; then
    MANIFEST_REPO="home/repo/dev/platform/android/platform/manifest/o"
fi
# THIS IS A MAJOR HACK - Use manifest_file
if [[ $BRANCH == */mo* ]]; then
    MANIFEST_REPO="home/repo/dev/platform/android/platform/manifest/o"
fi
# THIS IS A MAJOR HACK - Use manifest_file
if [[ $BRANCH == mp* ]]; then
    MANIFEST_REPO="home/repo/dev/platform/android/platform/manifest/o"
fi




# run repo init
echo "Running repo init"
echo "/apps/android/bin/repo init --manifest-url=${manifest_url} --repo-url=ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/repo.git --manifest-branch=refs/tags/$SHA1_TAG -m $MANIFEST_FILE"
#echo "/apps/android/bin/repo init --manifest-url=ssh://gerrit.mot.com:29418/${MANIFEST_REPO}.git --repo-url=ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/repo.git --manifest-branch=refs/tags/$SHA1_TAG -m $MANIFEST_FILE"

#/apps/android/bin/repo init --manifest-url=ssh://gerrit.mot.com:29418/${MANIFEST_REPO}.git --repo-url=ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/repo.git --manifest-branch=refs/tags/$SHA1_TAG -m $MANIFEST_FILE
/apps/android/bin/repo init --manifest-url=${manifest_url} --repo-url=ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/repo.git --manifest-branch=refs/tags/$SHA1_TAG -m $MANIFEST_FILE


# Using local manifest for hab_tools repo. It is needed for Ubuntu 18.
mkdir -p ${top_dir}/platform/.repo/local_manifests/
cp /apps/tools/scm_tools/hudson_tools/local_manifests/phone/hab_tools.xml ${top_dir}/platform/.repo/local_manifests/


if [[ $BRANCH == *mo* || $BRANCH == *mp* || $BRANCH == *mq* || $BRANCH == *prodp* || $BRANCH == *prodq*  || $BRANCH == *mr*  || $BRANCH == *refs/tags* ]]; then
    export REPOS_TO_SYNC="build/make motorola/build_ids motorola/build motorola/security/hab_cst_client motorola/security/certs"    
else    
    export REPOS_TO_SYNC="build      motorola/build_ids motorola/build motorola/security/hab_cst_client motorola/security/certs"
fi


#if [[ $BRANCH == mo* ]]; then
#    export REPOS_TO_SYNC="build/make motorola/build_ids motorola/build motorola/security/hab_cst_client motorola/security/certs"    
#else    
#if [[ $BRANCH == *prodp* ]]; then
#    export REPOS_TO_SYNC="build/make motorola/build_ids motorola/build motorola/security/hab_cst_client motorola/security/certs"
#else
#   if [[ $BRANCH == *mp* ]]; then
#       export REPOS_TO_SYNC="build/make motorola/build_ids motorola/build motorola/security/hab_cst_client motorola/security/certs"
#   else
#       export REPOS_TO_SYNC="build motorola/build_ids motorola/build motorola/security/hab_cst_client motorola/security/certs"
#   fi
#fi
#fi

# Sync all vendor/moto/* and device/moto/* repos
for i in `repo manifest | cat | sed -e 's/.*path="//' | sed -e 's/".*//' | grep "^[vd]e[nv][di][oc][re]\/moto\/"`
do
    REPOS_TO_SYNC="$REPOS_TO_SYNC $i"
done

## sync vendor/moto/* and device/moto/* on mr1 and later lines which has new manifest staructure
for i in `repo manifest | cat |grep -v path | sed -e 's/.*name="//' | sed -e 's/".*//' | grep "^[vd]e[nv][di][oc][re]\/moto\/"`
do
    REPOS_TO_SYNC="$REPOS_TO_SYNC $i"
done

echo "current working directory"

pwd

echo "Repos to sync :" $REPOS_TO_SYNC

#repo sync -c -j8 $REPOS_TO_SYNC > sync_log 2>&1
echo "Running /apps/android/bin/repo sync -c -j8 $REPOS_TO_SYNC > sync_log 2>&1"

/apps/android/bin/repo sync -c -j8 $REPOS_TO_SYNC > sync_log 2>&1



# START CR IKSWUP-5344 
# hack for aljeter
if [[ $PRODUCT_CARRIER == *jeter* && $destination_artifactory_url == *PPP29.55-25* ]]; then
       echo "**************** WARNING ***********************************"
       echo "*                                                          *" 
       echo "* Ashley HACK: CherryPicking IKSWUP-5344 and IKSWUP-5379   *"
       echo "*                                                          *" 
       echo "************************************************************" 
       cd ${top_dir}/platform/motorola/build
       git fetch ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/motorola/build_new refs/changes/96/1305296/7 && git cherry-pick FETCH_HEAD  
       cd -
fi

if [[ $PRODUCT_CARRIER == *jeter* && $destination_artifactory_url == *PPPS29.55-25* ]]; then
       echo "**************** WARNING ***********************************"
       echo "*                                                          *" 
       echo "* Ashley HACK: CherryPicking IKSWUP-5344 and IKSWUP-5379   *"
       echo "*                                                          *" 
       echo "************************************************************" 
       cd ${top_dir}/platform/motorola/build
       git fetch ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/motorola/build_new refs/changes/96/1305296/7 && git cherry-pick FETCH_HEAD  
       cd -
fi

# hack for ali
if [[ $PRODUCT_CARRIER == *ali* && $destination_artifactory_url == *PPS*29.55-24* ]]; then
       echo "**************** WARNING ***********************************"
       echo "*                                                          *" 
       echo "* Blaine HACK: CherryPicking IKSWUP-5344 and IKSWUP-5379   *"
       echo "*                                                          *" 
       echo "************************************************************" 
       cd ${top_dir}/platform/motorola/build
       git fetch ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/motorola/build_new refs/changes/05/1305305/5 && git cherry-pick FETCH_HEAD
       cd -
fi
# END CR IKSWUP-5344

# START GERRIT 1333032
if [[ $target_build_id == OPP28.44-26 || $target_build_id == OPPS28.44-26-2 || $target_build_id == OPPS28.44-26-4 || $target_build_id == OPPS28.44-26-6 ]]; then
       echo "**************** WARNING ***********************************"
       echo "*                                                          *" 
       echo "*  HACK: CherryPicking https://gerrit.mot.com/#/c/1333032/ *"
       echo "*                                                          *" 
       echo "************************************************************" 
       cd ${top_dir}/platform/build/make
       git fetch ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/platform/build refs/changes/32/1333032/1 && git cherry-pick FETCH_HEAD
       cd -    
fi
# END GERRIT 1333032


# START GERRIT 1455762
if [[ $target_build_id == PDSS29.118-15-11-* ]]; then
       echo "**************** WARNING ***********************************"
       echo "*                                                          *" 
       echo "*  HACK: CherryPicking https://gerrit.mot.com/#/c/1455762/ *"
       echo "*                                                          *" 
       echo "************************************************************" 
       cd ${top_dir}/platform/build/make
       git fetch ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/platform/build refs/changes/62/1455762/7 && git cherry-pick FETCH_HEAD
       cd -    
fi
# END GERRIT 1455762



# START GERRIT 1407331
#if [[ $target_build_id == PPP29.118-57 ]]; then
#       echo "**************** WARNING ***********************************"
#       echo "*                                                          *" 
#       echo "*  HACK: CherryPicking https://gerrit.mot.com/#/c/1407331/ *"
#       echo "*                                                          *" 
#       echo "************************************************************" 
#       cd ${top_dir}/platform/motorola/build
#       git fetch ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/motorola/build_new refs/changes/31/1407331/1 && git cherry-pick FETCH_HEAD
#       cd -    
#fi
# END GERRIT 1407331




# START CR IKSWP-34469 
#if [[ $PRODUCT_CARRIER == aljeter* && $destination_artifactory_url =~ "PPP29" ]]; then
#   echo "**************** WARNING ***********************"
#   echo "*                                              *" 
#   echo "* CPicking https://gerrit.mot.com/#/c/1265226/ *"
#   echo "*                                              *" 
#   echo "************************************************" 
#   cd ${top_dir}/platform/build/make
#   git fetch ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/platform/build refs/changes/26/1265226/4 && git cherry-pick FETCH_HEAD   
#   cd -    
#fi
# END CR IKSWP-34469

# START GERRIT 1407331 , to reduce package size as SMR missed fix https://idart.mot.com/browse/IKSWP-84048
if [[ $BRANCH == mp-stable6.2-PPS29.55-37-4-10 || $BRANCH == mp-stable6.3-PPP29.55-35-12-8 ]]; then
       echo "**************** WARNING *************************************************"
       echo "*                                                          *" 
       echo "* Blaine HACK: CherryPicking gerrit 1407331 as SMR missing IKSWP-84048   *"
       echo "*                                                          *" 
       echo "**************************************************************************" 
    cd ${top_dir}/platform/motorola/build
    git fetch ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/motorola/build_new refs/changes/31/1407331/1 && git cherry-pick FETCH_HEAD
    cd -
fi


# Cherrypick the fix for Ubuntu 14 and Ubuntu 18
# CR IKSWUP-4959
if [[ -d ${top_dir}/platform/motorola/build ]]; then
   echo " **** Cherry-pick fix for Ubuntu 14 and Ubuntu 18 *****"
   cd ${top_dir}/platform/motorola/build
   git fetch ssh://gerrit.mot.com:29418/home/repo/dev/platform/android/motorola/build_new refs/changes/57/1262357/4 && git cherry-pick FETCH_HEAD || git cherry-pick --abort || true 
   cd -
fi


echo "SIGN_TYPE is "$SIGN_TYPE

####### MBISSARO HACK FOR NEW SIGNING SERVER #############
sed -i 's/CST_SA_HOST = 10.181.214.137/CST_SA_HOST = 100.64.116.218/' motorola/security/hab_cst_client/hab/config/hab_cst_client.config   || true
sed -i 's/CST_SA_HOST2 = 100.64.116.218/CST_SA_HOST2 = 100.65.166.237/' motorola/security/hab_cst_client/hab/config/hab_cst_client.config || true
sed -i 's/CST_SA_HOST = 10.181.214.137/CST_SA_HOST = 100.64.116.218/' motorola/security/hab_cst_client/apk/config/hab_cst_client.config   || true
sed -i 's/CST_SA_HOST2 = 100.64.116.218/CST_SA_HOST2 = 100.65.166.237/' motorola/security/hab_cst_client/apk/config/hab_cst_client.config || true
##########################################################

#if [[ $SIGN_TYPE == *test* ]]; then
#    export REVERSE="-r"
#else
#    export REVERSE=""
#fi

#if [[ $BRANCH == mlmp* ]]; then
#    REVERSE=""
#fi


#if [[ "${OTA_BUILD_ID}" == "13114" ]]; then
#   cd ${top_dir}/platform/motorola/build
#   git checkout bdde643b96e0d56720d39a0554e128a56580670b~1 || true
#   cd -
#fi

############ TESTING SIGNING ISSUE on 7/30/2019#################
#cd ${top_dir}/platform/motorola/security/hab_cst_client
#git checkout 9747864
#cd -
######################END ###########################

if [[ ${package_type} == reverse ]]; then
	echo "Reverse package will be generated."
	export REVERSE="-r"
else
	export REVERSE=""
fi

 if [[ $SIGN_TYPE == *test* ]]; then
    echo "IT IS TEST keys"
    echo "Executing: ${top_dir}/platform/motorola/build/bin/ota.bash -p $PRODUCT_CARRIER -d -i ${top_dir}/temp -o ${top_dir}/platform/release $REVERSE"
    ${top_dir}/platform/motorola/build/bin/ota.bash -p $PRODUCT_CARRIER -d -i ${top_dir}/temp -o ${top_dir}/platform/release $REVERSE
    export bota_script_success=$?
 else
    if [[ $SIGN_TYPE == *release* ]]; then
        echo "IT IS RELEASE KEYS"
        #export PATH=/apps/android/python-2.7.1-x64/bin:/usr/bin:$PATH
        export PATH=/usr/bin:$PATH
        export CST_AUTO_SIGN=1
        #export CST_DEBUG=TRUE
        export CST_ALT_AUTH_PATH=${HOME}/auth/$HOSTNAME
        export HABROOT=${top_dir}/platform/motorola/security/hab_cst_client
        echo "Executing: ${top_dir}/platform/motorola/build/bin/ota.bash -p $PRODUCT_CARRIER -d -i ${top_dir}/temp -o ${top_dir}/platform/release -x $REVERSE"
        ${top_dir}/platform/motorola/build/bin/ota.bash -p $PRODUCT_CARRIER -d -i ${top_dir}/temp -o ${top_dir}/platform/release -x $REVERSE
        export bota_script_success=$?
    else
        echo "specify SIGN_TYPE" 
        exit 0
    fi
 fi
}
fi

if [ "${bota_script_success}" != "0" ]; then
   OTA_GEN_STATUS='FAILURE'
   ERROR_MESSAGE="Error to run ota.bash script"
   EXIT_STATUS=127
else
   
   # Add md5sum to get md5 hash for all the zip files
   touch ${top_dir}/platform/release/md5sum-hash.txt
   md5sum ${top_dir}/platform/release/*.zip > ${top_dir}/platform/release/md5sum-hash.txt || true
   #md5sum ${top_dir}/platform/release/*/*.zip >> ${top_dir}/platform/release/md5sum-hash.txt || true
   
   export ARTIFACT=${top_dir}/platform/release
   export upload_success=""
   
   export dest_jenkins_path="${top_dir}/platform/release"
   
   if [[ $TEST_RUN == TRUE ]]; then
      export jenkins_webhome_path="/usr/prod/jenkins-test/webhome/jobs/"${JOB_NAME}"/builds/"${BUILD_NUMBER}"/archive/platform/release"
   else
      export jenkins_webhome_path="/usr/prod/hudson01/webhome/jobs/"${JOB_NAME}"/builds/"${BUILD_NUMBER}"/archive/platform/release"
   fi
   
   echo "jenkins_webhome_path " ${jenkins_webhome_path}
   export upload_success=""
   
   echo "UPLOAD_ARTI: $UPLOAD_ARTI"
   
   # Select the server to upload if TEST_RUN then test server else production
   
   if [[ $TEST_RUN == TRUE ]]; then
      export server_to_upload="test"
   else
      export server_to_upload="production"
   fi


   if [[ ${UPLOAD_ARTI} != "" ]]; then
     dest_artifactory_path=$upload_path/$UPLOAD_ARTI
     echo "Destination Artifactory path" ${dest_artifactory_path}
     echo "Destination Jenkins path" ${dest_jenkins_path}
     
     echo "##################### COPYING LOG #####################"
     
     cp "${top_dir}/ota_generation_log.txt" "${dest_jenkins_path}/ota_generation_log.txt"
   
     echo "##################### UPLOADING TO ARTIFACTORY - START ####################"
     echo "#### Upload command: "
     echo "/apps/tools/scm_tools/hudson_tools/artifactory/execute upload -debug -artifactory_path=$dest_artifactory_path -local_location ${dest_jenkins_path} -server=$server_to_upload > ${top_dir}/platform/upload_log 2>&1"

     upload=$(/apps/tools/scm_tools/hudson_tools/artifactory/execute upload -debug -artifactory_path=$dest_artifactory_path -local_location ${dest_jenkins_path} -server=$server_to_upload > ${top_dir}/platform/upload_log 2>&1)
     export upload_success=$?

     echo "#### Full Upload sccript LOG - START #### "
     cat ${top_dir}/platform/upload_log
     echo "#### Full Upload sccript LOG - END #### "

     echo "------- DEBUG: upload exit status = $upload_success"
     # extract file name from log file
     ##export xml_file=`cat ${top_dir}/platform/upload_log |grep "downloadUri" |grep "/Blur_Version"`
     export xml_file=`cat ${top_dir}/platform/upload_log | grep "/delta-ota-Blur_Version.*.xml\|/file_delta-Blur_Version.*.xml\|/block_delta-Blur_Version.*.xml\|/block_delta-ota-Blur_Version.*.xml\|/ab_delta-Blur_Version.*.xml\|/Blur_Version.*.xml" |grep "Uploading .* to .*" | sed "s/Uploading \(.*\) to '\(.*\)'.*/\2/"`
   #DEPRECATED#  export ota_zip_file=`cat ${top_dir}/platform/upload_log |grep  "delta-ota-Blur_Version.*.zip\|file_delta-Blur_Version.*.zip\|block_delta-Blur_Version.*.zip\|ab_validation-Blur_Version.*.zip\|ab_delta-Blur_Version.*.zip"`
     export ota_zip_file=`cat ${top_dir}/platform/upload_log |grep  "/delta-ota-Blur_Version.*.zip\|/file_delta-Blur_Version.*.zip\|/block_delta-Blur_Version.*.zip\|/block_delta-ota-Blur_Version.*.zip\|/ab_delta-Blur_Version.*.zip\|/block_validation-Blur_Version.*.zip\|/ab_dp_delta-Ota_Version.*.zip\|/ab_delta-Ota_Version.*.zip" |grep "Uploading .* to .*" | sed "s/Uploading \(.*\) to '\(.*\)'.*/\2/"`
     export ota_zip_file_trimmed="$(echo ${ota_zip_file} | tr '\n' ' ')"

     echo "------- DEBUG: ota_zip_file = $ota_zip_file"
     export sdcard_zip_file=`cat ${top_dir}/platform/upload_log |grep "downloadUri" |grep "validation-sdcard"`

     export sdcard_file_name=`echo $sdcard_zip_file |awk -F'/' '{print $NF}'`
     echo ${sdcard_file_name//\"\,}
     export xml_file_name=`echo $xml_file |awk -F'/' '{print $NF}'`
     echo ${xml_file_name//\"\,}  # replace ", from the file name
   #DEPRECATED#  export zip_file_name=`echo $ota_zip_file |awk -F'/' '{print $NF}'`
     export zip_file_name=$(get_zip_file "$ota_zip_file_trimmed")

     export zip_file_name_alternative=`echo $ota_zip_file_alternative |awk -F'/' '{print $NF}'`
     echo ${zip_file_name//\"\,}
     echo ${zip_file_name_alternative//\"\,}
     echo "------- DEBUG: zip_file_name = $zip_file_name"
     echo "------- DEBUG: zip_file_name_alternative = $zip_file_name_alternative"
     export artifactory_url=`echo $xml_file |awk -F'"downloadUri" :' '{print $2}'`
   #DEPRECATED#  export artifactory_url_path=`echo ${artifactory_url}|awk -F'Blur_Version' '{print $1}'`
     export artifactory_url_path=`cat ${top_dir}/platform/upload_log |grep "Uploading .* to .*" | sed "s/Uploading \(.*\) to '\(.*\)'.*/\2/" | grep "$zip_file_name\'" | tail -1`

     echo "Artifactory URL is "${artifactory_url_path}

     echo "##################### UPLOADING TO ARTIFACTORY - END ####################"

   fi

   # Create OTA pacakage and upload it to Artifactory.
   #Following values should be intialized before making send signal
   #OTA_GEN_STATUS
   #OTA_PACKAGE_JENKINS_PATH
   #OTA_PACKAGE_ARTIFACTORY_PATH
   #OTA_PACKAGE_XML_FILE_NAME
   #OTA_PACKAGE_ZIP_FILE_NAME

   OTA_PACKAGE_JENKINS_PATH=${jenkins_webhome_path}
   OTA_PACKAGE_ZIP_FILE_NAME=$(echo $artifactory_url_path |awk -F'/' '{print $NF}')
   OTA_PACKAGE_ARTIFACTORY_PATH=$(echo $artifactory_url_path | sed "s/$OTA_PACKAGE_ZIP_FILE_NAME//")
   OTA_PACKAGE_XML_FILE_NAME=${xml_file_name//\"\,}
   OTA_PACKAGE_SDCARD_FILE_NAME=${sdcard_file_name//\"\,}

   # if ota zip file is not created then job status is failed
   if  [ -z "${OTA_PACKAGE_ZIP_FILE_NAME// }" ]; then
      OTA_GEN_STATUS='FAILURE'
      EXIT_STATUS=127
      if [ "${upload_success}" != "0" ]; then
          http_status=$(cat upload_log |grep -e "\"status\"" -m 1 | sed -s "s/\"//g")
             http_message=$(cat upload_log |grep -e "message" -m 1 | sed -s "s/\"//g")
          http_error_title=$(cat upload_log |grep -e "<title>" -m 1 | sed -s "s/\"//g")
          ERROR_MESSAGE="Error: ${http_error_title} - ${http_status} - ${http_message}. Upload Log: https://jenkins.mot.com/job/OTA_CREATOR_FROM_DEVOPS_MISC/${BUILD_NUMBER}/artifact/platform/upload_log"
      else
             ERROR_MESSAGE="Jenkins internal error. Please see: https://jenkins.mot.com/job/OTA_CREATOR_FROM_DEVOPS_MISC/${BUILD_NUMBER}/console"
      fi
   else
      OTA_GEN_STATUS='SUCCESS'
      ERROR_MESSAGE="No Error."
      EXIT_STATUS=0
   fi
fi
echo "OTA_GEN_STATUS: " ${OTA_GEN_STATUS}
echo "ERROR MESSAGE: " ${ERROR_MESSAGE}

#Send signal to devops on completion
echo curl -X POST -H "Content-Type: application/json" -d "{\"ERROR MESSAGE\": \"${ERROR_MESSAGE}\",\"OTA_GEN_STATUS\": \"${OTA_GEN_STATUS}\", \"OTA_PACKAGE_JENKINS_PATH\": \"${OTA_PACKAGE_JENKINS_PATH}\", \"OTA_PACKAGE_ARTIFACTORY_PATH\": \"https://artifacts.mot.com/artifactory/simple/${OTA_PACKAGE_ARTIFACTORY_PATH}\", \"OTA_PACKAGE_XML_FILE_NAME\": \"${OTA_PACKAGE_XML_FILE_NAME}\", \"OTA_PACKAGE_ZIP_FILE_NAME\": \"${OTA_PACKAGE_ZIP_FILE_NAME}\", \"OTA_PACKAGE_SDCARD_FILE_NAME\": \"${OTA_PACKAGE_SDCARD_FILE_NAME}\", \"BUILD_NUMBER\": ${BUILD_NUMBER}}" "http://devops.mot.com/ota/create_finished/${OTA_BUILD_ID}?token=<token>"
     curl -X POST -H "Content-Type: application/json" -d "{\"ERROR MESSAGE\": \"${ERROR_MESSAGE}\",\"OTA_GEN_STATUS\": \"${OTA_GEN_STATUS}\", \"OTA_PACKAGE_JENKINS_PATH\": \"${OTA_PACKAGE_JENKINS_PATH}\", \"OTA_PACKAGE_ARTIFACTORY_PATH\": \"https://artifacts.mot.com/artifactory/simple/${OTA_PACKAGE_ARTIFACTORY_PATH}\", \"OTA_PACKAGE_XML_FILE_NAME\": \"${OTA_PACKAGE_XML_FILE_NAME}\", \"OTA_PACKAGE_ZIP_FILE_NAME\": \"${OTA_PACKAGE_ZIP_FILE_NAME}\", \"OTA_PACKAGE_SDCARD_FILE_NAME\": \"${OTA_PACKAGE_SDCARD_FILE_NAME}\", \"BUILD_NUMBER\": ${BUILD_NUMBER}}" "http://devops.mot.com/ota/create_finished/${OTA_BUILD_ID}?token=559cd9e4ccf77f1b484e090bfu01ced33efc9155" || true
     curl -X POST -H "Content-Type: application/json" -d "{\"ERROR MESSAGE\": \"${ERROR_MESSAGE}\",\"OTA_GEN_STATUS\": \"${OTA_GEN_STATUS}\", \"OTA_PACKAGE_JENKINS_PATH\": \"${OTA_PACKAGE_JENKINS_PATH}\", \"OTA_PACKAGE_ARTIFACTORY_PATH\": \"https://artifacts.mot.com/artifactory/simple/${OTA_PACKAGE_ARTIFACTORY_PATH}\", \"OTA_PACKAGE_XML_FILE_NAME\": \"${OTA_PACKAGE_XML_FILE_NAME}\", \"OTA_PACKAGE_ZIP_FILE_NAME\": \"${OTA_PACKAGE_ZIP_FILE_NAME}\", \"OTA_PACKAGE_SDCARD_FILE_NAME\": \"${OTA_PACKAGE_SDCARD_FILE_NAME}\", \"BUILD_NUMBER\": ${BUILD_NUMBER}}" "http://ilcldevops02.mot.com/api/ota/create_finished/${OTA_BUILD_ID}?token=ImFwcGRldm9wIg.7uarwvQhUJL3vrwmgTOC04Wd6sQ" || true

exit $EXIT_STATUS