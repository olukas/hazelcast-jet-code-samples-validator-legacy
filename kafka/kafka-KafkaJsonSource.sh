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
mvn "-Dexec.args=-classpath %classpath com.hazelcast.jet.examples.kafka.json.KafkaJsonSource" -Dexec.executable=java org.codehaus.mojo:exec-maven-plugin:1.6.0:exec | tee ${OUTPUT_LOG_FILE}

#################################
### verify code sample output ###
#################################
echo "Searching for job ID ..."
JOB_ID=$(sed -n 's:.*\:5701.* Execution plan for jobId=\(.*\), jobName=.*:\1:p' ${OUTPUT_LOG_FILE})
if [ "x${JOB_ID}" == "x" ]; then   
    echo "'Execution plan for jobId' has not been found in output log.";
    exit 1
fi
echo "job ID is ${JOB_ID}"

echo "Searching for job executionId ..."
JOB_EXECUTION_ID=$(sed -n 's:.*\:5701.*, executionId=\(.*\) initialized.*:\1:p' ${OUTPUT_LOG_FILE})
if [ "x${JOB_EXECUTION_ID}" == "x" ]; then   
    echo "executionId for job has not been found in output log.";
    exit 1
fi
echo "job executionId is ${JOB_EXECUTION_ID}"

echo "Checking whether job finished as expected ..."
EXPECTED_JOB_FINISH_LOG_COUNT=$(grep "Execution of job '${JOB_ID}', execution ${JOB_EXECUTION_ID} .*, reason=java.util.concurrent.CancellationException" ${OUTPUT_LOG_FILE} | wc -l)
if [ ${EXPECTED_JOB_FINISH_LOG_COUNT} -lt 1 ]; then   
    echo "executionId for job has not been found in output log.";
    exit 1
fi

check_text_in_log "\[ZooKeeperClient\] Connected"
check_text_in_log "\[KafkaServer id=0\] started"
check_text_in_log "Received 20 entries in [0-9]* milliseconds."

for i in {0..19}; do
    if [ $(($i % 2)) -eq 0 ];
    then
        EXPECTED_STATUS="true"
    else
        EXPECTED_STATUS="false"
    fi
    check_text_in_log "$i={\"username\":\"name$i\",\"password\":\"pass$i\",\"age\":$i,\"status\":${EXPECTED_STATUS}}"
done

