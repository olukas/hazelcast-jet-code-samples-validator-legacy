#!/bin/bash

export SCRIPT_WORKSPACE=$1
export JET_REPO=$2

export OUTPUT_LOG_FILE=${SCRIPT_WORKSPACE}/output.log

function check_text_in_log {
    CHECKED_INITIAL_LOG=$1
    echo "Checking log for '${CHECKED_INITIAL_LOG}'"
    INITIAL_LOG_COUNT=$(grep "${CHECKED_INITIAL_LOG}" ${OUTPUT_LOG_FILE} | wc -l)
    if [ ${INITIAL_LOG_COUNT} -lt 1 ]; then   
        echo "Log '${CHECKED_INITIAL_LOG}' has not been found in output log.";
        exit 1
    fi
}

cd ${JET_REPO}
mvn clean install -U -B -Dmaven.test.failure.ignore=true -DskipTests

###########################
### execute code sample ###
###########################
cd ${JET_REPO}/examples/imdg-connectors
mvn "-Dexec.args=-classpath %classpath com.hazelcast.jet.examples.imdg.RemoteListSourceAndSink" -Dexec.executable=java org.codehaus.mojo:exec-maven-plugin:1.6.0:exec | tee ${OUTPUT_LOG_FILE}

#################################
### verify code sample output ###
#################################
check_text_in_log "Creating and populating remote Hazelcast instance..."
check_text_in_log "Local list-1 contents: \[0, 1, 2, 3, 4, 5, 6, 7, 8, 9\]"
check_text_in_log "Remote list-2 contents: \[0, 1, 2, 3, 4, 5, 6, 7, 8, 9\]"

