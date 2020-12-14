#! /bin/sh --
#! -*- perl -*-
eval 'exec env LD_LIBRARY_PATH="/apps/android/mysql_client_5.1.50/lib/mysql:$LD_LIBRARY_PATH" \
               XML_SIMPLE_PREFERRED_PARSER=XML::Parser \
               PATH="/apps/android/perl-5.26.0-x64/bin:/apps/android/bin:/usr/bin:$PATH" \
           perl -x $0 ${1+"$@"}'
    if (0);
####################################################################################################
#
# Copyright Motorola Mobility 2010-2019, All rights reserved.
#   Motorola Mobility Confidential Proprietary
#   Contains confidential proprietary information of Motorola Mobility, Inc.
#   Reverse engineering is prohibited.
#   The copyright notice does not imply publication.
#
####################################################################################################

####################################################################################################
# MAIN (POD) DOCUMENTATION
####################################################################################################
=pod

=head1 NAME

product_build.pl

=head1 DESCRIPTION

Performs an automated release for the specified build type and flavor.

=head1 SYNOPSIS

product_build.pl -help

product_build.pl
    -build_type              { continuous_plugin_trigger |
                               daily_plugin_trigger }
    { -compile_target        <target> |
      -product_group         <product group> }
    [ -debug ]
    -manifest_branch         <Branch>
    [ -manifest_file         <Manifest file name> ]
    -manifest_url            <URL or Path>
    [ -passed_in_tag_file    <tag file> ]
    [ -tag_info_prefix       <prefix> ]
    [ -test_db ]

product_build.pl
    -build_type              promotion_plugin_trigger
    { -compile_target        <target> |
      -product_group         <product group> }
    -continuous_job_name     <Continuous_job_name>
    [ -debug ]
    -manifest_branch         <Branch>
    [ -manifest_file         <Manifest file name> ]
    -manifest_url            <URL or Path>
    [ -passed_in_tag_file    <tag file> ]
    [ -product_form          <product form> ]
    -promote_based_on        <promotion_based_on>
    [ -tag_info_prefix       <prefix> ]
    [ -test_db ]

product_build.pl
    -build_flavor            <Build Flavor>
    -build_type              { continuous     |
                               daily          |
                               derivative     }
    [ -clean_workspace_upon_success ]
    { -compile_target        <target> |
      -product_group         <product group> }
    [ -debug ]
    [ -gerrit                <list of Gerrits> ]
    [ -hab_cid               <CID> ]
    -manifest_branch         <Branch>
    [ -manifest_file         <Manifest file name> ]
    [ -manifest_group        <Manifest group name(s)> ]
    -manifest_url            <URL or Path>
    [ -no_artifactory_upload ]
    [ -no_bota ]
    [ -no_bota_partition_check ]
    [ -no_build_id_check ]
    [ -no_build_ids_update ]
    [ -no_manifest_branch_check ]
    [ -no_nosync ]
    [ -no_oem ]
    [ -no_truncated_incremental_failure ]
    [ -no_update_jira ]
    [ -no_workspace_clean_upon_success ]
    [ {-oem_to_build | -oem_to_not_build } <OEM list> ]
    [ -oem_to_package <OEM list> ]
    [ -passed_in_tag_file    <tag file> ]
    [ -product_form          <product form> ]
    [ -replace_tag ]
    [ -sanity_test ]
    [ -tag_info_prefix       <prefix> ]
    [ -test_db ]

product_build.pl
    -build_flavor            <Build Flavor>
    -build_number_to_promote <Build_number_to_promote>
    -build_type              promote_continuous_to_daily
    [ -clean_workspace_upon_success ]
    { -compile_target        <target> |
      -product_group         <product group> }
    -continuous_job_name     <Continuous_job_name>
    [ -debug ]
    -manifest_branch         <Branch>
    [ -manifest_file         <Manifest file name> ]
    -manifest_url            <URL or Path>
    [ -no_artifactory_upload ]
    [ -no_bota ]
    [ -no_bota_partition_check ]
    [ -no_build_id_check ]
    [ -no_build_ids_update ]
    [ -no_nosync ]
    [ -no_oem ]
    [ -no_truncated_incremental_failure ]
    [ -no_update_jira ]
    [ {-oem_to_build | -oem_to_not_build } <OEM list> ]
    [ -oem_to_package <OEM list> ]
    [ -passed_in_tag_file    <tag file> ]
    [ -product_form          <product form> ]
    -promote_based_on        <promotion_based_on>
    [ -promoter_id <core ID> ]
    [ -replace_tag ]
    [ -sanity_test ]
    [ -tag_info_prefix       <prefix> ]
    [ -test_db ]

