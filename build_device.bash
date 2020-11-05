#!/bin/bash
#-------------------------------------------------------------------------------
#  build_device.bash - platform and applications integrated device build script
#-------------------------------------------------------------------------------

# to make bash scripts behave like makefiles, exit on any error
set -e

script_path=${0}
script_name=$(basename ${script_path})

build_command_line="motorola/build/bin/build_device.bash $*"

function clobber {
    echo "clobber build"
    (cd ${platform_dir}; make clobber)
    (cd ${platform_dir}; rm -f *.gz *.tgz)
    if [ -d ${platform_dir}/kernel ]; then
        (cd ${platform_dir}/kernel; git clean -f -x -d || true)
    fi
    rm -rf $release_dir
}

function usage {
    echo ""
    echo "Usage: ${script_name} [OPTION] -b [build type] -p [product] -u [device_uid_path] -j [simultaneous] -a [customer name]"
    echo ""
    echo "      b: build types:"
    echo "             barebones        build product images to out/ only, no fastboot package."
    echo "             developer        barebones plus release fastboot package. [default]"
    echo "             release          full build and release of images, target-files package, fastboot package, etc."
    echo "             clobber          'clean' release build. Calls 'make clobber' before building."
    echo ""
    echo "      p: product [default: gsi]"
    echo "      s: create generically signed build"
    echo "      t: Create system image with default flex file and special flex file"
    echo "      a: Customer signing - Verizon, ATT etc"
    echo "      f: user build"
    echo "      g: userdebug build [default]"
    echo "      n: build number"
    echo "      m: GMS off build."
    echo "      e: Build Moto oem image only."
    echo "      h: target hw config (separeted by ';') "
    echo "      i: special build config: builda, buildb, buildc, buildd, builde"
    echo "      k: target mbm hw config"
    echo "      u: path to device uid file (either absolute or from the root directory of your workspace)"
    echo "          Formatting of the UID in file uid.txt should be as follows: 0xaa 0xbb, fourteen bytes long"
    echo "          pls note bound signing works only on system,boot and recovery"
    echo "          pls flash official secure build from jenkins and replace system,boot or recovery from bound build for testing"
    echo "      j: Number of simultaneous jobs. X = # of CPU core [default X for <8 cpus, X/2 for >=8 cpus]"
    echo "      w: Enable moto partial gms build."
    echo "      y: APK Signing Only"
    echo "      z: include MAKE_FACT=true on make command line for GNPO/Factory"
    echo "      r: generate cfc zip package"
    echo "      T: disable target files packaging"
    echo "      B: avoid bootloader source build if possible"
    echo "      E: build SW + oem, tar oem image into fastboot file"
    echo "      N: Build WITHOUT nonhlos target"
    echo "      C: Run the 'installclean' target before running the real build."
    echo ""
    exit 1
}


# Get all the build variables needed by this script in a single call to the build system.
# Note: Stolen from build/envsetup.sh
function mmi_build_build_var_cache()
{
    local T=$(gettop)
    # Grep out the variable names from the script.
    mmi_cached_vars=`cat ${script_path} | tr '()' '  ' | awk '{for(i=1;i<=NF;i++) if(\$i~/mmi_get_build_var/) print \$(i+1)}' | sort -u | tr '\n' ' '`
    # Call the build system to dump the "<val>=<value>" pairs as a shell script.
    mmi_build_dicts_script=`\builtin cd $T; build/soong/soong_ui.bash --dumpvars-mode \
                        --vars="${mmi_cached_vars[*]}" \
                        --var-prefix=mmi_var_cache_ `
    local ret=$?
    if [ $ret -ne 0 ]
    then
        unset mmi_build_dicts_script
        return $ret
    fi
    # Execute the script to store the "<val>=<value>" pairs as shell variables.
    eval "$mmi_build_dicts_script"
    ret=$?
    unset mmi_build_dicts_script
    if [ $ret -ne 0 ]
    then
        return $ret
    fi
    MMI_BUILD_VAR_CACHE_READY="true"
}

# Get the exact value of a build variable.
function mmi_get_build_var()
{
    if [ "$MMI_BUILD_VAR_CACHE_READY" = "true" ]
    then
        eval "echo \"\${mmi_var_cache_$1}\""
    return
    fi

    local T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return
    fi
    (\cd $T; build/soong/soong_ui.bash --dumpvar-mode $1)
}

# Delete the build var cache.  Note: Not currently called/used.
function mmi_destroy_build_var_cache()
{
    unset MMI_BUILD_VAR_CACHE_READY
    local v
    for v in $mmi_cached_vars; do
      unset mmi_var_cache_$v
    done
    unset mmi_cached_vars
}


# generate_privapp_whitelist function passes all arguments to privapp_permissions.py
function generate_privapp_whitelist {
    if [ ! -f ${platform_dir}/development/tools/privapp_permissions/privapp_permissions.py ]; then
        echo "WARNING: privapp_permissions.py does not exist"
        return 0
    fi
    set +e
        ${platform_dir}/development/tools/privapp_permissions/privapp_permissions.py $@
        PRIVAPP_ERR=$?
    set -e
    if [ $PRIVAPP_ERR -eq 0 ]; then
        echo "INFO: $2 generated successfully"
    else
        echo "WARNING: privapp_permissions.py script failed, $2 could not be generated."
    fi
}

# Release the build-related files that we want to keep along with the artifacts
function release_build_info {
    build_info_dir="${platform_dir}/release/build_info"
    mkdir -p ${build_info_dir}

    if [ -f $BUILDOUT/module-info.json ]; then
        echo "copy $BUILDOUT/module-info.json > ${build_info_dir}/module-info.json"
        cp $BUILDOUT/module-info.json ${build_info_dir}/module-info.json
        echo "INFO: Copied module-info.json to the release folder"
    fi

    if [ -f ${platform_dir}/out/build-${product}.ninja ]; then
        echo "copy ${platform_dir}/out/build-${product}.ninja > ${build_info_dir}/build-${product}.ninja"
        cp ${platform_dir}/out/build-${product}.ninja ${build_info_dir}/build-${product}.ninja
        echo "INFO: Copied build-${product}.ninja to the release folder"
    fi
    if [ -f ${platform_dir}/out/build.trace.gz ]; then
        cp ${platform_dir}/out/build.trace*.gz ${build_info_dir}/
        echo "INFO: Copied build.trace*.gz files to the release folder"
    fi
    if [ -f ${platform_dir}/out/soong/build.ninja ]; then
        cp ${platform_dir}/out/soong/build.ninja ${build_info_dir}/
        echo "INFO: Copied soong/build.ninja to the release folder"
    fi
}


build_type=developer
build_flavor=userdebug
product=smq_vzw
CSV_BARKER=true
BOUND_BUILD_ONLY=
RADIO_SECURE=0
HAB_APK_SIGNING_ONLY=0
sign_imgs=false
HAB_SIGN=""
SERVER_SIGN=""
AUTO_SIGN=""
CID=""
customer=""
MOT_NO_GMS=0
MOT_PARTIAL_GMS=0
mbm_hw_config=""
device_uid_path=""
parallel_num=""
wifi_only_build=false
build_symbol=""
DEVTREE="device_tree.bin"
showcommands=""
target_files_package_opt=target-files-package
ota_tools_package="otatools-package"
MOT_TARGET_BUILD_ADDITIONAL_CONFIG=""
build_sw_oem="false"
build_oem_image=""
sign_oem=""
sign_qcom=""
build_fastboot_package=true
build_misc_zipfiles=true

MOTO_MAKE="make"
BUILD_MSI_ENABLE="false"
# BIG Usage parameters
inttool_product=""
bp_flex_name_prefix=""
inttool_bp_product=""
bootloader_source_build_opt=""

nonhlos=""
make_fact=""
gen_fact_package=0

margs=`getopt -o b:e:p:v:h:u:i:k:j:a:n:E:stodfgcmlqdwxyzrTBNC -- "$@"` || (usage ; exit 1)
eval set -- "$margs"

while true
do
    case "$1" in
        -b)  build_type="$2"; shift 2;;
        -p)  product="$2"; shift 2;;
        -j)  parallel_num="$2"; shift 2;;
        -n)  BUILD_NUMBER="$2"; shift 2;;
        -u)  device_uid_path="$2"; shift 2;;
        -i)  build_symbol="$2"; shift 2;;
        -k)  mbm_hw_config="$2"; shift 2;;
        -s)  sign_keys=product;RADIO_SECURE=1; shift;;
        -a)  CID="true";customer="$2"; shift 2;;
        -f)  build_flavor=user; shift;;
        -g)  build_flavor=userdebug; shift;;
        -e)  build_oem_image="$2"; shift 2;;
        -m)  MOT_NO_GMS=1; shift;;
        -w)  MOT_PARTIAL_GMS=1; shift;;
        -y)  HAB_APK_SIGNING_ONLY=1; shift;;
        -z)  make_fact="MAKE_FACT=true"; shift;;
        -r)  gen_fact_package=1; shift;;
        -T)  target_files_package_opt=""; shift;;
        -B)  bootloader_source_build_opt="TARGET_AVOID_BOOTLOADER_SOURCE_BUILD=1"; shift;;
        -E)  build_sw_oem="true"; build_oem_image="$2"; shift 2;;
        -N)  build_nonhlos_disable="true"; shift;;
        -C)  FORCE_INSTALLCLEAN=1; shift;;
        --)  shift; break;;
    esac
done

# Don't build target-files and other zipfiles for barebones and developer builds.
if [[ "${build_type}" == "barebones" ]] || [[ "${build_type}" == "developer" ]]; then
    target_files_package_opt=""
    build_misc_zipfiles=false
fi

# Don't build fastboot package for barebones builds
if [ "${build_type}" == "barebones" ]; then
    build_fastboot_package=false
fi

# set showcommands
if [ "${SHOW_COMMANDS}" == "true" ]; then
   showcommands="showcommands"
