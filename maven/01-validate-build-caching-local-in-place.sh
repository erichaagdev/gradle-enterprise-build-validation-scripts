#!/usr/bin/env bash
#
# Runs Experiment 02 - Validate Build Caching - Local - In Place 
#
# Invoke this script with --help to get a description of the command line arguments
#
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR="$(cd "$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# Experiment-speicifc constants
EXP_NAME="Validate Build Caching - Local - In Place"
EXP_NO="02"
EXP_SCAN_TAG=exp1
RUN_ID=$(uuidgen)
EXPERIMENT_DIR="${SCRIPT_DIR}/data/${SCRIPT_NAME%.*}"
SCAN_FILE="${EXPERIMENT_DIR}/scans.csv"

build_cache_dir="${EXPERIMENT_DIR}/build-cache"

# These will be set by the collect functions (see lib/input.sh)
project_url=""
project_name=""
project_branch=""
task=""

# Include and parse the command line arguments
# shellcheck source=experiments/lib/maven/01/parsing.sh
source "${LIB_DIR}/maven/01/parsing.sh" || { echo "Couldn't find '${LIB_DIR}/maven/01/parsing.sh' parsing library."; exit 1; }

# shellcheck source=experiments/lib/libs.sh
source "${LIB_DIR}/libs.sh" || { echo "Couldn't find '${LIB_DIR}/libs.sh'"; exit 1; }

main() {
  if [ "$_arg_wizard" == "on" ]; then
    wizard_execute
  else
    execute
  fi
}

execute() {
 print_experiment_name
 print_scan_tags

 make_experiment_dir

 load_settings
 collect_project_details
 collect_maven_goals

 make_maven_extensions
 clone_project ""
 make_local_cache_dir
 execute_first_build
 execute_second_build

 save_settings
 print_summary
}

wizard_execute() {
 print_introduction

 explain_scan_tags

 explain_experiment_dir
 make_experiment_dir

 load_settings

 collect_project_details

 explain_collect_maven_goals
 collect_maven_goals

 explain_make_maven_extensions
 make_maven_extensions

 explain_clone_project
 clone_project ""

 explain_local_cache_dir
 make_local_cache_dir

 explain_first_build
 execute_first_build

 explain_second_build
 execute_second_build

 save_settings
 print_summary
 explain_summary
}

execute_first_build() {
  info "Running first build."
  execute_build
}

execute_second_build() {
  info "Running second build."
  execute_build
}

execute_build() {
  info 
  info "./mvnw -Dscan.tag.${EXP_SCAN_TAG} -Dscan.tag.${RUN_ID} clean ${task}"

  #shellcheck disable=SC2086  # we actually want ${task} to expand because it may have more than one maven goal
  invoke_maven \
     -Dgradle.cache.local.enabled=true \
     -Dgradle.cache.remote.enabled=false \
     -Dgradle.cache.local.directory="${build_cache_dir}" \
     clean ${task}
}

print_summary() {
 read_scan_info

 local branch
 branch=$(git branch)
 if [ -n "$_arg_branch" ]; then
   branch=${_arg_branch}
 fi

 local fmt="%-25s%-10s"
 info
 info "SUMMARY"
 info "----------------------------"
 infof "$fmt" "Project:" "${project_name}"
 infof "$fmt" "Branch:" "${branch}"
 infof "$fmt" "Gradle task(s):" "${task}"
 infof "$fmt" "Experiment dir:" "${EXPERIMENT_DIR}"
 infof "$fmt" "Experiment tag:" "${EXP_SCAN_TAG}"
 infof "$fmt" "Experiment run ID:" "${RUN_ID}"
 print_build_scans
 print_starting_points
}

print_build_scans() {
 local fmt="%-25s%-10s"
 infof "$fmt" "First build scan:" "${scan_url[0]}"
 infof "$fmt" "Second build scan:" "${scan_url[1]}"
}

print_starting_points() {
 local fmt="%-25s%-10s"
 info 
 info "SUGGESTED STARTING POINTS"
 info "----------------------------"
 infof "$fmt" "Scan comparision:" "${base_url[0]}/c/${scan_id[0]}/${scan_id[1]}/task-inputs?cacheability=cacheable"
 infof "$fmt" "Cache performance:" "${base_url[0]}/s/${scan_id[1]}/performance/build-cache"
 infof "$fmt" "Executed cachable tasks:" "${base_url[0]}/s/${scan_id[1]}/timeline?cacheability=cacheable&outcome=successful&sort=longest"
 infof "$fmt" "Uncachable tasks:" "${base_url[0]}/s/${scan_id[1]}/timeline?cacheability=any_non-cacheable&outcome=successful&sort=longest"
 info
}