product_build.pl
    -build_type              promotion_child
    [ -no_bota ]
    [ -no_bota_partition_check ]
    [ -no_build_ids_update ]
    [ -no_nosync ]
    [ -no_update_jira ]
    -promotion_build_number  <number>
    -promotion_job_name      <Job name>

product_build.pl
    -build_flavor            <Build Flavor>
    -build_type              developer
    { -compile_target        <target> |
      -product_group         <product group> }
    [ -debug ]
    [ -gerrit                <list of Gerrits> ]
    -manifest_branch         <Branch>
    [ -manifest_file         <Manifest file name> ]
    [ -manifest_group        <Manifest group name(s)> ]
    -manifest_url            <URL or Path>
    [ -no_artifactory_upload ]
    [ -no_oem ]
    [ {-oem_to_build | -oem_to_not_build } <OEM list> ]
    [ -oem_to_package <OEM list> ]
    [ -product_form          <product form> ]
    [ -test_db ]

=over

=item -build_flavor <Build Flavor>

The flavor of the build.  This is usually only differenciated between each other by the make
command.

=item -build_type <Build Type>

Can be one of these:

=over

=item * continuous

Syncs, makes artifacts, and builds

=item * continuous_plugin_trigger

Designed to trigger a 'continuous' job in plugin.  It has to be called from "ShellTrigger" plugin.
This has a 10-minute timeout.

=item * daily

Syncs, makes artifacts, builds, makes release notes, tags, pushes changes and tags

=item * daily_plugin_trigger

Designed to trigger a 'daily' job in plugin.  It has to be called from "ShellTrigger" plugin.
This has a 10-minute timeout.

=item * derivative

Syncs, makes artifacts, builds, makes release notes

=item * developer

Syncs, compiles, no extra artifacts or anything

=item * promote_continuous_to_daily

Promotes a 'continuous' or 'continuous_oem' build by tagging and releasing an existing 'continuous'
 or 'continuous_oem' build as if it were 'daily'.  This type will only tag the manifest, collect
artifacts, and trigger the upload.

=item * promotion_child

Goes hand-in-hand with the 'promote_continuous_to_daily' type.  All outstanding tasks that make the
release will be done here instead.

=item * promotion_plugin_trigger

Designed to trigger a 'promote_continuous_to_daily' job in plugin.  It has to be called from
"ShellTrigger" plugin.  This has a 10-minute timeout.

=back

=item -build_number_to_promote <build number>

Receives build number to promote when promotion type is specific_build_number.
specific_build_number > 0

=item -clean_workspace_upon_success

If the build is successful, the workspace will be removed.  This is on by default for derivitive and
promotion_child types.

=item -compile_target <target>

In place of '-product_group', this will build for the target given.  For apps, this would be the
app name, e.g. omega_release

=item -continuous_job_name <Continuous Job name>

Receives continuous build job name

=item -debug

Performs the release, but does not do any permanent changes, like commiting and pushing.
Automatically will turn on '-test_db'.

=item -gerrit <list of Gerrits>

Specify a Gerrit or Gerrit,patch to cherry-pick.  If ',patch' is missing, the latest patch will be
used.  See example #3 for easiest usage.

=item -hab_cid <CID>

Only used for 'signed_cid' flavored builds.  Specify either the number or the description of the
CID.  If able to detect the correct CID, that detected value will be used.  Only usable with
'-compile_target'.

=item -manifest_branch <Branch>

The branch to use to download the manifest.  For 'derivative', this can be a manifest tag.

=item -manifest_file <Manifest file name>

The manifest file name if different from the default.  Ignored for 'derivative' type builds.

=item -manifest_group <Manifest group name(s)>

Comma-delimited list of manifest groups to sync.  Be careful as if different products share the same
build ID, use of this would become disasterous as the SHA1 manifest may not support some products.

=item -manifest_url <URL or Path>

URL or path to where the manifest will be fetched.

=item -no_artifactory_upload

Use this to turn off the Artifactory uploading.

=item -no_bota

Do not perform BOTA generation.

=item -no_bota_partition_check

Do not perform the partition check to allow a BOTA to be generated.

=item -no_build_id_check

Turn off the build_id check to see if the tag matches the build ID.

=item -no_build_ids_update

Turns off the auto-updating of the 'build_ids' repo.  Useful for components that should not be
updating the 'build_ids' files to reflect their component tags.

=item -no_manifest_branch_check

Turns off the check that the upstream job has the same 'manifest_branch' as the current.

=item -no_nosync

Do not use NoSync.

=item -no_oem

