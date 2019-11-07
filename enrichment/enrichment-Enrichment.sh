#!/bin/bash

export SCRIPT_WORKSPACE=$1
export JET_REPO=$2

export USING_IMAP_OUTPUT_LOG_FILE=${SCRIPT_WORKSPACE}/output-enrichUsingIMap.log
export USING_REPLICATED_MAP_OUTPUT_LOG_FILE=${SCRIPT_WORKSPACE}/output-enrichUsingReplicatedMap.log
export USING_HASH_JOIN_OUTPUT_LOG_FILE=${SCRIPT_WORKSPACE}/output-enrichUsingHashJoin.log

function check_text_in_log {
    EXPECTED_TEXT=$1
    OUTPUT_LOG_FILE=$2
    echo "Checking log for '${EXPECTED_TEXT}' in '${OUTPUT_LOG_FILE}'"
    INITIAL_LOG_COUNT=$(grep "${EXPECTED_TEXT}" ${OUTPUT_LOG_FILE} | wc -l)
    if [ ${INITIAL_LOG_COUNT} -lt 1 ]; then   
        echo "Log '${EXPECTED_TEXT}' has not been found in output log.";
        exit 1
    fi
}

function check_job_started_and_finished {
    OUTPUT_LOG_FILE=$1
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
}

# check whether log contains some trades and that various Product/Brokers are generated 
function check_trades_are_generated_and_processed {
    OUTPUT_LOG_FILE=$1
    echo "Checking various Product/Brokers trades are generated in '${OUTPUT_LOG_FILE}' ..."
    PRODUCTS_COUNTER=0
    BROKERS_COUNTER=0
    occurs_in_log ${OUTPUT_LOG_FILE} "productId=31"
    PRODUCTS_COUNTER=$((${PRODUCTS_COUNTER}+$?))
    occurs_in_log ${OUTPUT_LOG_FILE} "productId=32"
    PRODUCTS_COUNTER=$((${PRODUCTS_COUNTER}+$?))
    occurs_in_log ${OUTPUT_LOG_FILE} "productId=33"
    PRODUCTS_COUNTER=$((${PRODUCTS_COUNTER}+$?))
    occurs_in_log ${OUTPUT_LOG_FILE} "productId=34"
    PRODUCTS_COUNTER=$((${PRODUCTS_COUNTER}+$?))
    occurs_in_log ${OUTPUT_LOG_FILE} "brokerId=21"
    BROKERS_COUNTER=$((${BROKERS_COUNTER}+$?))
    occurs_in_log ${OUTPUT_LOG_FILE} "brokerId=22"
    BROKERS_COUNTER=$((${BROKERS_COUNTER}+$?))
    occurs_in_log ${OUTPUT_LOG_FILE} "brokerId=23"
    BROKERS_COUNTER=$((${BROKERS_COUNTER}+$?))
    occurs_in_log ${OUTPUT_LOG_FILE} "brokerId=24"
    BROKERS_COUNTER=$((${BROKERS_COUNTER}+$?))
    if [ ${PRODUCTS_COUNTER} -lt 2 ]; then   
        echo "At least two different Products should occur in log '${OUTPUT_LOG_FILE}'";
        exit 1
    fi    
    if [ ${BROKERS_COUNTER} -lt 2 ]; then   
        echo "At least two different Brokers should occur in log '${OUTPUT_LOG_FILE}'";
        exit 1
    fi 
}

function occurs_in_log {
    OUTPUT_LOG_FILE=$1
    CHECKED_TEXT=$2
    OCCURED_COUNT=$(grep "${CHECKED_TEXT}" ${OUTPUT_LOG_FILE} | wc -l)
    if [ ${OCCURED_COUNT} -gt 0 ]; then   
        return 1
    fi
    return 0
}

function check_trades_enrichment {
    OUTPUT_LOG_FILE=$1
    echo "Checking enrichment in '${OUTPUT_LOG_FILE}' ..."
    check_certain_enrichment "productId=31" "US 1Y Bond" ${OUTPUT_LOG_FILE}
    check_certain_enrichment "productId=32" "US 10Y Bond" ${OUTPUT_LOG_FILE}
    check_certain_enrichment "productId=33" "UK 1Y Bond" ${OUTPUT_LOG_FILE}
    check_certain_enrichment "productId=34" "UK 10Y Bond" ${OUTPUT_LOG_FILE}
    check_certain_enrichment "brokerId=21" "Donte Biermann" ${OUTPUT_LOG_FILE}
    check_certain_enrichment "brokerId=22" "Hunter Jurado" ${OUTPUT_LOG_FILE}
    check_certain_enrichment "brokerId=23" "Rebbecca Prosper" ${OUTPUT_LOG_FILE}
    check_certain_enrichment "brokerId=24" "Kisha Agena" ${OUTPUT_LOG_FILE}
}

