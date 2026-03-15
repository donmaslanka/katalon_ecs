pipeline {

  agent { label 'katalon-ecs' }

  options {
    timestamps()
  }

  environment {
    PROJECT_FILE    = "Jenkins2Smoke.prj"
    TEST_SUITE_PATH = "Test Suites/Smoke"
    EXEC_PROFILE    = "default"
    BROWSER         = "Chrome"
  }

  stages {

    stage('Checkout Source') {
      steps {
        checkout scm
      }
    }

    stage('Verify Repo') {
      steps {
        sh '''
          set -e
          echo "=== BASIC NODE INFO ==="
          hostname
          whoami
          pwd

          echo "=== REPO CONTENTS ==="
          ls -la
          find . -maxdepth 3 -type f | sort

          echo "=== VERIFY PROJECT FILE ==="
          test -f "${PROJECT_FILE}"
        '''
      }
    }

    stage('Run Katalon Smoke Test') {
      steps {
        withCredentials([string(credentialsId: 'katalon-api-key', variable: 'KATALON_API_KEY')]) {
          sh '''
            set -e

            katalonc \
              -noSplash \
              -runMode=console \
              -projectPath="${PROJECT_FILE}" \
              -testSuitePath="${TEST_SUITE_PATH}" \
              -executionProfile="${EXEC_PROFILE}" \
              -browserType="${BROWSER}" \
              -apiKey="${KATALON_API_KEY}" \
              -retry=0
          '''
        }
      }
    }

  }

  post {
    always {
      archiveArtifacts artifacts: '**/Reports/**', allowEmptyArchive: true
      junit testResults: '**/*.xml', allowEmptyResults: true
    }
  }

}