Turns off handling of OEM.

=item -no_truncated_incremental_failure

Do not fail when the truncated SHA1 for the incremental exceeds 8 characters.

=item -no_update_jira

Turns off the updating jira version.

=item -no_workspace_clean_upon_success

Do not remove the workspace after a successful run.

=item -oem_to_build <OEM list>

Comma-delimited list of OEM package names to build instead of all of them.  This is mutually
exclusive of '-oem_to_not_build'.

For continuous, overrides the default OEM package from 'oem' to the <OEM list> setting,
e.g. 'oem_o2'.  If the <OEM> does not exist, the default will be used instead.  The 'all' value is
also valid to build all OEMs.

=item -oem_to_not_build <OEM list>

Comma-delimited list of OEM package names to not build from the list of all of them.  Will be
ignored for continuous builds.  This is mutually exclusive of '-oem_to_build'.

=item -oem_to_package <OEM list>

Comma-delimitted list of OEM package names to make fastboots for.  If not specified, only the
default OEM will have a fastboot.

=item -passed_in_tag_file <tag file>

Specify a tag file instead of the default one.

=item -product_form  <product form>

Defaults to 'phone', takes 'phone', 'app', 'mod', 'watch' as choices.  Can be overridden by
ProductConfig also.

=item -product_group <product group>

Product group name.  Mutually exclusive of '-compile_target'.  This is deprecated and will
eventually be removed.

=item -promote_based_on

Receives promotion type input, this can be last_successful_continuous_build or
specific_continuous_build_number

=item -promoter_id <core ID>

The core ID of the one that requested the promotion.

=item -promotion_build_number <number>

The build number of the 'promote_continuous_to_daily' build.

=item -promotion_job_name <Job name>

The name of the job that corresponds to the 'promote_continuous_to_daily' build.

=item -replace_tag

If a tag was already released, using this will remove the tag and then replace the tag.

=item -repo_url <URL or Path>

URL or path to where the repo will be fetched.

=item -sanity_test

Using this will upload artifacts to the production Artifactory in the 'sandbox-public' repo.  This
switch can only be used in conjunction with '-debug' and '-test_db'.

=item -tag_info_prefix <prefix>

Used to indicate the tag info file to define the tag, '<prefix>_tag_info.txt'.  Whereas the default
will be <product group>

=item -test_db

Use the test database instead of the official.  Automatically will turn on '-debug'.

=back

=head1 ASSUMPTIONS

=over

=item 1.

The '.gitconfig' file must have rules to account for any and all Gerrit URLs that may be used/fed to
the tool.

=back

=head1 EXAMPLES

=over

=item 1.

Derivative

=over

product_build.pl
    -build_flavor     signed_cid
    -build_type       derivative
    -compile_target   nash_retail
    -manifest_branch  mp
    -manifest_url     ssh://gerrit.mot.com/home/repo/dev/platform/android/platform/manifest/o
    -tag_info_prefix  PPX29-Nash

=back

=item 2.

Build promotion

=over

product_build.pl
    -build_number_to_promote 32
    -build_type              promote_continuous_to_daily
    -compile_target          nash_retail
    -continuous_job_name     PPX29_nash-retail_userdebug_mp_r-8998_test-keys_continuous
    -manifest_branch         mp
    -manifest_file           r-8998.xml
    -manifest_url            ssh://gerrit.mot.com/home/repo/dev/platform/android/platform/manifest/o
    -promote_based_on        specific_continuous_build_number
    -tag_info_prefix         PPX29-Nash

=back

=item 3.

Example continuous with Gerrits to cherry-pick:

=over

product_build.pl
    -build_flavor            userdebug
    -build_type              continuous
    -compile_target          nash_retail
    -gerrit                  123456
    -gerrit                  123452,2
    -gerrit                  123455,6
    -manifest_branch         mp
    -manifest_file           r-8998.xml
    -manifest_url            ssh://gerrit.mot.com/home/repo/dev/platform/android/platform/manifest/o
    -tag_info_prefix         PPX29-Nash

=back

=back

=head1 PORTABILITY

=over

=item 1.

Must be run on Linux.

=item 2.

Dependent on:
 use CommonUtil;
 use Constants;
 use EnvironmentSetup;
 use Logging;
 use ProductBuild::ProductBuild;

=back

=head1 BUGS AND LIMITATIONS

=over

=item 1.

See the PORTABILITY section above

=back

=cut

####################################################################################################
# END MAIN DOCUMENTATION BLOCK
####################################################################################################

####################################################################################################
# PRAGMAS
####################################################################################################
#
# Modules to use
#
use strict;
use warnings;
use File::Touch;
use Getopt::Long;

