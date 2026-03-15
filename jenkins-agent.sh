#!/usr/bin/env bash
set -euo pipefail

echo "========== jenkins-agent.sh starting =========="
echo "IMAGE_VERSION=2.0-websocket"
echo "------------------------------------------------"

# Compatibility: allow either variable name
JENKINS_AGENT_SECRET="${JENKINS_AGENT_SECRET:-${JENKINS_SECRET:-}}"
JENKINS_WORKDIR="${JENKINS_AGENT_WORKDIR:-/workspace}"

echo "Key Jenkins-related env vars:"
echo "  JENKINS_URL          = '${JENKINS_URL:-<empty>}'"
echo "  JENKINS_AGENT_NAME   = '${JENKINS_AGENT_NAME:-<empty>}'"
echo "  JENKINS_AGENT_SECRET = '${JENKINS_AGENT_SECRET:+<set>}'"
echo "  JENKINS_AGENT_WORKDIR= '${JENKINS_WORKDIR}'"
echo "------------------------------------------------"

if [[ -z "${JENKINS_URL:-}" || -z "${JENKINS_AGENT_SECRET:-}" || -z "${JENKINS_AGENT_NAME:-}" ]]; then
  echo "ERROR: Missing one of JENKINS_URL, JENKINS_AGENT_SECRET/JENKINS_SECRET, JENKINS_AGENT_NAME – cannot start agent."
  sleep 15
  exit 1
fi

mkdir -p /usr/share/jenkins "${JENKINS_WORKDIR}" "${JENKINS_WORKDIR}/tmp"

# Keep temp off /tmp (important in many runtimes)
export JAVA_OPTS="${JAVA_OPTS:-} -Djava.io.tmpdir=${JENKINS_WORKDIR}/tmp"

echo "Downloading agent.jar from: ${JENKINS_URL%/}/jnlpJars/agent.jar"
curl -fsSL "${JENKINS_URL%/}/jnlpJars/agent.jar" -o /usr/share/jenkins/agent.jar

echo "Starting Jenkins agent via WebSocket..."
exec java ${JAVA_OPTS} -jar /usr/share/jenkins/agent.jar \
  -url "${JENKINS_URL%/}" \
  -secret "${JENKINS_AGENT_SECRET}" \
  -name "${JENKINS_AGENT_NAME}" \
  -workDir "${JENKINS_WORKDIR}" \
  -webSocket