fi

my_zip="gzip --rsyncable"
zip_ext=gz
# determine if pigz is available
if pg_zip=$(which pigz); then
   my_zip="${pg_zip} --rsyncable"
fi

script_dir=$(cd $(dirname ${0}); pwd)
platform_dir=${script_dir}
while [ ! -d "${platform_dir}/.repo" ]; do
   platform_dir=`dirname ${platform_dir}`
done

release_dir=${platform_dir}/release

# generate salesforce report only for signed daily job
sfdc_script="${platform_dir}/motorola/build_tools/salesforce/gen_sfdc_report.bash"
if [[ "${DONT_GENERATE_SALESFORCE_FILE}" == "1" ]] || [[ "${product}" =~ "factory" ]] || [[ ! -e "${sfdc_script}" ]]; then
    gen_salesforce=0
else
    gen_salesforce=1
fi

# set blur region if unset
if [ "${BLUR_REGION}" == "" ]; then
    export BLUR_REGION=US
fi

# set blur release notes if unset
if [ "${BLUR_RELEASE_NOTES}" == "" ]; then
    export BLUR_RELEASE_NOTES=http://www.motorola.com/support
fi

if [ "${BUILD_NUMBER}" == "" ]; then
    BUILD_NUMBER=eng.`whoami`.`date +%y%m%d.%H%M%S`
fi
if [ "${INTTOOL_GEN_ENABLED}" == "" ]; then
    export INTTOOL_GEN_ENABLED=""
fi

if [ "${build_symbol}" != "" ]; then
    if [ "${build_symbol}" == "builda" ]; then
        MOT_TARGET_BUILD_ADDITIONAL_CONFIG="bldacfg"
    elif [ "${build_symbol}" == "buildb" ]; then
        MOT_TARGET_BUILD_ADDITIONAL_CONFIG="bldbcfg"
    elif [ "${build_symbol}" == "buildc" ]; then
        MOT_TARGET_BUILD_ADDITIONAL_CONFIG="bldccfg"
    elif [ "${build_symbol}" == "buildd" ]; then
        MOT_TARGET_BUILD_ADDITIONAL_CONFIG="blddcfg"
    elif [ "${build_symbol}" == "builde" ]; then
        MOT_TARGET_BUILD_ADDITIONAL_CONFIG="bldecfg"
    elif [ "${build_symbol}" == "buildg" ]; then
        MOT_TARGET_BUILD_ADDITIONAL_CONFIG="bldgcfg"
    elif [ "${build_symbol}" == "buildm" ]; then
        MOT_TARGET_BUILD_ADDITIONAL_CONFIG="bldmcfg"
    fi
fi

export OTA
export BUILD_NUMBER
export RADIO_SECURE
export HAB_APK_SIGNING_ONLY
export MOT_TARGET_BUILD_CONFIG
export MOT_TARGET_BUILD_ADDITIONAL_CONFIG
export platform_dir
export CID

# Initialize the Build environment
# (Java/Python env will be initialized by motorola/build/vendorsetup.sh)
# If you need new environment variable initializations do it on
# motorola/build/vendorsetup.sh that is called by envsetup.sh
source ${platform_dir}/build/envsetup.sh

architecture=linux-x86
export NO_OF_CPUs=$(grep processor /proc/cpuinfo | wc -l)
export PATH=${platform_dir}/prebuilts/gcc/linux-x86/arm/arm-eabi-4.6/bin:${platform_dir}/out/host/linux-x86/bin:${PATH}

if [ "${parallel_num}" == "" ] &&  [ "${NO_OF_CPUs}" -gt "8" ] ; then
    parallel_num=$((NO_OF_CPUs/2))
elif [ "${parallel_num}" == "" ] &&  [ "${NO_OF_CPUs}" -le "8" ] ; then
    parallel_num=$NO_OF_CPUs
elif [ "${parallel_num}" == "X" ]; then
    parallel_num=$NO_OF_CPUs
fi

export SIMULTANEOUS_JOBS=-j${parallel_num}

# set path for the ota binaries and copy jar file
export PATH=${platform_dir}/out/host/${architecture}/bin:${PATH}

# test for local env then set the PATH
if [ "${HOST_JAVA_HOME}" != "" ]; then
    JAVA_HOME=${HOST_JAVA_HOME}
fi

if [ "${HOST_JRE_HOME}" != "" ]; then
    JRE_HOME=${HOST_JRE_HOME}
fi
export PATH=${JAVA_HOME}/bin:${JRE_HOME}/bin:${PATH}

# verify that the java versions are correct
JAVA_VERSION=$(${JAVA_HOME}/bin/java -version 2>&1 | grep "java version" | awk -F"." '{print $2}')
JRE_VERSION=$(${JRE_HOME}/bin/java -version 2>&1 | grep "java version" | awk -F"." '{print $2}')

cd ${platform_dir}

if [ "${build_type}" == "clobber" ]; then
    clobber
fi

export product=${product}

echo "lunch ${product}-${build_flavor}"
lunch ${product}-${build_flavor}

echo "Caching build variables for ${product}-${build_flavor}..."
mmi_build_build_var_cache

device=$(mmi_get_build_var TARGET_DEVICE)
mot_device=$(mmi_get_build_var MOT_TARGET_DEVICE)
target_board_platform=$(mmi_get_build_var TARGET_BOARD_PLATFORM)
build_nonhlos=$(mmi_get_build_var BOARD_USES_QCOM_NONHLOS )

export TARGET_DEVICE=${device}
export MOT_TARGET_DEVICE=${mot_device}

# All msm targets build nonhlos
if [ "${build_nonhlos,,}" == "true" ] || [ "${target_board_platform:0:3}" == "msm" ] || [ "${target_board_platform:0:3}" == "apq" ] ; then
    export nonhlos="nonhlos"
fi

if [ "${build_nonhlos_disable,,}" == "true" ]; then
    export nonhlos=""
fi

export build_target="PRODUCT-${product}-${build_flavor}"

# Execute any "special build configuration" that modifies the source code or environment before building
if [ "${MOT_TARGET_BUILD_ADDITIONAL_CONFIG}" != "" ]; then
   SPECIAL_BUILD_STAGE=pre
   source device/moto/common/build/special_build_config.sh
fi


if [ "${make_fact}" == "" ]; then
    build_factory=$(mmi_get_build_var MAKE_FACT )
    if [ "${build_factory}" == "true" ]; then
        make_fact="MAKE_FACT=true"
    fi
fi

# This script will set the proper HAB signing environment matching our back-end server
# This script makes use of system calls which can return errors.
set +e
    . ${platform_dir}/motorola/security/certs/hab_support/setenv_from_android_env.sh &> /dev/null
    SETENV_FAILED=$?
set -e

if [ "${sign_keys}" == "product" ] || [ "${HAB_APK_SIGNING_ONLY}" == "1" ] || [ "${device_uid_path}" != "" ]; then

    if [ "${customer}" == "Factory" ]; then
        export HAB_CUSTOMER_REGION=Factory
    fi;

    if [ $SETENV_FAILED -eq 0 ]; then
        # Use new certificate and customer ID framework
        export CSF_DIRECT_PATH=$HAB_CSF_FILES_DIR
        export PRODUCT_CERT_DIR=$HAB_CERTIFICATES_DIR

        # check certificates and customer ID are matched correctly.
        if [ -n "${customer}" ] && [ $HAB_CUSTOMER_REGION != ${customer} ]; then
            echo "Customer ${customer} does not match. Was expecting $HAB_CUSTOMER_REGION"
            echo "Please see readme in motorola/security/certs/hab_support for more info"
            exit 1
        fi;
    else
        echo "Please see readme in motorola/security/certs/hab_support for more info"
        echo "NOTICE: Product not found in certificate framework."
        exit 1
    fi;

    echo "PRODUCT_CERT_DIR = $PRODUCT_CERT_DIR"
    echo "HAB_APK_CERTIFICATES_DIR= $HAB_APK_CERTIFICATES_DIR"
    echo "CSF_DIRECT_PATH = $CSF_DIRECT_PATH"
fi

if [ "${sign_keys}" == "product" ] || [ "${device_uid_path}" != "" ]; then

    if [[ -z $BTROOT ]]; then
        echo "BTROOT = ${platform_dir}/motorola/build/tools/scripts/bin/"
        export BTROOT=${platform_dir}/motorola/build/tools/scripts/bin/
    fi;

    if [[ -z $HABROOT ]]; then
        echo "HABROOT = ${platform_dir}/motorola/security/hab_cst_client/"
        export HABROOT=${platform_dir}/motorola/security/hab_cst_client/
    fi;

    if [ "${sign_keys}" != "product" ]; then
        BOUND_BUILD_ONLY="sign_bound"
        export SIGN_TYPE="bound -ap_uid $device_uid_path"
        export CUST=""
        DIST_TARGET=""
    elif [ -n "${customer}" ]; then
        export SIGN_TYPE=customer
        export CUST="-customer $customer"
    elif [ -z "${customer}" ]; then
        export SIGN_TYPE=generic
        export CUST=""
    fi

    echo "Sign type is $SIGN_TYPE $CUST"
    echo ""

    # We must not sign non-user builds
    if [ "${build_flavor}" != "user" ] && [ "${customer}" != "Factory" ]; then
        echo "Only user builds can be signed with product signature (use -f option)"
        exit 1
    fi

    if [ "${device_uid_path}" != "" ] && [ "${CST_AUTO_SIGN}" == "1" ]; then
        echo "Bound signed build cannot be automated (you should unset CST_AUTO_SIGN variable)"
        exit 1
    else
        echo "This is bound signed build for device with uid specified here: ${device_uid_path}"
    fi

if [ "${sign_keys}" == "product" ]; then
    sign_imgs="true"
    DIST_TARGET="dist"
fi

