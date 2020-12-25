#!/usr/bin/python
import sys
import os
import subprocess
import logging
import logging.handlers
import csv
import time
import re

import argparse
import repo_cmd
import smart_push as smart_push_p
from smart_push import *

from git_cmd import Git
from git_errors import GitCommandError
from git import *

SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))

GOOGLE_SSW_MERGE_REPORT_URL="https://docs.google.com/spreadsheets/d/18K9rTqXGbfjch8c1G3xnmdBygBxjQ6G1YB8doTlZps0/edit#gid=0"

MERGE_STATUS_REPORT_FIELDNAMES=['Component', 'Status', 'Conflict?', 'Comments', 'Gerrit Review', 'MOT changes?', 'Rebased HEAD commit']
MERGE_STATUS_REPORT_FIELDNAMES.append('Mainline branch')
MERGE_STATUS_REPORT_FIELDNAMES.append('Pushed mainline commit')
REBASE_RESULT_LIST = [MERGE_STATUS_REPORT_FIELDNAMES]

MERGE_RECORD_OFFSET_COMPONENT = 0
MERGE_RECORD_OFFSET_STATUS = 1
MERGE_RECORD_OFFSET_CONFLICT = 2
MERGE_RECORD_OFFSET_COMMENT = 3
MERGE_RECORD_OFFSET_GERRIT_INFO = 4
MERGE_RECORD_OFFSET_MOT_CHAGNED = 5
MERGE_RECORD_OFFSET_HEAD = 6
MERGE_RECORD_OFFSET_MAINLINE_BRANCH = 7
MERGE_RECORD_OFFSET_MAINLINE_HEAD = 8
MERGE_RECORD_END = 9
MERGE_RECORD_COLUMN = MERGE_RECORD_END

GROUP_REBASE='ssw_rebase'


class ReportWriter(object):
    def __init__(self, report_name):
        self.report_name = report_name

    def Write(self, report_name, merge_status_report_name, data):
        pass

class ReportWriterGdocs(ReportWriter):
    def __init__(self,report_name):
        super(ReportWriterGdocs, self).__init__(report_name)

        # only import if needed.
        from mot_gspread import GoogSpreadsheet
        self.gspread = GoogSpreadsheet(GOOGLE_SSW_MERGE_REPORT_URL)

    def Write(self, data):
        self.gspread.upload(self.report_name, data)

class ReportWriterCsv(ReportWriter):
    def __init__(self,report_name):
        super(ReportWriterCsv, self).__init__(report_name)
        # For the filename add .csv if no suffix is specified
        filename, filext = os.path.splitext(self.report_name)
        if filext == '':
            filext = 'csv'
        self.filename = "%s.%s" % (filename, filext)

    def Write(self, data):

        with open(self.filename, 'wb') as csvfile:

            writer = csv.writer(csvfile, delimiter='|', quoting=csv.QUOTE_MINIMAL)
            for row in data:
                writer.writerow(row)

        #Write a list of the write object(Merge Result)
        print "Please check the report %s...." % self.filename




class CommonCommitNotMoto(Exception):
     __str__ = "The common commit is not moto commit, please rebase manually"

class State:
    def __init__(self, **kwds):
        self.__dict__.update(kwds)