function check_certain_enrichment {
    CHECKED_ID=$1
    EXPECTED_VALUE=$2
    OUTPUT_LOG_FILE=$3
    OUTPUT_LOG_FILE_TMP=${OUTPUT_LOG_FILE}_tmp
    echo "Checking enrichment for '${CHECKED_ID}' in '${OUTPUT_LOG_FILE}' ..."
    grep "${CHECKED_ID}" ${OUTPUT_LOG_FILE} > ${OUTPUT_LOG_FILE_TMP}
    CHECKED_ID_COUNT=$(grep "${CHECKED_ID}" ${OUTPUT_LOG_FILE_TMP} | wc -l)
    EXPECTED_VALUE_COUNT=$(grep "${EXPECTED_VALUE}" ${OUTPUT_LOG_FILE_TMP} | wc -l)
    if [ ${CHECKED_ID_COUNT} -ne ${EXPECTED_VALUE_COUNT} ]; then
        echo "There is Trade with '${CHECKED_ID}' which does not include '${EXPECTED_VALUE}' in '${OUTPUT_LOG_FILE}'";
        exit 1
    fi     
}

cd ${JET_REPO}
mvn clean install -U -B -Dmaven.test.failure.ignore=true -DskipTests

##################################################
### execute code sample with enrichUsingIMap() ###
##################################################
cd ${JET_REPO}/examples/enrichment
mvn "-Dexec.args=-classpath %classpath com.hazelcast.jet.examples.enrichment.Enrichment" -Dexec.executable=java org.codehaus.mojo:exec-maven-plugin:1.6.0:exec | tee ${USING_IMAP_OUTPUT_LOG_FILE}

########################################################
### verify code sample output with enrichUsingIMap() ###
########################################################
check_job_started_and_finished ${USING_IMAP_OUTPUT_LOG_FILE}
check_text_in_log "Generating trade events" ${USING_IMAP_OUTPUT_LOG_FILE}
check_text_in_log "Stopped trade events" ${USING_IMAP_OUTPUT_LOG_FILE}
check_text_in_log "Loaded product map:" ${USING_IMAP_OUTPUT_LOG_FILE}
check_text_in_log "31->Product{id=31, name='US 1Y Bond'}" ${USING_IMAP_OUTPUT_LOG_FILE}
check_text_in_log "32->Product{id=32, name='US 10Y Bond'}" ${USING_IMAP_OUTPUT_LOG_FILE}
check_text_in_log "33->Product{id=33, name='UK 1Y Bond'}" ${USING_IMAP_OUTPUT_LOG_FILE}
check_text_in_log "34->Product{id=34, name='UK 10Y Bond'}" ${USING_IMAP_OUTPUT_LOG_FILE}
check_text_in_log "Loaded brokers map:" ${USING_IMAP_OUTPUT_LOG_FILE}
check_text_in_log "21->Broker{id=21, name='Donte Biermann'}" ${USING_IMAP_OUTPUT_LOG_FILE}
check_text_in_log "22->Broker{id=22, name='Hunter Jurado'}" ${USING_IMAP_OUTPUT_LOG_FILE}
check_text_in_log "23->Broker{id=23, name='Rebbecca Prosper'}" ${USING_IMAP_OUTPUT_LOG_FILE}
check_text_in_log "24->Broker{id=24, name='Kisha Agena'}" ${USING_IMAP_OUTPUT_LOG_FILE}
check_trades_are_generated_and_processed ${USING_IMAP_OUTPUT_LOG_FILE}
check_trades_enrichment ${USING_IMAP_OUTPUT_LOG_FILE}