elif [ "${HAB_APK_SIGNING_ONLY}" == "1" ]; then
    DIST_TARGET="dist"
    echo "HAB_APK_SIGNING_ONLY enabled. Signing APKs Only."
    CSV_BARKER=true
else
    # We do not need to append CSV for unsigned build
    CSV_BARKER=false
fi

# Prepare config files for auto-signing (however, you should also set CST_AUTO_SIGN=1 if you want to auto-sign)
if [ "${CST_AUTO_SIGN}" == "1" ]; then
    HAB_SERVICE_CONFIG_APK=${platform_dir}/motorola/security/hab_cst_client/apk/config/hab_service.config
    HAB_SERVICE_CONFIG_CM=${platform_dir}/motorola/security/hab_cst_client/hab/config/hab_service.config
    HAB_SERVICE_CONFIG_COMMON=${platform_dir}/motorola/security/hab_cst_client/common/CURRENT/config/hab_service.config
    echo "BLD_SERVER_HOST=$HOSTNAME" > $HAB_SERVICE_CONFIG_APK
    echo "BLD_SERVER_HOST=$HOSTNAME" > $HAB_SERVICE_CONFIG_CM
    echo "ln -sf $HAB_SERVICE_CONFIG_CM $HAB_SERVICE_CONFIG_COMMON"
    mkdir -p ${platform_dir}/motorola/security/hab_cst_client/common/CURRENT/config
    ln -sf $HAB_SERVICE_CONFIG_CM $HAB_SERVICE_CONFIG_COMMON
    ## needed for QCOM BOOT signing ##
    export SERVER_SIGN="-server_signing"
    ## needed for AP and other images auto signing ##
    export AUTO_SIGN="-no_auto_password"
    export CST_CLIENT_INSTALL_PATH=${platform_dir}/motorola/security/hab_cst_client/apk
else
    rm -rf $HAB_SERVICE_CONFIG_APK || true
    rm -rf $HAB_SERVICE_CONFIG_CM || true
fi

cd ${platform_dir}
lunch ${product}-${build_flavor}

build_super_partition=$(mmi_get_build_var PRODUCT_BUILD_SUPER_PARTITION)
super_partition_size=$(mmi_get_build_var BOARD_SUPER_PARTITION_SIZE)
super_partition_list=$(mmi_get_build_var BOARD_SUPER_PARTITION_PARTITION_LIST)
export PRODUCT_BUILD_SUPER_PARTITION=${build_super_partition}

#Use msi wrapped tool to build msi enabled target.
if [ -f "build_msi_device.sh" ]; then
    echo "Moto system image will be built!!!!"
    MSIBUILDOUT=${platform_dir}/out/target/product/msi
    MOTO_MAKE="build_msi_device.sh"
    BUILD_MSI_ENABLE="true"
    #Add system from MSI in super_partition_list
    super_partition_list="${super_partition_list} system"
fi


BUILDOUT=$ANDROID_PRODUCT_OUT
RELEASEDIR=$release_dir

if [ "${sign_imgs}" == "true" ]; then
   echo "Signed build"
   export sign_qcom="sign_qcom"
fi

if [ "u${build_oem_image}" != "u" ]; then
   rm -rf $BUILDOUT/oem
   rm -rf $BUILDOUT/obj/PACKAGING/oem_intermediates
   export oem_image_file=$(echo ${build_oem_image} | awk -F- '{print $1}')
   if [ "${RADIO_SECURE}" == "1" ]; then
         sign_oem="sign_oem"
   fi
fi

if [ "${FORCE_INSTALLCLEAN}" == '1' ]; then
    make_cmd='make installclean'
    echo "Running [ $make_cmd ]"
    $make_cmd
fi

if [ "${build_super_partition}" == "true" ]; then
   echo "build dist for super image"
   export DIST_TARGET="dist"
fi

if [ "${build_sw_oem}" == "false" ] && [ "u${build_oem_image}" != "u" ]; then
    # build oem image only, save the build time
    # Note: Add aapt because Jenkins uses this tool during oem-only builds
    make_cmd="make ${SIMULTANEOUS_JOBS} BUILD_NUMBER=${BUILD_NUMBER} ${showcommands} MOT_NO_GMS=${MOT_NO_GMS} MOT_PARTIAL_GMS=${MOT_PARTIAL_GMS} ${build_oem_image} ${sign_oem} aapt"
    echo "Running [ $make_cmd ]"
    $make_cmd
elif [ "${build_sw_oem}" == "true" ] && [ "u${build_oem_image}" != "u" ]; then
    # Full legacy build oem + all other images
    ## cleanup target files before full build
    if [ -d $BUILDOUT/obj/PACKAGING/target_files_intermediates ]; then
       rm -Rf $BUILDOUT/obj/PACKAGING/target_files_intermediates
    fi
    echo "Building all images before the OEM..."
    make_cmd="${MOTO_MAKE} ${SIMULTANEOUS_JOBS} ${build_target} BUILD_NUMBER=${BUILD_NUMBER} ${showcommands} ${DIST_TARGET} MOT_NO_GMS=${MOT_NO_GMS} MOT_PARTIAL_GMS=${MOT_PARTIAL_GMS} ${make_fact} ${nonhlos} ${target_files_package_opt} ${ota_tools_package} ${bootloader_source_build_opt} ${sign_qcom} ${BOUND_BUILD_ONLY}"
    echo "Running [ $make_cmd ]"
    $make_cmd
    # Cleanup and build the OEM
    echo "Removing OEM intermediate files"
    rm -rf $BUILDOUT/oem
    rm -rf $BUILDOUT/obj/PACKAGING/oem_intermediates
    rm -rf $BUILDOUT/oem_other
    rm -rf $BUILDOUT/obj/PACKAGING/oem_other_intermediates
    echo "Building ${build_oem_image}"
    make_cmd="make ${SIMULTANEOUS_JOBS} BUILD_NUMBER=${BUILD_NUMBER} ${showcommands} MOT_NO_GMS=${MOT_NO_GMS} MOT_PARTIAL_GMS=${MOT_PARTIAL_GMS} ${build_oem_image} ${sign_oem}"
    echo "Running [ $make_cmd ]"
    $make_cmd
else
    # BEGIN Motorola, ADS047, 2010/04/05, IKMAP-8291 / support of build signing procedure
    ## cleanup target files before full build
    if [ -d $BUILDOUT/obj/PACKAGING/target_files_intermediates ]; then
       rm -Rf $BUILDOUT/obj/PACKAGING/target_files_intermediates
    fi
    make_cmd="${MOTO_MAKE} ${SIMULTANEOUS_JOBS} ${build_target} BUILD_NUMBER=${BUILD_NUMBER} ${showcommands} ${DIST_TARGET} MOT_NO_GMS=${MOT_NO_GMS} MOT_PARTIAL_GMS=${MOT_PARTIAL_GMS} ${make_fact} ${nonhlos} ${target_files_package_opt} ${ota_tools_package} ${bootloader_source_build_opt} ${sign_qcom} ${BOUND_BUILD_ONLY}"
    echo "Running [ $make_cmd ]"
    $make_cmd
    # END IKMAP-8291
fi

mkdir -p $RELEASEDIR

# build oem image only!
if [ "${build_sw_oem}" == "false" ] && [ "u${build_oem_image}" != "u" ]; then
    if [ "${RADIO_SECURE}" == "1" ]; then
         echo "copy $BUILDOUT/secure/${oem_image_file}.img_signed > $RELEASEDIR/${oem_image_file}.img"
         cp -rf $BUILDOUT/secure/${oem_image_file}.img_signed $RELEASEDIR/${oem_image_file}.img
         # Pack releasekey signed oem other image if present
         if [ -f $BUILDOUT/secure/${oem_image_file}_other.img_signed ]; then
             echo "copy $BUILDOUT/secure/${oem_image_file}_other.img_signed > $RELEASEDIR/${oem_image_file}_other.img"
             cp -rf $BUILDOUT/secure/${oem_image_file}_other.img_signed $RELEASEDIR/${oem_image_file}_other.img
         fi
    elif [ -f $BUILDOUT/${oem_image_file}.img ]; then
         echo "copy $BUILDOUT/${oem_image_file}.img > $RELEASEDIR"
         cp -rf $BUILDOUT/${oem_image_file}.img $RELEASEDIR
         # Pack oem other image if present
         if [ -f $BUILDOUT/${oem_image_file}_other.img ]; then
             echo "copy $BUILDOUT/${oem_image_file}_other.img > $RELEASEDIR"
             cp -rf $BUILDOUT/${oem_image_file}_other.img $RELEASEDIR
         fi
    fi
    echo "copy $BUILDOUT/${oem_image_file}.map > $RELEASEDIR"
    cp -rf $BUILDOUT/${oem_image_file}.map $RELEASEDIR
    echo "copy $BUILDOUT/oem/oem.prop > $RELEASEDIR/${oem_image_file}.prop"
    cp -rf $BUILDOUT/oem/oem.prop $RELEASEDIR/${oem_image_file}.prop
    if [ -f $BUILDOUT/ota.prop ]; then
       echo "copy $BUILDOUT/ota.prop > $RELEASEDIR/${oem_image_file}_ota.prop"
       cp -rf $BUILDOUT/ota.prop $RELEASEDIR/${oem_image_file}_ota.prop
    fi
    if [ -f ${platform_dir}/out/build-${product}-${build_oem_image}.ninja ]; then
       echo "copy ${platform_dir}/out/build-${product}-${build_oem_image}.ninja > $RELEASEDIR/build-${product}-${build_oem_image}.ninja"
       cp -rf ${platform_dir}/out/build-${product}-${build_oem_image}.ninja $RELEASEDIR/build-${product}-${build_oem_image}.ninja
    fi

    echo "...BUILD OEM IMAGE COMPLETED...."
    if [ "${oem_image_file}" == "oem" ]; then
        oem_product=$(echo ${product} | cut -d '_' -f1)
    else
        oem_product=$(echo ${product} | cut -d '_' -f1)_$(echo ${oem_image_file} |cut -d '_' -f2)
    fi
    if [[ "${RADIO_SECURE}" == "1" ]] && [[ "${gen_salesforce}" == "1" ]]; then
        echo "Call SaleForce: ${sfdc_script} -p ${oem_product}"
        ${sfdc_script} -p ${oem_product}
    fi
    # IKSWO-5055: Generate privapp permissions XML for "-e" partition option
    generate_privapp_whitelist -w --oem-only --oemfile "${release_dir}/privapp_permissions_${build_oem_image}.xml"

    # If this is an OEM-only build, and system was not yet built,
    # then don't try to parse the build properties.
    if [ -f $BUILDOUT/system/build.prop ]; then
       echo "parsing/gathering build property files after oem build..."
       /apps/android/tools/python/python-2.7.14-x64/bin/python motorola/build/bin/parse_build_properties.py -z ${BUILDOUT}/build_properties.zip ${BUILDOUT} ${BUILDOUT}/build_all.prop
       mkdir -p $release_dir
       cp ${BUILDOUT}/build_all.prop ${release_dir}/build_all_${build_oem_image}.prop
       cp ${BUILDOUT}/build_properties.zip ${release_dir}/build_properties_${build_oem_image}.zip
    fi
    exit 0
