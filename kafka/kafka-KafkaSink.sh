#!/bin/bash

export SCRIPT_WORKSPACE=$1
export JET_REPO=$2

export OUTPUT_LOG_FILE=${SCRIPT_WORKSPACE}/output.log

function check_text_in_log {
    EXPECTED_TEXT=$1
    echo "Checking log for '${EXPECTED_TEXT}'"
    EXPECTED_TEXT_COUNT=$(grep "${EXPECTED_TEXT}" ${OUTPUT_LOG_FILE} | wc -l)
    if [ ${EXPECTED_TEXT_COUNT} -lt 1 ]; then   
        echo "Log '${EXPECTED_TEXT}' has not been found in output log.";
        exit 1
    fi
}

cd ${JET_REPO}
mvn clean install -U -B -Dmaven.test.failure.ignore=true -DskipTests

###########################
### execute code sample ###
###########################
cd ${JET_REPO}/examples/kafka
mvn "-Dexec.args=-classpath %classpath com.hazelcast.jet.examples.kafka.KafkaSink" -Dexec.executable=java org.codehaus.mojo:exec-maven-plugin:1.6.0:exec | tee ${OUTPUT_LOG_FILE}

#################################
### verify code sample output ###
#################################
check_text_in_log "\[ZooKeeperClient\] Connected"
check_text_in_log "\[KafkaServer id=0\] started"
check_text_in_log "Filling IMap"
check_text_in_log "Published 50000 messages to IMap -> source"
check_text_in_log "Consuming Topics"
check_text_in_log "Received 50000 entries in [0-9]* milliseconds"