def com_ancestor_rebase(u_branch, x_branch, x_rebase_branch, project_path, default_remote):
    """The function is used for rebasing u_branch onto , in the case of 
       u_branch and x_branch have the common ancestor and x_branch has been rebased onto current tag and pushed into x_rebase_branch """

    mygit = Repo(project_path, odbt=GitCmdObjectDB)
    try:
        #Get the common ancestor commit of two branches
        com_anc_commit = mygit.git.merge_base(x_branch, u_branch)
        logging.info("The common ancestor is [ %s %s ]" %(mygit.commit(com_anc_commit).hexsha[:8], mygit.commit(com_anc_commit).summary))
    except Exception as e:
        logging.error("Failed to locate the common ancestor")
        logging.error("%s",e)
    #Find the common ancestor cherried pick in rebased branch
    try:
        com_anc_commit_rebase = smart_push_p.find_last_rebased_commit(mygit, default_remote, com_anc_commit, x_rebase_branch)
        assert com_anc_commit != str(com_anc_commit_rebase)
        logging.info("The common ancestor on rebase branch is [ %s %s ]" %(com_anc_commit_rebase.hexsha[:8], com_anc_commit_rebase.summary))
    except Exception as e:
        logging.error("Can't find the common ancestor commit in %s", x_rebase_branch)
        raise e
    out = mygit.git.rebase('--onto', str(com_anc_commit_rebase), com_anc_commit, u_branch)
    logging.info("git rebase --onto %s %s %s" %(str(com_anc_commit_rebase), com_anc_commit, u_branch))
    logging.info(out)
        
    
def xtag_rebase(args, project_path, default_remote):
    """The function is used for ultra rebase.
       It looks for common ancestor in mkk-x, locates the common ancestor in mkk-x-rebase where rebase droid commits on top"""

    mygit = Repo(project_path, odbt=GitCmdObjectDB)
    last_aosp_tag= args.last_release
    current_aosp_tag = args.current_release
    x_daily_tag = args.rebase_xtag
    x_current_tag = args.rebase_current_xtag
    d_daily_tag = "HEAD"
    #remote_x_rebase_br = "%s/mkk-x-rebase" %(default_remote)

    #If the mkk-x daily tag we rebased matches mkk-d, we use mkk-x-rebase branch instead
    if smart_push_p.is_match(mygit, x_daily_tag, d_daily_tag):
        logging.debug("%s matches %s" %(x_daily_tag, d_daily_tag))
        out = mygit.git.checkout(x_current_tag)
        logging.info("git chekcout %s" %(x_current_tag))
        logging.info(out)
    else:
        if smart_push_p.is_ancestor(mygit, x_daily_tag, d_daily_tag):
            logging.debug("%s is the ancestor of %s" %(x_daily_tag, d_daily_tag))
            out = mygit.git.rebase('--onto', x_current_tag, x_daily_tag, d_daily_tag)
            logging.info("git rebase --onto %s %s %s" %(x_current_tag, x_daily_tag, d_daily_tag))
            logging.info(out)
        else:
            logging.debug("Start common ancestor rebase")
            com_ancestor_rebase(d_daily_tag, x_daily_tag, x_current_tag, project_path, default_remote)

