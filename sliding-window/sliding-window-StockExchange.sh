#!/bin/bash

export SCRIPT_WORKSPACE=$1
export JET_REPO=$2

export OUTPUT_LOG_FILE=${SCRIPT_WORKSPACE}/output.log

function check_stock_occurs_in_log {
    echo "Checking whether $1 occurs in log ..."
    STOCK_OCCURS_COUNT=$(grep "$1" ${OUTPUT_LOG_FILE} | wc -l)
    if [ ${STOCK_OCCURS_COUNT} -lt 1 ]; then   
        echo "Stock $1 does not occur in output log.";
        exit 1
    fi
    echo "Checking whether every line for stock $1 finishes with number ..."
    CORRECT_LINE_COUNT=$(grep "$1.*[0-9]$" ${OUTPUT_LOG_FILE} | wc -l)
    if [ ${STOCK_OCCURS_COUNT} -ne ${CORRECT_LINE_COUNT} ]; then   
        echo "There is line which contains stock but does not finish with number.";
        exit 1
    fi    
}

cd ${JET_REPO}
mvn clean install -U -B -Dmaven.test.failure.ignore=true -DskipTests

###########################
### execute code sample ###
###########################
cd ${JET_REPO}/examples/sliding-windows
mvn "-Dexec.args=-classpath %classpath com.hazelcast.jet.examples.slidingwindow.StockExchange" -Dexec.executable=java org.codehaus.mojo:exec-maven-plugin:1.6.0:exec | tee ${OUTPUT_LOG_FILE}

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

check_stock_occurs_in_log AAAP
check_stock_occurs_in_log AAL
check_stock_occurs_in_log AAME
check_stock_occurs_in_log AAOI
check_stock_occurs_in_log AAON
check_stock_occurs_in_log AAPC
check_stock_occurs_in_log AAPL
check_stock_occurs_in_log AAWW
check_stock_occurs_in_log AAXJ
check_stock_occurs_in_log ABAC