# Include path for local modules
use FindBin;
use lib ($FindBin::RealBin);

# Local modules
use CommonUtil;
use Constants;
use EnvironmentSetup;
use Logging;
use ProductBuild::ProductBuild;


####################################################################################################
# CONSTANTS
####################################################################################################
use constant TEMP_FILE_FOR_UPDATED_MODIFY_TIME_IN_WORKSPACE =>
    '.temp_file_for_assuring_an_updated_modify_time_in_workspace';


####################################################################################################
# GLOBAL VARIABLES
####################################################################################################
my %opt = ();

$ENV{PRINT_PREFIX_FOR_SCM_TOOLS} = 'SCM-PB: ';


####################################################################################################
# MAIN BLOCK
####################################################################################################
eval {
    get_opt();
    main_proc();
};
really_die($@)  if ($@);

exit(PASS);


####################################################################################################
# FUNCTIONS
####################################################################################################
#---------------------------------------------------------------------------------------------------
#  NAME: get_opt
#
#  DESCRIPTION:
#      Processes the command line switches and checks for correct syntax.
#
#  INPUTS:
#      none
#
#  RETURN VALUE:
#      none
#
#  SIDE EFFECTS and IMPORTANT NOTES:
#      * Global hash %opt may be updated.
#      * Dies if syntax is incorrect.
#
#---------------------------------------------------------------------------------------------------
sub get_opt
{
    my @options = (
                   'build_flavor=s',
                   'build_number_to_promote=i',
                   'build_type=s',
                   'clean_workspace_upon_success',
                   'compile_target=s',
                   'continuous_job_name=s',
                   'debug',
                   'gerrit=s@',
                   'hab_cid=s',
                   'manifest_branch=s',
                   'manifest_file=s',
                   'manifest_group=s',
                   'manifest_url=s',
                   'no_artifactory_upload',
                   'no_bota',
                   'no_bota_partition_check',
                   'no_build_id_check',
                   'no_build_ids_update',
                   'no_duplicate_file_check',
                   'no_manifest_branch_check',
                   'no_nosync',
                   'no_oem',
                   'no_os_check',
                   'no_sync_sw',
                   'no_truncated_incremental_failure',
                   'no_update_jira',
                   'no_workspace_clean_upon_success',
                   'oem_to_build|default_oem=s',
                   'oem_to_not_build=s',
                   'oem_to_package=s',
                   'passed_in_tag_file=s',
                   'product_form=s',
                   'product_group=s',   # Deprecated
                   'promote_based_on=s',
                   'promoter_id=s',
                   'promotion_build_number=i',
                   'promotion_job_name=s',
                   'replace_tag',
                   'repo_url=s',
                   'sanity_test',
                   'tag_info_prefix=s',
                   'test_db',
                  );
    GetOptions(\%opt, @options) ||
        do {
            warn "Error: Failed to parse the command line switches\n";
            usage(0);
            exit(FAIL);
        };

    $opt{product_form} ||= 'phone';

    if ($opt{hab_cid} and $opt{build_flavor} !~ /signed_cid/)
    {
        log_a_line("Removed setting for '-hab_cid' as flavor in incompatible.");
        delete($opt{hab_cid});
    }

    my @errors = ();
    push(@errors, "The '-build_type' switch is required")  if (!$opt{build_type});
    push(@errors, "The '-sanity_test' switch is only valid with '-test_db' and '-debug'")
        if ($opt{sanity_test} and !$opt{debug} and !$opt{test_db});
    push(@errors, "The '-compile_target' and '-product_group' switches are mutually exclusive")
        if ($opt{compile_target} and $opt{product_group});
    push(@errors, "The '-hab_cid' switch can only be used with the '-compile_target' switch")
        if (exists $opt{hab_cid} and !$opt{compile_target});
    push(@errors, "The '-product_form' switch value is invalid")
        if (grep(/^\Q$opt{product_form}\E$/, qw(phone app mod watch)) <= 0);
    push(@errors, "The '-passed_in_tag_file' value ($opt{passed_in_tag_file}) is not a file")
        if ($opt{passed_in_tag_file} and not -f $opt{passed_in_tag_file});
    if ($opt{gerrit})
    {
        if (ref($opt{gerrit}) eq 'ARRAY')
        {
            my %counts = ();
            foreach my $val (@{$opt{gerrit}})
            {
                if ($val !~ /^(\d+)(?:,\d+)?/)
                {
                    push(@errors, "The '-gerrit' value ($val) is not in <Gerrit>[,<patch>] format");
                    next;
                }
                $counts{$1}++;
            }

            push(@errors, "There are repeated values for '-gerrit'")
                if (grep({$_ > 1} values(%counts)) > 0);
        }
        else
        {
            push(@errors, "The '-gerrit' value is not supported")
        }
    }

    push(@errors, "There are 'extra' parameters passed to the tool, check the command line")
        if (scalar(@ARGV) > 0);

    if (scalar(@errors) > 0)
    {
        my $message =
            "Error: The following reasons made this tool exit:\n- " . join("\n- ", @errors);
        die("$message\n");
    }

    command_switch_summary(\%opt, \@options);
    log_a_line("PID is $$\n");

    # Turn on '-test_db' and '-debug' if one of them is used
    $opt{test_db} = $opt{debug} = TRUE  if ($opt{test_db} or $opt{debug});
    set_debug_mode($opt{debug});
} # End get_opt