fi

# IKSWO-5055: Generate privapp permissions XML for "-E" partition option
system_privapp_file="${release_dir}/privapp_permissions_system.xml"
product_privapp_file="${release_dir}/privapp_permissions_product.xml"
if [ "${BUILD_MSI_ENABLE}" == "true" ]; then
    # If we are building system separate then pass in the correct outdir when constructing its whitelist
    generate_privapp_whitelist -w --no-oem --systemfile "${system_privapp_file}" --android-out "${MSIBUILDOUT}"
    generate_privapp_whitelist -w --no-oem --productfile "${product_privapp_file}"
else
    generate_privapp_whitelist -w --no-oem --systemfile "${system_privapp_file}" --productfile "${product_privapp_file}"
fi
if [ -n "${build_oem_image}" ]; then
    generate_privapp_whitelist -w --oem-only --oemfile "${release_dir}/privapp_permissions_${build_oem_image}.xml"
fi

if [ "u${BOUND_BUILD_ONLY}" != "u" ]; then
   rm -rf $BUILDOUT/bound_signed_images
   mkdir -p $BUILDOUT/bound_signed_images
   cp -rf $BUILDOUT/secure/system_signed $BUILDOUT/bound_signed_images/system.img
   cp -rf $BUILDOUT/secure/boot_signed $BUILDOUT/bound_signed_images/boot.img
   cp -rf $BUILDOUT/secure/recovery_signed $BUILDOUT/bound_signed_images/recovery.img
   cd $BUILDOUT
   if [ "${build_fastboot_package}" == "true" ]; then
     tar c bound_signed_images | ${my_zip} > $RELEASEDIR/bound_signed_images.tar.$zip_ext
   fi
   exit 0
fi
# If CST_AUTO_SIGN environment variable is not set to '1',
# build_device.bash will sign apks in manual mode, meaning that the
# user should be ready to enter OneIT password during building/signing.
# In some cases, if bldlog wrapper is used, the prompt from cst client
# doesn't appear. Therefore we added explicit text asking for password
# into the echo command below.
if [ "${HAB_APK_SIGNING_ONLY}" == "1" ]; then
   echo "Signing applications with HAB product keys for ${product} (Enter OneIT pass below):"
   motorola/build/tools/releasetools/signer.sh -o ${BYPASS_WHITELIST_SIGNING} || (echo "Error with signing apks. Use CST_DEBUG=TRUE to get more log for debugging."; exit 1)
fi

#Only if sign_keys==product, recreate the signed radio img
if [[ "${sign_keys}" == "product" ]]; then
   if [[ "${product}" == *wifi* ]] || [[ "${nonhlos}" == "nonhlos" ]]; then
      echo "radio.img is not build/signed"
   else
      rm -f $BUILDOUT/radio.img
      echo "Building radio.img "
      make -j8 radio
   fi
fi