# Repo.Walk() callback to rebase
def visit_rebase_callback(project, state):
    gitpath = project.get('path', project.get('name'))
    gitfullpath = os.path.join(work_path, gitpath)
    logging.debug("Rebasing project %s...",gitpath)
    gitfullpath = os.path.join(work_path, gitpath)
    gitrevision = "HEAD"
    gitremote = project.get('remote', 'origin')
    mygit = Repo(gitfullpath, odbt=GitCmdObjectDB)
    git_last_tag= state.args.last_release
    git_current_tag = state.args.current_release
    rebase_result_record = ["" for i in range(MERGE_RECORD_COLUMN) ]

    try:
        #Evaluate the curreent tag and the current HEAD to see if need rebase
        brs_eval = compare_branch(mygit, git_current_tag, gitrevision)
        #The current tag is not the ancestor of HEAD firstly, and then not match HEAD
        if brs_eval != BranchEvals.isMatch and brs_eval != BranchEvals.isAncestor:
            # Only take care the gits have changes between two tags
            rebase_result_record[MERGE_RECORD_OFFSET_COMPONENT] = gitpath
            rebase_result_record[MERGE_RECORD_OFFSET_MAINLINE_BRANCH] = project['revision']
            rebase_result_record[MERGE_RECORD_OFFSET_COMMENT] = ""
            rebase_result_record[MERGE_RECORD_OFFSET_GERRIT_INFO] = ""
            #Store the HEAD commit we start rebased
            try:
                git_rebase_commit = mygit.git.log('-1', '--oneline', gitrevision)
            except Exception as git_cmd_e:
                logging.error("%s", git_cmd_e)
            rebase_result_record[MERGE_RECORD_OFFSET_HEAD] = git_rebase_commit
            try:
                has_mot_change = compare_branch(mygit, git_last_tag, gitrevision)
                #Current HEAD is not match the last qcom base, there is moto change on it
                if has_mot_change != BranchEvals.isMatch:
                    #If there is moto changes, we rebase
                    rebase_result_record[MERGE_RECORD_OFFSET_MOT_CHAGNED] = "YES"
                    try:
                        if state.args.rebase_xtag:
                            xtag_rebase(state.args, gitfullpath, gitremote)
                        else:
                            out = mygit.git.rebase('--onto', git_current_tag, git_last_tag, gitrevision)
                            logging.info(out)
                        rebase_result_record[MERGE_RECORD_OFFSET_STATUS] = "rebased"
                        rebase_result_record[MERGE_RECORD_OFFSET_CONFLICT] = "no"
                    except Exception as rebase_e:
                        rebase_result_record[MERGE_RECORD_OFFSET_STATUS] = "Fix me, please"
                        rebase_result_record[MERGE_RECORD_OFFSET_CONFLICT] = "yes"
                        logging.debug("Rebase E: %s", rebase_e)
                else:
                    #If there is no moto changes, we checkout directly
                    mygit.git.checkout(current_release_tag)
                    rebase_result_record[MERGE_RECORD_OFFSET_STATUS] = "fast-forward"
                    rebase_result_record[MERGE_RECORD_OFFSET_MOT_CHAGNED] = "NO"
                    rebase_result_record[MERGE_RECORD_OFFSET_CONFLICT] = ""
            except Exception as moto_delta_e:
                logging.error("Failed to verify if there is moto changes, %s" % (moto_delta_e))
            logging.debug("rebase_result_record:Status: %s MOT changes: %s, Conflicts: %s" %(rebase_result_record[MERGE_RECORD_OFFSET_STATUS], rebase_result_record[MERGE_RECORD_OFFSET_MOT_CHAGNED], rebase_result_record[MERGE_RECORD_OFFSET_CONFLICT]))
            REBASE_RESULT_LIST.append(rebase_result_record)
    except Exception as e:
        logging.debug("SKIP %s ***, NOT from upstream, %s" %(gitfullpath, e))

# We don't push repo whose revision is tag
def is_tag_revision(git_revision):
    tagstring = re.compile('refs/tags/.')
    return re.match(tagstring, git_revision)

# Wildcard matches the skip_list
def is_in_skip_list(git_path_project, skip_list):
    for path_string in skip_list:
        if re.match(re.compile(path_string), git_path_project):
            return True

# Repo.Walk() callback to push
def visit_push_callback(project, state):
    gitpath = project.get('path', project.get('name'))
    logging.debug("project %s",gitpath)
    gitfullpath = os.path.join(work_path, gitpath)
    gitrevision = project.get('revision')
    if is_tag_revision(gitrevision):
        logging.info("%s Resetting to target tag", gitpath)
        git = Git(gitfullpath)
        out = git.reset('--hard', gitrevision)
        logging.debug(out)
        state.reset_list.append(gitpath)
        return

    archive_branch = os.path.join("archive",gitrevision)
    gitremote = project.get('remote', 'origin')

    last_rebased_commit = state.report_reader.get_last_rebased_commit(gitpath)
    logging.debug('gitpath: %s revision: %s last_rebased: %s, archiver: %s', gitpath, gitrevision, last_rebased_commit, archive_branch)

    try:
        pushstat = smart_push(gitfullpath, gitremote, 'HEAD', gitrevision, archive_branch=archive_branch, last_rebased_commit=last_rebased_commit, force=True, cherry_pick=True, dry_run=state.args.dry_run)
        logging.debug("%s returned pushstat %s %s %s", gitpath, pushstat.pushed, pushstat.forced, pushstat.out_of_date)
        if pushstat.pushed:
            state.push_list.append(gitpath)
        if pushstat.forced:
            state.force_push_list.append(gitpath)
        if pushstat.out_of_date:
            assert(not pushstat.pushed)
            assert(not pushstat.forced)
            logging.info("%s is out-of-date. Resetting to target branch.", gitpath)
            git = Git(gitfullpath)
            out = git.reset('--hard', "%s/%s" % (gitremote, gitrevision))
            logging.debug(out)
            state.reset_list.append(gitpath)

    except Exception as e:
        logging.exception("Error while processing %s.", gitpath)
        state.errors += 1
        state.error_list.append(gitpath)