#---------------------------------------------------------------------------------------------------
#  NAME: main_proc
#
#  DESCRIPTION:
#      Main workhorse
#
#  INPUTS:
#      none
#
#  RETURN VALUE:
#      none
#
#  SIDE EFFECTS and IMPORTANT NOTES:
#      * none
#
#---------------------------------------------------------------------------------------------------
sub main_proc
{
    # Touch a temporary file to make sure the current directory's modify time is updated
    unlink(TEMP_FILE_FOR_UPDATED_MODIFY_TIME_IN_WORKSPACE);
    touch(TEMP_FILE_FOR_UPDATED_MODIFY_TIME_IN_WORKSPACE);
    unlink(TEMP_FILE_FOR_UPDATED_MODIFY_TIME_IN_WORKSPACE);

    my $build_obj =
        ProductBuild::ProductBuild->
              create(
                     build_flavor                     => $opt{build_flavor},
                     build_number_to_promote          => $opt{build_number_to_promote},
                     build_type                       => $opt{build_type},
                     clean_workspace_upon_success     => $opt{clean_workspace_upon_success},
                     compile_target                   => $opt{compile_target},
                     continuous_job_name              => $opt{continuous_job_name},
                     gerrit                           => $opt{gerrit},
                     hab_cid                          => $opt{hab_cid},
                     manifest_branch                  => $opt{manifest_branch},
                     manifest_file                    => $opt{manifest_file},
                     manifest_group                   => $opt{manifest_group},
                     manifest_url                     => $opt{manifest_url},
                     no_artifactory_upload            => $opt{no_artifactory_upload},
                     no_bota                          => $opt{no_bota},
                     no_bota_partition_check          => $opt{no_bota_partition_check},
                     no_build_id_check                => $opt{no_build_id_check},
                     no_build_ids_update              => $opt{no_build_ids_update},
                     no_manifest_branch_check         => $opt{no_manifest_branch_check},
                     no_nosync                        => $opt{no_nosync},
                     no_oem                           => $opt{no_oem},
                     no_os_check                      => $opt{no_os_check},
                     no_sync_sw                       => $opt{no_sync_sw},
                     no_truncated_incremental_failure => $opt{no_truncated_incremental_failure},
                     no_update_jira                   => $opt{no_update_jira},
                     no_workspace_clean_upon_success  => $opt{no_workspace_clean_upon_success},
                     oem_to_build                     => $opt{oem_to_build},
                     oem_to_not_build                 => $opt{oem_to_not_build},
                     oem_to_package                   => $opt{oem_to_package},
                     passed_in_tag_file               => $opt{passed_in_tag_file},
                     product_form                     => $opt{product_form},
                     product_group                    => $opt{product_group},
                     promote_based_on                 => $opt{promote_based_on},
                     promoter_id                      => $opt{promoter_id},
                     promotion_build_number           => $opt{promotion_build_number},
                     promotion_job_name               => $opt{promotion_job_name},
                     replace_tag                      => $opt{replace_tag},
                     repo_url                         => $opt{repo_url},
                     sanity_test                      => $opt{sanity_test},
                     tag_info_prefix                  => $opt{tag_info_prefix},
                    );

    # Setup the timeout for those builds that need it
    my $timeout     = $build_obj->get_timeout();
    my $exit_status = FAIL;
    if (defined $timeout and $timeout)
    {
        eval {
            local $SIG{ALRM} = sub { die "Error: Timed out after $timeout minutes!!\n"; };
            alarm(int($timeout * 60));
            $build_obj->process_product_release();
            alarm(0);
        };
        die($@)  if ($@);
    }
    else
    {
        $build_obj->process_product_release();
        $build_obj->final_thoughts();
    }
} # End main_proc