if [ "${sign_imgs}" == "true" ]; then
   # The signing scripts may have updated some build.prop files, and copied them to
   # out/dist.  Copy any files in dist to their proper location in the build output
   # directory.

   if [ -d ${platform_dir}/out/dist/build_properties ]; then
      cp -P -f -r ${platform_dir}/out/dist/build_properties/* $BUILDOUT || true
   elif [ -f ${platform_dir}/out/dist/SYSTEM/build.prop ]; then
      # system build.prop found in the legacy location
      cp -r ${platform_dir}/out/dist/SYSTEM/build.prop $BUILDOUT/system/
   fi
fi

if [ "${build_misc_zipfiles}" == "true" ]; then
   # Create a tarball of proguard mapping files
   rm -rf $RELEASEDIR/proguard
   mkdir -p $RELEASEDIR/proguard
   proguard_dictionaries=`find out/target/common/obj/APPS -name proguard_dictionary -print`
   jack_dictionaries=`find out/target/common/obj/APPS -name jack_dictionary -print`
   cd $RELEASEDIR
   for proguard_dictionary in ${proguard_dictionaries}; do
       app_name=`echo ${proguard_dictionary} | cut -d/ -f6 | cut -d_ -f1`
       cp -rf ${platform_dir}/${proguard_dictionary} $RELEASEDIR/proguard/${app_name}_proguard_dictionary
   done
   for jack_dictionary in ${jack_dictionaries}; do
       app_name=`echo ${jack_dictionary} | cut -d/ -f6 | cut -d_ -f1`
       cp -rf ${platform_dir}/${jack_dictionary} $RELEASEDIR/proguard/${app_name}_jack_dictionary
   done
   tar c proguard | ${my_zip} > $RELEASEDIR/proguard.tar.$zip_ext
   rm -rf $RELEASEDIR/proguard
   cd ${platform_dir}
fi

# Create a tarball of the fastboot images.  Having SBF only is driving us insane.
build_version_string=$(grep ro.build.version.full $BUILDOUT/system/build.prop | awk -F= '{print $2}')
if [ "u${build_version_string}" != "u" ]; then
    build_blur_carrier=$(echo ${build_version_string} | awk -F. '{print $6}')
else
    # the BVS does not exist, we need caculate it
    if [ -f $BUILDOUT/product/build.prop ]; then
        build_blur_carrier=$(awk -F= '/ro.mot.build.customerid=/{print $2}' $BUILDOUT/product/build.prop)
    else
        build_blur_carrier=$(awk -F= '/ro.mot.build.customerid=/{print $2}' $BUILDOUT/system/product/build.prop)
    fi
    if [ "u${build_blur_carrier}" == "u" ]; then
        build_blur_carrier="ret"
    fi
fi
build_blur_carrier_region=${build_blur_carrier}

if [ "${build_sw_oem}" == "false" ]; then
    if [ "u${build_version_string}" != "u" ]; then
        build_blur_region=$(echo ${build_version_string} | awk -F. '{print $8}')
    else
        build_blur_region=$(awk -F= '/ro.product.locale=/{split($2, region, "-");print region[2]}' $BUILDOUT/system/build.prop)
    fi
    build_blur_carrier_region="${build_blur_carrier}_${build_blur_region}"
fi

if [ -n "${customer}" ]; then
    if [[ -z ${HAB_CID:+x} ]]; then
        CID="-cid$(grep -w ${customer} ${platform_dir}/motorola/security/certs/hab_support/region_mapping.txt | tr -d '\r' |  awk -F' ' '{print $3}')-"
    elif [ ${HAB_CID} != 0 ]; then
        CID="-cid${HAB_CID}-"
    else
        CID=""
    fi
fi

echo "parsing/gathering build property files..."
/apps/android/tools/python/python-2.7.14-x64/bin/python motorola/build/bin/parse_build_properties.py -z ${BUILDOUT}/build_properties.zip ${BUILDOUT} ${BUILDOUT}/build_all.prop
mkdir -p $release_dir
cp ${BUILDOUT}/build_all.prop ${release_dir}/
cp ${BUILDOUT}/build_properties.zip ${release_dir}/

if [ "${BUILD_MSI_ENABLE}" == "true" ]; then
        build_product_name=$(awk -F= '/ro.product.name=/{print $2}' $BUILDOUT/build_all.prop)
        build_product_type=$(awk -F= '/ro.build.type=/{print $2}' $BUILDOUT/build_all.prop)
        build_release=$(awk -F= '/ro.build.version.release=/{print $2}' $BUILDOUT/build_all.prop)
        build_id=$(awk -F= '/ro.build.id=/{print $2}' $BUILDOUT/build_all.prop)
        build_num=$(awk -F= '/ro.build.version.incremental=/{print $2}' $BUILDOUT/build_all.prop)
        build_tags=$(grep ro.build.tags= $BUILDOUT/build_all.prop | awk -F= '{print $2}' |sed "s/,/-/g")
        out_name=${build_product_name}"_"${build_product_type}"_"${build_release}"_"${build_id}"_"${build_num}"_"${build_tags}${CID:-`echo _`}${build_blur_carrier_region}
else
    build_description=$(grep ro.build.description= $BUILDOUT/system/build.prop | awk -F= '{print $2}')
    if [ "u${build_description}" == "u" ]; then
        build_product_name=$(awk -F= '/ro.product.system.name=/{print $2}' $BUILDOUT/system/build.prop)
        build_product_type=$(awk -F= '/ro.system.build.type=/{print $2}' $BUILDOUT/system/build.prop)
        build_release=$(awk -F= '/ro.build.version.release=/{print $2}' $BUILDOUT/system/build.prop)
        build_id=$(awk -F= '/ro.build.id=/{print $2}' $BUILDOUT/system/build.prop)
        build_num=$(awk -F= '/ro.build.version.incremental=/{print $2}' $BUILDOUT/system/build.prop)
        build_tags=$(grep ro.build.tags= $BUILDOUT/system/build.prop | awk -F= '{print $2}' |sed "s/,/-/g")
        out_name=${build_product_name}"_"${build_product_type}"_"${build_release}"_"${build_id}"_"${build_num}"_"${build_tags}${CID:-`echo _`}${build_blur_carrier_region}
    else
        out_name=$(grep ro.build.description= $BUILDOUT/system/build.prop | awk '{gsub(/ /,"_");print}' | awk '{gsub(/,/,"_");print}' | awk -F= '{print $2}' | awk '{sub(/-/,"_");print}')${CID:-`echo _`}${build_blur_carrier_region}
    fi
fi

rm -fr $BUILDOUT/${out_name}
rm -fr $BUILDOUT/build_intermediates_${out_name}
rm -fr $BUILDOUT/nvflash_${out_name}

mkdir -p $BUILDOUT/${out_name}
cp ${BUILDOUT}/build_all.prop ${BUILDOUT}/${out_name}/

prebuilt_bootloader_dir=$(mmi_get_build_var PREBUILT_BOOTLOADER_DIR)
if [ "${prebuilt_bootloader_dir}" != "" ]; then
   mbm_location=${platform_dir}/${prebuilt_bootloader_dir}
else
   mbm_location=${platform_dir}/device/moto/mot${target_board_platform:3}/prebuilt/mbm
fi

if [ -d ${mbm_location} ]; then
   echo "copying mbm prebuilt from: ${mbm_location}"
   mkdir -p $release_dir
   cp -r -L ${mbm_location} $release_dir || true
   cp -r -L ${mbm_location} $BUILDOUT || true
else
   echo "bad MBM prebuilt location: ${mbm_location}"
fi

build_int_files="ramdisk.img \
                 ramdisk-recovery.img \
                 partitiontable.bin \
                 configtable.bin \
                 bootloader.bin \
                 microboot.bin \
                 system/build.prop \
                 root/default.prop \
                 system/etc/NOTICE-PARTNER-LICENSED-${BUILD_NUMBER}.txt"

fastboot_files="boot.img \
                boot-debug.img \
                dtbo.img \
                vbmeta.img \
                preinstall.img \
                system.img \
                system_other.img \
                system.map \
                logo.bin \
                ebr \
                mbr \
                lbl \
                cdrom \
                radio.img \
                system.img.ext4 \
                userdata.img \
                persist.img.ext4 \
                cache.img.ext4 \
                tombstones.img.ext4 \
                NON-HLOS.bin \
                BTFM.bin \
                adspso.bin \
                dspso*.bin \
                mdtp.img \
                multi_image.mbn \
                spunvm.bin \
                blank_hob.mbn \
                blank_dhob.mbn \
                fsg.mbn \
                mdmddr.mbn \
                sdx50_fsg.mbn \
                sdx55_fsg.mbn \
                fsg_ensdisable.mbn \
                rpm_10245.mbn \
                gpt_main0.bin \
                gpt.bin \
                recovery.img \
                sdi.mbn \
                persist.img \
                cache.img \
                vendor.img \
                vendor.map \
                super.img \
                super_empty.img \
                product.img \
                carrier.img \
                flash_ap.sh \
                flash_ap.bat \
                flashall.sh \
                flashall.bat \
                flashall.xml \
                flashfile_config.xml \
                motoproducts.txt \
                programutags.sh \
                programutags.bat \
                hwflash.sh \
                hwflash.bat \
                hwflash.xml \
                Windows/ \
                Linux/fastboot \
                Linux/fastbootip \
                Darwin/fastboot \
                Darwin/fastbootip \
                fastboot \
                android-info.txt \
                ${DEVTREE} "

if [ "${customer}" == "Factory" ]; then
    fastboot_files+=" \
                     pds.img \
                     persist.img"
fi

# image get from target file
target_file_images="boot.img \
                dtbo.img \
                system.img \
                system_other.img \
                system.map \
                vendor.img \
                vendor.map \
                vbmeta.img \
                product.img \
                recovery.img"

qcom_bootloader_files_1="bootloader.img \
     sbl1.mbn \
                pmic.mbn \
                emmc_appsboot.mbn \
                programmer.elf \
                pmic.elf \
                abl.elf \
                qupfw.elf \
                xbl_config.elf \
                xbl.elf"

qcom_bootloader_files_2="motoboot.img \
                motoboot_4015.img \
                sbl1_8226.mbn \
                sbl1_8626.mbn \
                sbl1_8926.mbn \
                sbl1_8210.mbn \
                sbl1_8610.mbn \
                sbl2.mbn \
                sbl3.mbn \
                keymaster.mbn \
                keymaster64.mbn \
                cmnlib.mbn \
                cmnlib_30.mbn \
                cmnlib64_30.mbn \
                cmnlib64.mbn \
                lksecapp.mbn \
                devcfg.mbn \
                tz.mbn \
                rpm.mbn \
                aop.mbn \
                sdi.mbn \
                prov64.mbn \
                prov32.mbn \
                prov.mbn \
                storsec.mbn \
                uefi_sec.mbn \
                featenabler.mbn \
                spss1p.mbn \
                spss2p.mbn \
                hyp.mbn"

nvflash_files="pds.uid \
               flash_nv.bat \
               flash_uboot.cfg \
               flash.bct"

ota_files="bp.img \
           lte.img \
           fs_config.cfg \
           partition.xml \
           muc_ota.zip \
           multiconfig-bp-delta.script \
           fotabota_includelist.cfg \
           obj/EXECUTABLES/updater_intermediates/updater \
           ../../../host/linux-x86/bin/fs_config \
           supportedmodels.txt \
           ${mbm_location}/${mbm_hw_config}/mbmloader.bin>mbmloader_ns.bin \
           ${mbm_location}/${mbm_hw_config}-signed/mbmloader.bin>mbmloader_hs.bin \
           ${mbm_location}/${mbm_hw_config}-signed/mbm.bin>mbm.bin \
           ext4_parts_to_fixup.txt \
           ext4fixup_static \
           msm8226 \
           msm8926 \
           msm8210 \
           msm8610 \
           msm8626"

ota_files1="obj/PACKAGING/target_files_intermediates/*/META"

fastboot_script_files="fastboot.xml \
                       flash_fastboot.bat"

signed_files="$BUILDOUT/secure/boot_signed>boot.img \
              $BUILDOUT/secure/system_signed>system.img \
              ${platform_dir}/out/dist/system_other.img_signed>system_other.img \
              ${platform_dir}/out/dist/system.img_signed>system.img \
              ${platform_dir}/out/dist/system.map>system.map \
              ${platform_dir}/out/dist/recovery.img_signed>recovery.img \
              ${platform_dir}/out/dist/boot.img_signed>boot.img \
              ${platform_dir}/out/dist/dtbo.img_signed>dtbo.img \
              ${platform_dir}/out/dist/preinstall.img>preinstall.img \
              ${platform_dir}/out/dist/vendor.img_signed>vendor.img \
              ${platform_dir}/out/dist/vendor.map>vendor.map \
              ${platform_dir}/out/dist/vbmeta.img_signed>vbmeta.img \
              ${platform_dir}/out/dist/product.img_signed>product.img \
              ${platform_dir}/out/dist/super.img_signed>super.img \
              $BUILDOUT/secure/devtree_signed>device_tree.bin \
              $BUILDOUT/secure/ebr_signed>ebr \
              $BUILDOUT/secure/mbr_signed>mbr \
              $BUILDOUT/secure/lbl_signed>lbl \
              $BUILDOUT/secure/motoboot_signed.img>motoboot.img \
              $BUILDOUT/secure/cdrom_signed>cdrom
              $BUILDOUT/secure/persist_signed>persist.img.ext4 \
              $BUILDOUT/secure/gpt_signed>gpt_main0.bin \
              $BUILDOUT/secure/userdata_signed>userdata.img \
              $BUILDOUT/secure/gpt.bin_signed>gpt.bin \
              $BUILDOUT/secure/logo.bin_signed>logo.bin \
              $BUILDOUT/secure/modem_signed>NON-HLOS.bin \
              $BUILDOUT/secure/radio_firmware-signed.bin>radio_firmware.bin \
              $BUILDOUT/secure/fsg_signed>fsg.mbn \
              $BUILDOUT/secure/carrier.img_signed>carrier.img"

signed_qcom_bl_files="$BUILDOUT/secure/bootloader_signed.img>bootloader.img \
     $BUILDOUT/secure/motoboot_signed.img>motoboot.img \
     $BUILDOUT/secure/sbl1_signed>sbl1.mbn \
     $BUILDOUT/secure/sbl2_signed>sbl2.mbn \
     $BUILDOUT/secure/sbl3_signed>sbl3.mbn \
     $BUILDOUT/secure/rpm_signed>rpm.mbn \
     $BUILDOUT/secure/tz_signed>tz.mbn \
     $BUILDOUT/secure/emmc_appsboot.mbn_signed>emmc_appsboot.mbn"