print_introduction() {
  local text
  IFS='' read -r -d '' text <<EOF
${CYAN}                              ;x0K0d,
${CYAN}                            kXOxx0XXO,
${CYAN}              ....                '0XXc
${CYAN}       .;lx0XXXXXXXKOxl;.          oXXK
${CYAN}      xXXXXXXXXXXXXXXXXXX0d:.     ,KXX0
${CYAN}     .,KXXXXXXXXXXXXXXXXXO0XXKOxkKXXXX:
${CYAN}   lKX:'0XXXXXKo,dXXXXXXO,,XXXXXXXXXK;   Gradle Enterprise Trial
${CYAN} ,0XXXXo.oOkl;;oKXXXXXXXXXXXXXXXXXKo.
${CYAN}:XXXXXXXKdllxKXXXXXXXXXXXXXXXXXX0c.
${CYAN}'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXk'
${CYAN}xXXXXXXXXXXXXXXXXXXXXXXXXXXXXXc          Experiment ${EXP_NO}:
${CYAN}KXXXXXXXXXXXXXXXXXXXXXXXXXXXXl           ${EXP_NAME}
${CYAN}XXXXXXklclkXXXXXXXklclxKXXXXK
${CYAN}OXXXk.     .OXXX0'     .xXXXx
${CYAN}oKKK'       ,KKK:       .KKKo

This is the second of several experiments that are part of your
Gradle Enterprise Trial. Each experiment will help you to make concrete
improvements to your existing build. The experiments will also help you to
build the data necessary to recommend Gradle Enerprise to your organization.

This script (and the other experiment scripts) will run some of the
experiment steps for you, but we'll walk you through each step so that you
know exactly what we are doing, and why.

In this experiment, we will be checking your build to see how well it takes
advantage of the local build cache. When the build cache is enabled, the
Gradle Enterprise Maven extension saves the output from goals so that the
same output can be reused if the goal is executed again with the same
inputs.

To test out the build cache, we'll run two builds (with build caching
enabled). Both builds will invoke clean and run the same tasks. We will not
make any changes between each build run.

If the build is taking advantage of the local build cache, then very few (if
any) tasks should actually execute on the seond build (all of the task
output should be used from the local cache).

The Gradle Solutions engineer will then work with you to figure out why some
(if any) tasks ran on the second build, and how to optimize them to take
advantage of the build cache.

${USER_ACTION_COLOR}Press enter when you're ready to get started.
EOF

  print_in_box "${text}"
  wait_for_enter
}

explain_local_cache_dir() {
  local text
  IFS='' read -r -d '' text <<EOF
We are going to create a new empty local build cache dir (and configure
Gradle to use it instead of the default local cache dir). This way, the
first build won't find anything in the cache and all tasks will run. 

This is mportant beause we want to make sure tasks that are cachable do in
fact produce output that is stored in the cache.

Specifically, we are going to create and use this directory for the local
build cache (we'll delete it if it already exists from a previous run of the
experiment):

$(info "${build_cache_dir}")

${USER_ACTION_COLOR}Press enter to continue.
EOF
  print_in_box "${text}"
  wait_for_enter
}

explain_make_maven_extensions() {
  local text
  IFS='' read -r -d '' text <<EOF

We will use a Maven extension to capture build scan information, which I
will use to provide you with some helpful links at the end. The extension
needs to be built and packaged as a JAR file before it can be used.

You can find the log for the extension build in the experiments directory.

${USER_ACTION_COLOR}Press enter to build the extension.
EOF
  print_in_box "${text}"
  wait_for_enter
}

explain_first_build() {
 local build_command
  build_command="${INFO_COLOR}./gradlew \\
  ${INFO_COLOR}-Dscan.tag.${EXP_SCAN_TAG} \\
  ${INFO_COLOR}-Dscan.tag.${RUN_ID} \\
  ${INFO_COLOR} clean ${task}"

  local text
  IFS='' read -r -d '' text <<EOF
OK! We are ready to run our first build!

For this run, we'll execute 'clean ${task}'. 

We will also add the build scan tags we talked about before.

Effectively, this is what we are going to run:

${build_command}

${USER_ACTION_COLOR}Press enter to run the first build.
EOF
  print_in_box "${text}"
  wait_for_enter
}

explain_second_build() {
  local text
  IFS='' read -r -d '' text <<EOF
Now we are going to run the build again without changing anything.

In a fully optimized build, no tasks would run on this second build because
we already built everything in the first build, and the task outputs should
be in the local build cache. If some tasks do run, they will show up in the
build scan for this second build.

${USER_ACTION_COLOR}Press enter to run the second build.
EOF
  print_in_box "$text"
  wait_for_enter
}

explain_summary() {
  read_scan_info
  local text
  IFS='' read -r -d '' text <<EOF
Now that both builds have completed, there is a lot of valuable data in
Gradle Enterprise to look at. The data can help you find ineffiencies in
your build.

After running the experiment, I will generate a summary table of useful data
and links to help you analyze the experiment results. Most of the data in
the summmary is self-explanatory, but there are a few things are worth
reviewing:

$(print_build_scans)

^^ These are links to the build scans for the builds. A build scan is a
report that provides information and statistics about the build execution.

$(print_starting_points)

^^ These are links to help you get started in your analysis. The first link
is to a comparison of the two build scans. Comparisions show you what was
different between two different builds.

The "Cache performance" link takes you to the build cache performance page
of the 2nd build scan. This page contains various metrics related to the
build cache (such as cache hits and misses).

The "Executed cachable tasks" link shows you which tasks ran again on the
second build, but shouldn't have because they are actually cachable. If any
cachable tasks ran, then one of their inputs changed (even though we didn't
make any changes), or they may not be declaring their inputs correctly.

The last link, "Uncachable tasks", shows you which tasks ran that are not
cachable. It is not always possible, or doesn't make sense the output from
every task. For example, there's no way to cache the "output" of the clean
task because the clean task deletes output rather than creating it.

If you find something to optimize, then you will want to run this expirment
again after you have implemented the optimizations (to validate the
optimizations were effective). You will not need to run this wizard again.
All of your settings have been saved, so all you need to do to run this
experiment again without the wizard is to invoke this script without any
arguments:

$(info "./${SCRIPT_NAME}")

Congrats! You have completed this experiment.
EOF
  print_in_box "${text}"
}

main
