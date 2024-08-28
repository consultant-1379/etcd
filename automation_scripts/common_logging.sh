# Logging functions
#
# This module contains Logging functions and logic
# The module provides functions to log at different levels. At runtime the logging level is checkd against the variable "DCED_LOG4J_ROOT_LOGLEVEL"
# to match the level used by DCED.
# Log output is in the format: "<ISO 8601 timestamp> <severity> [<function name:line>] - <message>"
#
# NOTE: Interface methods are the ones without the "_" prefix

SEVERITY_LABEL_TRACE="TRACE"
SEVERITY_LABEL_DEBUG="DEBUG"
SEVERITY_LABEL_INFO="INFO"
SEVERITY_LABEL_WARN="WARN"
SEVERITY_LABEL_ERROR="ERROR"
SEVERITY_LABEL_FATAL="FATAL"
SERVICE_ID="eric-data-distributed-coordinator-ed"

DEFAULT_SEVERITY="INFO"

# TODO: copy value from DCED_LOG4J_ROOT_LOGLEVEL to another variable and use that instead throughtout the module. This will make it easier to port this module to other services
# TODO: check input values on every function, at least their presence

# log to stdout
_logToStdout() {
  echo "$@"
}

# Get timestamp adhering Log General Design Rule DR-D1114-010.
_getTimestamp() {
  date +"%Y-%m-%dT%H:%M:%S.%3N%:z"
}

# Converts log level to a number, higher value means higher priority
_severityToNumber() {
  local severity=$1
  local value=0
  case $severity in
    "ALL")
      value=0
      ;;
    "TRACE")
      value=1
      ;;
    "DEBUG")
      value=2
      ;;
    "INFO")
      value=3
      ;;
    "WARN")
      value=4
      ;;
    "ERROR")
      value=5
      ;;
    "FATAL")
      value=6
      ;;
    "OFF")
      value=7
      ;;
    *)
      # if unknown log as INFO level (cannot log an error/warn because it gets captured as return value)
      value=$(_severityToNumber $SEVERITY_LABEL_INFO)
      ;;
  esac
  echo $value
}

# Return true if log level passed as input can be logged given set log level of DCED (DCED_LOG4J_ROOT_LOGLEVEL), false otherwise
_checkLogLevel() {
  local msgSeverity=$1
  local targetSeverity=$DCED_LOG4J_ROOT_LOGLEVEL

  if [[ -z targetSeverity ]]
  then
    targetSeverity=$DEFAULT_SEVERITY
  fi

  if [[ $(_severityToNumber $msgSeverity) -ge $(_severityToNumber $targetSeverity) ]]
  then
    return 0
  fi
  return 1
}

# Convert Log4j severity levels to be aligned with levels defined in ADP Logging Schema.
_convertLog4jLogLevel() {
  local severity=${1,,}
  case $severity in
    trace)
      echo "debug" ;;
    warn)
      echo "warning" ;;
    fatal)
      echo "critical" ;;
    *)
      echo "$severity" ;;
  esac
}

# Log message with specific severity
# Never call this function directly, that would broke the "where" mechanism, always call one of: logDebug, logInfo, logWarn, logError.
_log() {
  local severity=$1
  shift
  if _checkLogLevel $severity
  then
    local message="$@"
    local timestamp="$(_getTimestamp)"
    local convertedLogLevel="$(_convertLog4jLogLevel $severity)"
    # TODO: add script filename to the "source" field?
    # gets function name and line number, 2 means the 2nd callee
    local source="${FUNCNAME[2]}"
    local location="${BASH_LINENO[2]}"
    local logMessage="{\"version\": \"1.2.0\", \"timestamp\": \"${timestamp}\", \"severity\": \"${convertedLogLevel}\", \"service_id\": \"${SERVICE_ID}\", \"message\": \"${message}\", \"metadata\": {\"pod_name\": \"${POD_NAME}\", \"container_name\": \"${CONTAINER_NAME}\", \"namespace\": \"${NAMESPACE}\"}}"
    # TODO: check where logs are supposed to be sent (stdout, file, etc...) and write specific function
    _logToStdout $logMessage
  fi
}

#
# Interface methods
#

# Logs at TRACE level
logTrace() {
  _log $SEVERITY_LABEL_TRACE "$@"
}

# Logs at DEBUG level
logDebug() {
  if [[ ${DCED_LOG4J_ROOT_LOGLEVEL} == "DEBUG" ]]; then
    _log $SEVERITY_LABEL_DEBUG "$@"
  fi
}

# Logs at INFO level
logInfo() {
  _log $SEVERITY_LABEL_INFO "$@"
}

# Logs at WARNING level
logWarn() {
  _log $SEVERITY_LABEL_WARN "$@"
}

# Logs at ERROR level
logError() {
  _log $SEVERITY_LABEL_ERROR "$@"
}

# Logs at FATAL level
logFatal() {
  _log $SEVERITY_LABEL_FATAL "$@"
}