copy_done=0
if [ -d ${mbm_location}/reflash ]; then
   mbm_path=${mbm_location}/reflash
   if [ -n "$(mmi_get_build_var SEPARATE_SIGNED_BL_IMAGES)" ]; then
      if [ -f $mbm_path/emmc_appsboot.mbn ]; then
          echo "creating flashall bootloader.img: ${BUILDOUT}/bootloader.img"

          # check whether go motoboot format or star format
          if [ -d ${platform_dir}/${prebuilt_bootloader_dir}/../singleimage ] || [ -d ${platform_dir}/device/moto/${product}/prebuilt/singleimage ] || [ -d ${platform_dir}/device/moto/mot${target_board_platform:3}/prebuilt/singleimage ]; then
             star_tool=${platform_dir}/bootable/bootloader/boottools/bin/star
             cont_imgs="$(mmi_get_build_var SEPARATE_SIGNED_BL_IMAGES) $(mmi_get_build_var SEPARATE_SIGNED_TZ4_IMAGES)"
             # find the prebuilt and update
             cp -f $mbm_path/bootloader.img $BUILDOUT
             for cont_img in ${cont_imgs}; do
                ${star_tool} -f ${BUILDOUT}/bootloader.img add-as ${BUILDOUT}/mbm-ci/${cont_img%:*} "${cont_img%:*}"
             done
          else
             packimg_py=${platform_dir}/vendor/qcom/nonhlos/build_support/bin/packimg.py
             rm ${BUILDOUT}/bootloader.img
             mot_bl1=$(mmi_get_build_var MOTOBOOT_BL_IMAGES)
             mot_bl2=$(mmi_get_build_var MOTOBOOT_SEPARATED_BL_IMAGES)
             input_boot_imgs=""
             for bl_img in ${mot_bl1}; do
                input_boot_imgs+="${mbm_path}/${bl_img} "
             done
             for bl_img in ${mot_bl2}; do
                input_boot_imgs+="${BUILDOUT}/mbm-ci/${bl_img} "
             done
             ${packimg_py} --verbose --output=${BUILDOUT}/bootloader.img $input_boot_imgs
          fi

          for bl_file in ${qcom_bootloader_files_1}; do
             if [ -f $mbm_path/${bl_file} ]; then
               cp -f $mbm_path/${bl_file} $BUILDOUT/${out_name}
             fi
          done
          cp -f ${BUILDOUT}/bootloader.img $BUILDOUT/${out_name}
          if [ -d $BUILDOUT/mbm-ci ]; then
             bl_path=$BUILDOUT/mbm-ci
          else
             bl_path=$BUILDOUT
          fi
          echo "copy bootloader file from $mbm_path and $bl_path to $BUILDOUT/${out_name}"
          for bl_file in ${qcom_bootloader_files_2}; do
             if [ -f $bl_path/${bl_file} ]; then
               cp -f $bl_path/${bl_file} $BUILDOUT/${out_name}
             fi
          done
          copy_done=1
      else
          echo "WARNING: SEPARATE_BOOTLOADER_RELEASE=true, but couldn't find bootloader files in $mbm_path"
      fi
   elif [ -f $mbm_path/emmc_appsboot.mbn ]; then
      echo "copy bootloader file from $mbm_path to $BUILDOUT/${out_name}"
      for bl_file in ${qcom_bootloader_files_1}; do
         if [ -f $mbm_path/${bl_file} ]; then
            cp -f $mbm_path/${bl_file} $BUILDOUT/${out_name}
         fi
      done
      for bl_file in ${qcom_bootloader_files_2}; do
         if [ -f $mbm_path/${bl_file} ]; then
           cp -f $mbm_path/${bl_file} $BUILDOUT/${out_name}
         fi
      done
      copy_done=1
   else
      echo "WARNING: couldn't find bootloader files in $mbm_path"
   fi
fi

if [ "${copy_done}" == "0" ]; then
   if [ -d $BUILDOUT/mbm-ci ]; then
      mbm_path=$BUILDOUT/mbm-ci
   else
      mbm_path=$BUILDOUT
   fi
   echo "copy bootloader file from $mbm_path to $BUILDOUT/${out_name}"
   for bl_file in ${qcom_bootloader_files_1}; do
      if [ -f $mbm_path/${bl_file} ]; then
        cp -f $mbm_path/${bl_file} $BUILDOUT/${out_name}
      fi
   done
   for bl_file in ${qcom_bootloader_files_2}; do
      if [ -f $mbm_path/${bl_file} ]; then
        cp -f $mbm_path/${bl_file} $BUILDOUT/${out_name}
      fi
   done
fi