class RebaseReportReader(object):
    def __init__(self, filename):
        report_file_reader = csv.DictReader(open(filename, 'rb'), fieldnames=None,
                                         restkey=None, restval=None, dialect='excel')
        logging.debug("rebase report %s",filename)
        self.records = {}
        for record in report_file_reader:
            logging.debug("%s", record)
            self.records[record['Component']] = record

    def get_record(self, component):
        return self.records.get(component)

    def get_last_rebased_commit(self, component):
        commit = None
        record = self.get_record(component)
        if record:
            commit_oneline = record['Rebased mainline commit']
            if commit_oneline:
                commit = commit_oneline.split()[0]
        return commit

def rebase_func(path, last_tag, current_tag, args):

    # Create a CSV or GDOCS writer
    if args.file_report:
        report_writer = ReportWriterCsv(args.rebase_report)
    else:
        report_writer = ReportWriterGdocs(args.rebase_report)

    repo = repo_cmd.RepoGroup(path, args.rebase_group)
    repo_top = repo.get_top()
    if repo_top is None:
        sys.stderr.write("Failed.  Cannot find .repo dir.  Did you indicate the correct workspace?\n")
        sys.exit(2)

    state = WalkState(args, None)
    try:
        repo.walk(visit_rebase_callback, state)
    except Exception as e:
        logging.error("Group %s does not existed in %s" %(args.rebase_group, path))
        raise e

    report_writer.Write(REBASE_RESULT_LIST)

class WalkState(object):
    def __init__(self, args, report_reader):
        self.args = args
        self.report_reader = report_reader

        self.errors = 0
        self.error_list = []
        self.push_list = []
        self.force_push_list = []
        self.reset_list = []

def push_func(path, last_tag, current_tag, args):
    repo = repo_cmd.RepoGroup(path, args.rebase_group)
    repo_top = repo.get_top()
    if repo_top is None:
        sys.stderr.write("Failed.  Cannot find .repo dir.  Did you indicate the correct workspace?\n")
        sys.exit(2)

    if not os.path.isfile(merge_status_report_name):
        sys.stderr.write("Failed.  Cannot locate rebase report(%s) to push\n" % merge_status_report_name)
        sys.exit(2)

    report_reader = RebaseReportReader(merge_status_report_name)
    state = WalkState(args, report_reader)
    logging.debug("starting walk...")
    try:
        repo.walk(visit_push_callback, state)
    except Exception as e:
        logging.error("Group %s does not existed in %s" %(args.rebase_group, path))
        raise e

    if len(state.reset_list) > 0:
        logging.info("=== Reset to Target Branch ===")
        for comp in state.reset_list:
            logging.info("%s (reset)",comp)
 
    if len(state.push_list) - len(state.force_push_list) > 0:
        logging.info("=== Pushed ===")
        for comp in state.push_list:
            if comp not in state.force_push_list:
                logging.info(comp)

    if len(state.force_push_list) > 0:
        logging.info("=== Force Pushed ===")
        for comp in state.force_push_list:
            logging.info("%s (force pushed)",comp)

    if state.errors > 0:
        logging.error("=== Errors ===")
        for comp in state.error_list:
            logging.error(comp)

def rebase(args):
    log_msg = "Start to rebase onto %s from %s....." % (current_release_tag, last_release_tag)
    logging.info(log_msg)
    rebase_func(work_path, last_release_tag, current_release_tag, args)

