#!/usr/bin/env bash

function pused() {
    local PORT=$1
    local PID=$(/usr/sbin/lsof -i:${PORT} | awk 'NR>1{print $2}')
    PIDS[${PORT}]=${PID}
    if [ -n "${PID}" ]; then
        echo "port ${PORT} is used by pid ${PID}"
        return 0
    else
        return 1
    fi
}

function pstop() {
    local PORT=$1
    pused ${PORT}
    local PID=${PIDS[${PORT}]}
    if [ -n "${PID}" ]; then
        kill ${PID}
        echo "killing pid ${PID}"
        while [ -n "${PID}" ];do
            sleep 1
            pused ${PORT}
            local PID=${PIDS[${PORT}]}
            echo "waiting pid ${PID} to be killed"
        done
    fi
    echo "port ${PORT} is free"
}

function pstart() {
    local PORT=$1
    local RETRY=$2
    PORT=${PORT} nohup npm start 1>>~/log-${PORT}.out 2>>~/log-${PORT}.err &
    while [[ ${RETRY} > 0 ]]; do
        pused ${PORT}
        local PID=${PIDS[${PORT}]}
        if [ -n "${PID}" ]; then
            break
        fi
        echo "starting at ${PORT}, retry=${RETRY}"
        sleep 1
        local RETRY=$((RETRY-1))
    done
    if [[ ${RETRY} == 0 ]]; then
        echo "deploy FAILED"
        return 1
    else
        return 0
    fi
}

function pwait() {
    local URL=$1
    local RETRY=$2
    while [[ ${RETRY} > 0 ]]; do
        local HTTP_CODE=$(curl -s ${URL} -o /dev/null -w %{http_code})
        if [[ ${HTTP_CODE} == 200 ]]; then
            break
        fi
        echo "${URL} return ${HTTP_CODE}, retry=${RETRY}"
        sleep 1
        local RETRY=$((RETRY-1));
    done
    if [[ ${RETRY} == 0 ]]; then
        echo "deploy FAILED"
        return 1
    else
        echo "${URL} return ${HTTP_CODE}"
        return 0
    fi
}

PORT1=3000
PORT2=3100

PIDS=()

function run1() {
    pstop ${PORT1} && pstart ${PORT1} 5 && pwait "http://localhost:${PORT1}/" 2 && pstop ${PORT2} && echo "deploy SUCCEED" || return 1
}

function run2() {
    pstop ${PORT2} && pstart ${PORT2} 5 && pwait "http://localhost:${PORT2}/" 2 && pstop ${PORT1} && echo "deploy SUCCEED" || return 1
}

pused ${PORT1} && run2 || run1