for out_file in ${fastboot_files}; do
   if [ "${out_file}" == "fastboot" ]; then
       cp -f ${platform_dir}/out/host/${architecture}/bin/${out_file} $BUILDOUT/${out_name}
   elif [ "${out_file}" == "Linux/fastboot" ]; then
       mkdir -p $BUILDOUT/${out_name}/Linux
       if [ -f $BUILDOUT/Linux/fastboot ]; then
           cp -f $BUILDOUT/Linux/fastboot $BUILDOUT/${out_name}/Linux
       fi
   elif [ "${out_file}" == "Darwin/fastboot" ]; then
       mkdir -p $BUILDOUT/${out_name}/Darwin
       if [ -f $BUILDOUT/Darwin/fastboot ]; then
           cp -f $BUILDOUT/Darwin/fastboot $BUILDOUT/${out_name}/Darwin
       fi
   elif [ "${out_file}" == "fastbootip" ]; then
       cp -f ${platform_dir}/out/host/${architecture}/bin/${out_file} $BUILDOUT/${out_name}
   elif [ "${out_file}" == "Linux/fastbootip" ]; then
       mkdir -p $BUILDOUT/${out_name}/Linux
       if [ -f $BUILDOUT/Linux/fastbootip ]; then
           cp -f $BUILDOUT/Linux/fastbootip $BUILDOUT/${out_name}/Linux
       fi
   elif [ "${out_file}" == "Darwin/fastbootip" ]; then
       mkdir -p $BUILDOUT/${out_name}/Darwin
       if [ -f $BUILDOUT/Darwin/fastbootip ]; then
           cp -f $BUILDOUT/Darwin/fastbootip $BUILDOUT/${out_name}/Darwin
       fi
   elif [ "${out_file}" == "Windows/" ]; then
       mkdir -p $BUILDOUT/${out_name}/Windows
       if [ -d $BUILDOUT/Windows ]; then
           cp -f $BUILDOUT/Windows/* $BUILDOUT/${out_name}/Windows
       fi
   elif [ "${out_file}" == "fsg_ensdisable.mbn" ]; then
       if [ -f ${platform_dir}/device/moto/${device}/prebuilt/nonhlos/modem_proc/fsg/customer/fsg_ensdisable.mbn ]; then
           cp -f ${platform_dir}/device/moto/${device}/prebuilt/nonhlos/modem_proc/fsg/customer/fsg_ensdisable.mbn $BUILDOUT/${out_name}
       fi
   elif [ -f $BUILDOUT/${out_file}.ext4 ]; then
           mkdir -p $BUILDOUT/${out_name}
           cp -f $BUILDOUT/${out_file}.ext4 $BUILDOUT/${out_name}
   else
       dir=`dirname ${out_file}`
       mkdir -p $BUILDOUT/${out_name}/${dir}

       TARGET_FILE_ZIP=$BUILDOUT/obj/PACKAGING/target_files_intermediates/${product}-target_files-${BUILD_NUMBER}.zip
       TARGET_IMAGE=$BUILDOUT/obj/PACKAGING/target_files_intermediates/${product}-target_files-${BUILD_NUMBER}/IMAGES/${out_file}
       SUPER_INTERMEDIATES=$BUILDOUT/obj/PACKAGING/super.img_intermediates
       for out_file_with_path in $BUILDOUT/${out_file}; do
           out_fileglob=${out_file_with_path#$BUILDOUT/}

           skip_file_copy="false"
           # do not include individual DAP images (system, vendor, etc), since they are embedded into super.img
           if [ "${build_super_partition}" == "true" ] && [ ! -z ${super_partition_size} ]; then
               out_file_no_suffix=$(echo ${out_fileglob}|sed 's/\.img$//g'|sed 's/_other$//g')
               if [[ "${super_partition_list}" == *${out_file_no_suffix}* ]]; then
                   skip_file_copy="true"
           # Pick super.img from target intermediates , not from root
               elif [ "${out_fileglob}" == "super.img" ]; then
                  if [ -f $SUPER_INTERMEDIATES/super.img ]; then
                     echo "copy super.img from intermediates"
                     cp -f $SUPER_INTERMEDIATES/super.img $BUILDOUT/${out_name}/${dir}
                     skip_file_copy="true"
                  fi
               fi
           fi
           if [ "${skip_file_copy}" == "true" ]; then
               continue
           fi

           # The image in target_file_images list should copy from TARGET_FILE_ZIP
           if [ -f ${TARGET_FILE_ZIP} ] && [[ ${target_file_images} =~ ${out_fileglob} ]] && [ -f ${TARGET_IMAGE} ]; then
               no_recovery="false"
               if [ -d $BUILDOUT/${out_file1} ]; then
                   no_recovery=`cat ${BUILDOUT}/${ota_files1}/misc_info.txt | grep -m 1 "no_recovery=" | awk -F= '{print $2}'`
               fi
               if [ "${out_fileglob}" == "recovery.img" ] && [ "${no_recovery}" == "true" ]; then
                   echo "TARGET_NO_RECOVERY is true, ignore the recovery.img"
               else
                   echo "unzip -p ${TARGET_FILE_ZIP} IMAGES/${out_fileglob} > $BUILDOUT/${out_name}/$dir/${out_fileglob}"
               unzip -p ${TARGET_FILE_ZIP} IMAGES/${out_fileglob} > $BUILDOUT/${out_name}/$dir/${out_fileglob}
               fi
           elif [ -f $BUILDOUT/${out_fileglob} ]; then
               cp -f $BUILDOUT/${out_fileglob} $BUILDOUT/${out_name}/${dir}
           fi
       done
   fi
done

if [ -f ${platform_dir}/out/target/installed_modules.txt ]; then
   if [ -d ${platform_dir}/out/release ]; then
           cp -f ${platform_dir}/out/target/installed_modules.txt ${platform_dir}/out/release
   fi
fi

#Copy mbm and mbm-ci folder
if [ -d $BUILDOUT/mbm ]; then
      cp -r $BUILDOUT/mbm $BUILDOUT/${out_name}/
fi

if [ -d $BUILDOUT/mbm-ci ]; then
      cp -r $BUILDOUT/mbm-ci $BUILDOUT/${out_name}/
fi

#Copy emmc and ufs folder
if [ -d $BUILDOUT/emmc ]; then
      cp -r $BUILDOUT/emmc $BUILDOUT/${out_name}/
fi
if [ -d $BUILDOUT/ufs ]; then
      cp -r $BUILDOUT/ufs $BUILDOUT/${out_name}/
fi

#Copy nonhlos_debug folder
if [ -d $BUILDOUT/nonhlos_debug ]; then
      cp -r $BUILDOUT/nonhlos_debug $BUILDOUT/${out_name}/
fi

##### Workaround for issue with bat file generation in tablets #####
if [ -f /apps/platform/flash_fastboot.bat ]; then
      cp -f /apps/platform/flash_fastboot.bat $BUILDOUT/${out_name}
elif [ -f ${platform_dir}/vendor/moto/${device}/${product}/flash_fastboot.bat ]; then
      cp -f ${platform_dir}/vendor/moto/${device}/${product}/flash_fastboot.bat $BUILDOUT/${out_name}
elif [ -f ${platform_dir}/vendor/moto/${device}/flash_fastboot.bat ]; then
      cp -f ${platform_dir}/vendor/moto/${device}/flash_fastboot.bat $BUILDOUT/${out_name}
fi

for out_file in ${ota_files}; do
   if [ -f $BUILDOUT/${out_file} ]; then
      mkdir -p $BUILDOUT/${out_name}/ota
      cp -f $BUILDOUT/${out_file} $BUILDOUT/${out_name}/ota
   else
      src_file_name=`echo ${out_file} | cut -d '>' -f1`
      out_file_name=`echo ${out_file} | cut -d '>' -f2`
      if [ -f ${src_file_name} ]; then
         mkdir -p $BUILDOUT/${out_name}/ota
         cp -f ${src_file_name} $BUILDOUT/${out_name}/ota/${out_file_name}
      fi
   fi
done
for out_file1 in ${ota_files1}; do
   if [ -d $BUILDOUT/${out_file1} ]; then
      mkdir -p $BUILDOUT/${out_name}/ota
      cp -rf $BUILDOUT/${out_file1} $BUILDOUT/${out_name}/ota
   fi
done


if [ "${sign_keys}" == "product" ] || [ "${device_uid_path}" != "" ]; then
   for out_file in ${signed_files}; do
      src_file_name=`echo ${out_file} | cut -d '>' -f1`
      out_file_name=`echo ${out_file} | cut -d '>' -f2`
      if [ -f ${src_file_name} ]; then
         mkdir -p $BUILDOUT/${out_name}
         cp -f ${src_file_name} $BUILDOUT/${out_name}/${out_file_name}
      fi
   done
   for out_file in ${signed_qcom_bl_files}; do
       src_file_name=`echo ${out_file} | cut -d '>' -f1`
   out_file_name=`echo ${out_file} | cut -d '>' -f2`
   if [ -f ${src_file_name} ]; then
       mkdir -p $BUILDOUT/${out_name}/mbm-ci
       cp -f ${src_file_name} $BUILDOUT/${out_name}/mbm-ci/${out_file_name}
       fi
   done
fi

if [ -d $BUILDOUT/secure ]; then
     cd $BUILDOUT/secure
     ln -sf ../${out_name}/ota ota
fi

cd ${platform_dir}
if [ -f $BUILDOUT/${out_name}/gpt.bin ]; then
   echo "copy gpt images to $BUILDOUT/${out_name}/ota"
   motorola/build/bin/parse_single_image.py -e -o $BUILDOUT/${out_name}/ota -i $BUILDOUT/${out_name}/gpt.bin -x gpt.default.xml
fi

if [ -f $BUILDOUT/otatools.zip ]; then
   echo "copy otatools.zip to $BUILDOUT/${out_name}/ota"
   mkdir -p $BUILDOUT/${out_name}/ota
   cp -f $BUILDOUT/otatools.zip $BUILDOUT/${out_name}/ota
fi

# Call any post build handlers installed by component teams
echo "calling post build handlers"
if [ -d ${BUILDOUT}/post_build_handlers ]; then
   # set up environment variables for handlers to use
   # BDH is short for Build Device Handler
   export BDH_BUILDOUT_DIR=${BUILDOUT}
   export BDH_RELEASE_DIR=${release_dir}
   export BDH_PACKAGE_NAME=${out_name}

   # handlers must follow expected naming convention and have
   # execute permission so that other helper scripts, binaries,
   # libraries or regular files could coexist
   for h in `ls ${BUILDOUT}/post_build_handlers/bdh*.sh`; do
      if [ -x ${h} ]; then ${h}; fi
   done
fi

if [ "${sign_keys}" != "product" ] && [ "${HAB_APK_SIGNING_ONLY}" == "1" ]; then
   echo "Copying system.img and recovery.img with signed apks"
   if [ "${nonhlos}" == "nonhlos" ]; then
      if [ -f $BUILDOUT/system.img.ext4 ]; then
         cp ${platform_dir}/out/dist/system.img $BUILDOUT/${out_name}/system.img.ext4
      else
         cp ${platform_dir}/out/dist/system.img $BUILDOUT/${out_name}
      fi
   else
      cp ${platform_dir}/out/dist/system.img $BUILDOUT/${out_name}
   fi

   cp ${platform_dir}/out/dist/recovery.img $BUILDOUT/${out_name}
   if [ -f ${platform_dir}/out/dist/preinstall.img ]; then
      echo "Copying preinstall.img with signed apks"
      cp ${platform_dir}/out/dist/preinstall.img $BUILDOUT/${out_name}
   fi
fi

for out_file in ${build_int_files}; do
   if [ -f $BUILDOUT/${out_file} ]; then
      mkdir -p $BUILDOUT/build_intermediates_${out_name}
      cp -f $BUILDOUT/${out_file} $BUILDOUT/build_intermediates_${out_name}
   fi
done
for out_file in ${nvflash_files}; do
   if [ -f $BUILDOUT/${out_file} ]; then
      mkdir -p $BUILDOUT/nvflash_${out_name}
      cp -f $BUILDOUT/${out_file} $BUILDOUT/nvflash_${out_name}
   fi
done

if [ -f ${platform_dir}/vendor/moto/${device}/${product}/default_flash.xml ]; then
    cp ${platform_dir}/vendor/moto/${device}/${product}/default_flash.xml $BUILDOUT/${out_name}
elif [ -f ${platform_dir}/vendor/moto/${device}/default_flash.xml ]; then
    cp ${platform_dir}/vendor/moto/${device}/default_flash.xml $BUILDOUT/${out_name}
elif [ -f ${platform_dir}/device/moto/${device}/default_flash.xml ]; then
    cp ${platform_dir}/device/moto/${device}/default_flash.xml $BUILDOUT/${out_name}
fi

if [ -f ${platform_dir}/signing-info.txt ]; then
    cp ${platform_dir}/signing-info.txt $BUILDOUT/${out_name}
fi

if [ -f ${platform_dir}/vendor/moto/${device}/flash_scripts/flashall.sh ]; then
    cp ${platform_dir}/vendor/moto/${device}/flash_scripts/flashall.sh $BUILDOUT/${out_name}
fi
if [ -f ${platform_dir}/vendor/moto/${device}/flash_scripts/flashall.bat ]; then
    cp ${platform_dir}/vendor/moto/${device}/flash_scripts/flashall.bat $BUILDOUT/${out_name}
fi
if [ -f ${platform_dir}/device/moto/${device}/flash_scripts/flashall.sh ]; then
    cp ${platform_dir}/device/moto/${device}/flash_scripts/flashall.sh $BUILDOUT/${out_name}
fi

if [ "${build_sw_oem}" == "true" ]; then
   # we need add oem image
   oem_image_file=$(echo ${build_oem_image} | awk -F- '{print $1}')
   oem_other_image_file=${oem_image_file}_other

      if [ -f $BUILDOUT/${oem_image_file}.img ]; then
         if [ "${RADIO_SECURE}" == "1" ]; then
               echo "copy $BUILDOUT/secure/${oem_image_file}.img_signed > $BUILDOUT/${out_name}/oem.img"
               cp -rf $BUILDOUT/secure/${oem_image_file}.img_signed $BUILDOUT/${out_name}/oem.img
               # Pack releasekey signed oem other image if present
               if [ -f $BUILDOUT/secure/${oem_image_file}_other.img_signed ]; then
                   echo "copy $BUILDOUT/secure/${oem_image_file}_other.img_signed > $BUILDOUT/${out_name}/oem_other.img"
                   cp -rf $BUILDOUT/secure/${oem_image_file}_other.img_signed $BUILDOUT/${out_name}/oem_other.img
               fi
         else
               echo "copy $BUILDOUT/${oem_image_file}.img > $BUILDOUT/${out_name}/oem.img"
               cp -rf $BUILDOUT/${oem_image_file}.img $BUILDOUT/${out_name}/oem.img
               if [ -f $BUILDOUT/${oem_other_image_file}.img ]; then
                  echo "copy $BUILDOUT/${oem_other_image_file}.img > $BUILDOUT/${out_name}/oem_other.img"
                  cp -rf $BUILDOUT/${oem_other_image_file}.img $BUILDOUT/${out_name}/oem_other.img
               fi
         fi
         echo "copy $BUILDOUT/oem/oem.prop > $BUILDOUT/${out_name}/oem.prop"
         cp -rf $BUILDOUT/oem/oem.prop $BUILDOUT/${out_name}/oem.prop
         echo "copy $BUILDOUT/${oem_image_file}.map > $BUILDOUT/${out_name}/oem.map"
         cp -rf $BUILDOUT/${oem_image_file}.map $BUILDOUT/${out_name}/oem.map
         oem_product_name=$(grep ro.product.name= $BUILDOUT/oem/oem.prop | awk -F= '{print $2}')
         if [ "u${oem_product_name}" == "u" ]; then
            # ro.product.name does not set in oem.prop, use the core build one
            oem_product_name=${product}
         fi
         device_name=$(echo ${oem_product_name} | awk -F_ '{print $1}')
         if [ "${oem_product_name}" == "${device_name}" ]; then
             oem_product_carrier=""
         else
             oem_product_carrier=$(echo ${oem_product_name#${device_name}_})
             if [ "u${oem_product_carrier}" != "u" ]; then
                 oem_product_carrier="_${oem_product_carrier}"
             fi
         fi
         oem_out_name=$(echo ${out_name} | sed "s/${product}/${oem_product_name}_oem${oem_product_carrier}/g" | sed "s/_${build_blur_carrier_region}$/${oem_product_carrier}/g")
         echo "Generic out name: ${out_name}"
         echo "OEM out name: ${oem_out_name}"
         if [ "u${oem_out_name}" != "u" ] && [ "${oem_out_name}" != "${out_name}" ]; then
            if [ -d $BUILDOUT/${oem_out_name} ]; then
               rm -fr $BUILDOUT/${oem_out_name}
            fi
            (cd $BUILDOUT; mv ${out_name} ${oem_out_name})
            out_name=${oem_out_name}
         fi
      fi
fi

if [ "${build_fastboot_package}" == "true" ]; then
   (cd $BUILDOUT; if [ -d ${out_name} ]; then tar c ${out_name} | ${my_zip} > $RELEASEDIR/fastboot_${out_name}.tar.$zip_ext; fi)
   wait
fi

if [ "${build_misc_zipfiles}" == "true" ]; then
   (cd $BUILDOUT; if [ -d build_intermediates_${out_name} ]; then tar c build_intermediates_${out_name} | ${my_zip} > $RELEASEDIR/build_intermediates-${out_name}.tar.$zip_ext; fi) &
   (cd $BUILDOUT; if [ -d nvflash_${out_name} ]; then tar c nvflash_${out_name} | ${my_zip} > $RELEASEDIR/nvflash-${out_name}.tar.$zip_ext; fi) &
   wait
fi

#IKARCH-1583 Save adb/fastboot files in release folder --begin
mkdir -p $release_dir/tools/Linux
mkdir -p $release_dir/tools/Darwin
mkdir -p $release_dir/tools/Windows

if [ -f ${platform_dir}/device/moto/common/fastboot/Linux/fastboot ]; then
     cp -f ${platform_dir}/device/moto/common/fastboot/Linux/fastboot $release_dir/tools/Linux
fi
if [ -f ${platform_dir}/device/moto/common/adb/Linux/adb ]; then
     cp -f ${platform_dir}/device/moto/common/adb/Linux/adb $release_dir/tools/Linux
fi
if [ -f ${platform_dir}/device/moto/common/fastboot/Darwin/fastboot ]; then
     cp -f ${platform_dir}/device/moto/common/fastboot/Darwin/fastboot $release_dir/tools/Darwin
fi
if [ -f ${platform_dir}/device/moto/common/adb/Darwin/adb ]; then
     cp -f ${platform_dir}/device/moto/common/adb/Darwin/adb $release_dir/tools/Darwin
fi
if [ -f ${platform_dir}/device/moto/common/fastboot/Windows/AdbWinApi.dll ]; then
     cp -f ${platform_dir}/device/moto/common/fastboot/Windows/AdbWinApi.dll $release_dir/tools/Windows
fi
if [ -f ${platform_dir}/device/moto/common/fastboot/Windows/fastboot.exe ]; then
     cp -f ${platform_dir}/device/moto/common/fastboot/Windows/fastboot.exe $release_dir/tools/Windows
fi
if [ -f ${platform_dir}/device/moto/common/adb/Windows/windows-adb.exe ]; then
     cp -f ${platform_dir}/device/moto/common/adb/Windows/windows-adb.exe $release_dir/tools/Windows
fi
#IKARCH-1583 Save adb/fastboot files in release folder --end
if [ -f $BUILDOUT/system/build.prop ]; then
    cp $BUILDOUT/system/build.prop ${platform_dir}/release/
fi

if [ "${build_misc_zipfiles}" == "true" ]; then
   if [ "${BUILD_MSI_ENABLE}" == "true" ]; then
       cd $MSIBUILDOUT
       tar c system | ${my_zip} > $RELEASEDIR/system.tar.$zip_ext
   else
       cd $BUILDOUT
       tar c system | ${my_zip} > $RELEASEDIR/system.tar.$zip_ext
   fi
   cd $BUILDOUT
   tar c symbols | ${my_zip} > $RELEASEDIR/symbols.tar.$zip_ext
   tar c data | ${my_zip} > $RELEASEDIR/userdata.tar.$zip_ext
   if [ -d nonhlos_symbols ]; then
       tar c nonhlos_symbols | ${my_zip} > $RELEASEDIR/nonhlos_symbols.tar.$zip_ext
   fi

   if [ -f obj/PARTITIONS/kernel_intermediates/build/vmlinux ]; then
    cat obj/PARTITIONS/kernel_intermediates/build/vmlinux | ${my_zip} > $RELEASEDIR/vmlinux.$zip_ext
   fi
   if [ -f obj/KERNEL_OBJ/vmlinux ]; then
    cat obj/KERNEL_OBJ/vmlinux | ${my_zip} > $RELEASEDIR/vmlinux.$zip_ext
   fi

   if [ -f blankflash.zip ]; then
     cp blankflash.zip $RELEASEDIR/blankflash.zip
   fi

   if [ -f ${product}-qpst-flash.zip ]; then
    cp ${product}-qpst-flash.zip $RELEASEDIR/${product}-qpst-flash.zip
   fi
fi

cd ${platform_dir}

if [ "${gen_fact_package}" == "1" ]; then
   if [ -f ${RELEASEDIR}/fastboot_${out_name}.tar.$zip_ext ]; then
      echo "Generating Factory Package(s)"
      motorola/build/bin/build_factory_package.py -p ${product} -v
   fi
fi

if [ "${MOT_TARGET_BUILD_ADDITIONAL_CONFIG}" != "" ]; then
   SPECIAL_BUILD_STAGE=post
   source device/moto/common/build/special_build_config.sh
fi

cd ${platform_dir}

# Generate Build_Commands.txt
rm -f ${platform_dir}/out/Build_Commands.txt
echo "$build_command_line" > ${platform_dir}/out/Build_Commands.txt
if [ "${MOT_TARGET_BUILD_ADDITIONAL_CONFIG}" == "" ]; then
    echo "OR" >> ${platform_dir}/out/Build_Commands.txt
    echo "source build/envsetup.sh" >> ${platform_dir}/out/Build_Commands.txt
    echo "lunch ${product}-${build_flavor}" >> ${platform_dir}/out/Build_Commands.txt
    echo "make -jX" >> ${platform_dir}/out/Build_Commands.txt
fi
# Generate Overlay.txt
rm -f ${platform_dir}/out/Overlay.txt
echo "PRODUCT_PACKAGE_OVERLAYS = $(mmi_get_build_var PRODUCT_PACKAGE_OVERLAYS)" > ${platform_dir}/out/Overlay.txt
echo "DEVICE_PACKAGE_OVERLAYS = $(mmi_get_build_var DEVICE_PACKAGE_OVERLAYS)" >> ${platform_dir}/out/Overlay.txt

# Find and copy partition.xml to release folder
if [ -d ${platform_dir}/out/release ]; then
    rm -f ${platform_dir}/out/release/partition.xml
    partition_path=$(mmi_get_build_var BOARD_PARTITION_FILE)
    if [ -e "${platform_dir}/${partition_path}" ]; then
        cp -f ${platform_dir}/${partition_path} ${platform_dir}/out/release/partition.xml || true
    fi

    #IKUIPRC-50 copy LVP_applist.csv and LVP_applist_GB.csv to release folder --begin
    rm -f ${platform_dir}/out/release/LVP_applist.csv
    rm -f ${platform_dir}/out/release/LVP_applist_GB.csv

    if [ -f ${platform_dir}/out/LVP_applist.csv ]; then
        cp -f ${platform_dir}/out/LVP_applist.csv ${platform_dir}/out/release/LVP_applist.csv || true
    fi
    if [ -f ${platform_dir}/out/LVP_applist_GB.csv ]; then
        cp -f ${platform_dir}/out/LVP_applist_GB.csv ${platform_dir}/out/release/LVP_applist_GB.csv || true
    fi
    #IKUIPRC-50 copy LVP_applist.csv and LVP_applist_GB.csv to release folder --end
fi

# Get salesforce configuration values for user signed build
if [[ "${RADIO_SECURE}" == "1" ]] && [[ "${gen_salesforce}" == "1" ]]; then
    echo "Call SaleForce: ${sfdc_script} -p ${product}"
    ${sfdc_script} -p ${product}
fi

# CR IKSWO-5087 to copy vendor's build.prop to release folder
if [ -f $ANDROID_PRODUCT_OUT/vendor/build.prop ]; then
    cp $ANDROID_PRODUCT_OUT/vendor/build.prop ${platform_dir}/release/vendor_build.prop
    echo "INFO: Copied vendor_build.prop to the release folder"
fi

# CR IKSWQ-3117 copy product partition's build.prop to release folder
if [ -f $ANDROID_PRODUCT_OUT/product/build.prop ]; then
    cp $ANDROID_PRODUCT_OUT/product/build.prop ${platform_dir}/release/product_build.prop
    echo "INFO: Copied product_build.prop to the release folder"
fi

if [ -f ${platform_dir}/signing-info.txt ]; then
    echo "copy ${platform_dir}/signing-info.txt > ${platform_dir}/release/signing-info.txt"
    cp ${platform_dir}/signing-info.txt ${platform_dir}/release/signing-info.txt
    echo "INFO: Copied signing-info.txt to the release folder"
fi

release_build_info


echo ".......BUILD COMPLETED........"