def push(args):
    log_msg = "Start to push rebase on %s....." % current_release_tag
    logging.info(log_msg)
    push_func(work_path, last_release_tag, current_release_tag, args)

def redo(args):
    log_msg = "Start to redo rebase onto %s from %s....." % (current_release_tag, last_release_tag)
    logging.info(log_msg)
    redo_rebase_func(work_path, last_release_tag, current_release_tag. args)

def setup_logger(filename='log.txt'):
    # Check if log exists and should therefore be rolled
    needRoll = False
    if os.path.isfile(filename):
            needRoll = True

    logger = logging.getLogger('')
    logger.setLevel(logging.DEBUG)
    # Add the log message handler to the logger
    handler = logging.handlers.RotatingFileHandler(filename, backupCount=20)
    formatter = logging.Formatter('%(levelname)-4s %(message)s')
    handler.setFormatter(formatter)
    handler.setLevel(logging.DEBUG)
    logger.addHandler(handler)
    if needRoll:
        handler.doRollover()

    logging.debug('Log started %s', time.asctime())
    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    formatter = logging.Formatter('%(levelname)-4s %(message)s')
    console.setFormatter(formatter)
    logging.getLogger('').addHandler(console)

#Main
setup_logger()
logging.debug('start')
parser = argparse.ArgumentParser()
subparsers = parser.add_subparsers()

subparser = subparsers.add_parser('rebase', help='Rebase moto commits onto new release.')
subparser.add_argument('-l', '--last-release', help='Last release rebased', required=True)
subparser.add_argument('-c', '--current-release', help='Current release going to rebase', required=True)
subparser.add_argument('-w', '--workspace', help='Specify the workspace path', required=True)
subparser.add_argument('-r', '--rebase-report', help='Report file about rebase', default='Merge_status')
subparser.add_argument('-f', '--file-report', action='store_true', help='Create a local report file instead of uploading to google docs', default=False)
subparser.add_argument('-g', '--rebase-group', help='group attribute the project needs to do rebase', default=GROUP_REBASE)
subparser.add_argument('-x', '--rebase-xtag', help='For ultra rebase, old x daily tag, for looking common ancestor', default='')
subparser.add_argument('-t', '--rebase-current-xtag', help='For ultra rebase, current x daily tag, for rebase reference', default='')
subparser.set_defaults(func=rebase)

subparser = subparsers.add_parser('push', help='Mainline the rebased contents')
subparser.add_argument('-l', '--last-release', help='Last release rebased', required=True)
subparser.add_argument('-c', '--current-release', help='Current release going to rebase', required=True)
subparser.add_argument('-w', '--workspace', help='Specify the workspace path', required=True)
subparser.add_argument('-r', '--rebase-report', help='Report file about rebase', default='Merge_status')
subparser.add_argument('-d', '--dry-run', help='Do not push to server', action='store_true')
subparser.add_argument('-g', '--rebase-group', help='group attribute the project needs to do rebase', default=GROUP_REBASE)
subparser.add_argument('-x', '--rebase-xtag', help='Report file about rebase', default='')
subparser.set_defaults(func=push)


subparser = subparsers.add_parser('redo', help='Redo the rebase moto commits onto new release.')
subparser.add_argument('-l', '--last-release', help='Last release rebased', required=True)
subparser.add_argument('-c', '--current-release', help='Current release going to rebase', required=True)
subparser.add_argument('-w', '--workspace', help='Specify the workspace path', required=True)
subparser.add_argument('-r', '--rebase-report', help='Report file about rebase', default='Merge_status')
subparser.add_argument('-g', '--rebase-group', help='group attribute the project needs to do rebase', default=GROUP_REBASE)
subparser.set_defaults(func=redo)

#Parse the args from command line
args = parser.parse_args()

work_path= args.workspace
last_release_tag= args.last_release
current_release_tag = args.current_release
merge_status_report_name =args.rebase_report

args.func(args)