##################################################
### execute code sample with enrichUsingReplicatedMap() ###
##################################################
cd ${JET_REPO}/examples/enrichment
sed -i 's#            Pipeline p = enrichUsingIMap();#//            Pipeline p = enrichUsingIMap();#' ${JET_REPO}/examples/enrichment/src/main/java/com/hazelcast/jet/examples/enrichment/Enrichment.java
sed -i 's#//            Pipeline p = enrichUsingReplicatedMap();#            Pipeline p = enrichUsingReplicatedMap();#' ${JET_REPO}/examples/enrichment/src/main/java/com/hazelcast/jet/examples/enrichment/Enrichment.java
mvn clean install -Pquick
mvn "-Dexec.args=-classpath %classpath com.hazelcast.jet.examples.enrichment.Enrichment" -Dexec.executable=java org.codehaus.mojo:exec-maven-plugin:1.6.0:exec | tee ${USING_REPLICATED_MAP_OUTPUT_LOG_FILE}

########################################################
### verify code sample output with enrichUsingReplicatedMap() ###
########################################################
check_job_started_and_finished ${USING_REPLICATED_MAP_OUTPUT_LOG_FILE}
check_text_in_log "Generating trade events" ${USING_REPLICATED_MAP_OUTPUT_LOG_FILE}
check_text_in_log "Stopped trade events" ${USING_REPLICATED_MAP_OUTPUT_LOG_FILE}
check_text_in_log "Loaded product replicated map:" ${USING_REPLICATED_MAP_OUTPUT_LOG_FILE}
check_text_in_log "31->Product{id=31, name='US 1Y Bond'}" ${USING_REPLICATED_MAP_OUTPUT_LOG_FILE}
check_text_in_log "32->Product{id=32, name='US 10Y Bond'}" ${USING_REPLICATED_MAP_OUTPUT_LOG_FILE}
check_text_in_log "33->Product{id=33, name='UK 1Y Bond'}" ${USING_REPLICATED_MAP_OUTPUT_LOG_FILE}
check_text_in_log "34->Product{id=34, name='UK 10Y Bond'}" ${USING_REPLICATED_MAP_OUTPUT_LOG_FILE}
check_text_in_log "Loaded brokers replicated map:" ${USING_REPLICATED_MAP_OUTPUT_LOG_FILE}
check_text_in_log "21->Broker{id=21, name='Donte Biermann'}" ${USING_REPLICATED_MAP_OUTPUT_LOG_FILE}
check_text_in_log "22->Broker{id=22, name='Hunter Jurado'}" ${USING_REPLICATED_MAP_OUTPUT_LOG_FILE}
check_text_in_log "23->Broker{id=23, name='Rebbecca Prosper'}" ${USING_REPLICATED_MAP_OUTPUT_LOG_FILE}
check_text_in_log "24->Broker{id=24, name='Kisha Agena'}" ${USING_REPLICATED_MAP_OUTPUT_LOG_FILE}
check_trades_are_generated_and_processed ${USING_REPLICATED_MAP_OUTPUT_LOG_FILE}
check_trades_enrichment ${USING_REPLICATED_MAP_OUTPUT_LOG_FILE}

##################################################
### execute code sample with enrichUsingHashJoin() ###
##################################################
cd ${JET_REPO}/examples/enrichment
sed -i 's#            Pipeline p = enrichUsingReplicatedMap();#//            Pipeline p = enrichUsingReplicatedMap();#' ${JET_REPO}/examples/enrichment/src/main/java/com/hazelcast/jet/examples/enrichment/Enrichment.java
sed -i 's#//            Pipeline p = enrichUsingHashJoin();#            Pipeline p = enrichUsingHashJoin();#' ${JET_REPO}/examples/enrichment/src/main/java/com/hazelcast/jet/examples/enrichment/Enrichment.java
mvn clean install -Pquick
mvn "-Dexec.args=-classpath %classpath com.hazelcast.jet.examples.enrichment.Enrichment" -Dexec.executable=java org.codehaus.mojo:exec-maven-plugin:1.6.0:exec | tee ${USING_HASH_JOIN_OUTPUT_LOG_FILE}

########################################################
### verify code sample output with enrichUsingHashJoin() ###
########################################################
check_job_started_and_finished ${USING_HASH_JOIN_OUTPUT_LOG_FILE}
check_text_in_log "Generating trade events" ${USING_HASH_JOIN_OUTPUT_LOG_FILE}
check_text_in_log "Stopped trade events" ${USING_HASH_JOIN_OUTPUT_LOG_FILE}
check_trades_are_generated_and_processed ${USING_HASH_JOIN_OUTPUT_LOG_FILE}
check_trades_enrichment ${USING_HASH_JOIN_OUTPUT_LOG_FILE}
