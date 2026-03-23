pipeline {
    agent { label 'ec2-agent' }

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 60, unit: 'MINUTES')
    }

    parameters {
        string(
            name: 'TEST_SUITE',
            defaultValue: 'Test Suites/Smoke',
            description: 'Katalon test suite path'
        )
        string(
            name: 'KATALON_PROJECT_PATH',
            defaultValue: '/katalon/project/Jenkins2Smoke.prj',
            description: 'Path to the Katalon .prj file inside the ECS container'
        )
        string(
            name: 'SUBNET_IDS',
            defaultValue: 'subnet-03edfae6295968a77',
            description: 'Comma-separated private subnet IDs for the Fargate task'
        )
        string(
            name: 'SECURITY_GROUP_IDS',
            defaultValue: 'sg-014254f1dc8168a1a',
            description: 'Security group ID(s) for the Fargate task'
        )
        choice(
            name: 'ASSIGN_PUBLIC_IP',
            choices: ['DISABLED', 'ENABLED'],
            description: 'DISABLED for private subnets'
        )
    }

    environment {
        AWS_REGION          = 'us-west-2'
        ECS_CLUSTER         = 'katalon-testing-dev-cluster'
        ECS_TASK_DEFINITION = 'katalon-testing-dev-katalon'
        ECS_CONTAINER_NAME  = 'katalon-container'
        KATALON_ORG_ID      = '2333388'
        CW_LOG_GROUP        = '/ecs/katalon-testing-dev-katalon'
    }

    stages {

        stage('Init') {
            steps {
                script {
                    env.BUILD_TIMESTAMP = sh(
                        script: 'date +%Y%m%d-%H%M%S',
                        returnStdout: true
                    ).trim()

                    env.NORMALIZED_TEST_SUITE = params.TEST_SUITE?.trim() ?: 'Test Suites/Smoke'
                    if (!env.NORMALIZED_TEST_SUITE.startsWith('Test Suites/')) {
                        env.NORMALIZED_TEST_SUITE = "Test Suites/${env.NORMALIZED_TEST_SUITE}"
                    }

                    echo "BUILD_TIMESTAMP      = ${env.BUILD_TIMESTAMP}"
                    echo "TEST_SUITE           = ${env.NORMALIZED_TEST_SUITE}"
                    echo "KATALON_PROJECT_PATH = ${params.KATALON_PROJECT_PATH}"
                    echo "SUBNET_IDS           = ${params.SUBNET_IDS}"
                }
            }
        }

        stage('Verify AWS access') {
            steps {
                sh '''
                    set -e
                    aws --version
                    aws sts get-caller-identity
                '''
            }
        }

        stage('Run Katalon on ECS') {
            steps {
                withCredentials([
                    string(credentialsId: 'katalon-api-key', variable: 'KATALON_API_KEY')
                ]) {
                    script {
                        def subnetList = params.SUBNET_IDS.split(',').collect { it.trim() }.findAll { it }
                        def sgList = params.SECURITY_GROUP_IDS.split(',').collect { it.trim() }.findAll { it }

                        if (subnetList.isEmpty()) { error('SUBNET_IDS cannot be empty') }
                        if (sgList.isEmpty())     { error('SECURITY_GROUP_IDS cannot be empty') }

                        def cleanApiKey = env.KATALON_API_KEY?.trim()?.replaceFirst(/^apiKey=/, '')

                        def commandList = [
                            "-runMode=console",
                            "-projectPath=${params.KATALON_PROJECT_PATH}",
                            "-testSuitePath=${env.NORMALIZED_TEST_SUITE}",
                            "-browserType=Chrome",
                            "-apiKey=${cleanApiKey}",
                            "-orgID=${env.KATALON_ORG_ID}",
                            "-retry=0",
                            "-statusDelay=15"
                        ]

                        def overrides = [containerOverrides: [[name: env.ECS_CONTAINER_NAME, command: commandList]]]
                        def networkConfig = [awsvpcConfiguration: [subnets: subnetList, securityGroups: sgList, assignPublicIp: params.ASSIGN_PUBLIC_IP]]

                        writeFile file: 'ecs-overrides.json', text: groovy.json.JsonOutput.toJson(overrides)
                        writeFile file: 'ecs-network-config.json', text: groovy.json.JsonOutput.toJson(networkConfig)

                        def taskArn = sh(
                            script: """
                                aws ecs run-task \
                                  --region '${env.AWS_REGION}' \
                                  --cluster '${env.ECS_CLUSTER}' \
                                  --task-definition '${env.ECS_TASK_DEFINITION}' \
                                  --launch-type FARGATE \
                                  --count 1 \
                                  --network-configuration file://ecs-network-config.json \
                                  --overrides file://ecs-overrides.json \
                                  --query 'tasks[0].taskArn' \
                                  --output text
                            """,
                            returnStdout: true
                        ).trim()

                        if (!taskArn || taskArn == 'None' || taskArn == 'null') {
                            error('ECS run-task returned no taskArn')
                        }

                        env.ECS_TASK_ARN = taskArn
                        env.ECS_TASK_ID  = taskArn.tokenize('/').last()
                        echo "Started ECS task: ${env.ECS_TASK_ARN}"

                        sh """
                            aws ecs wait tasks-stopped \
                              --region '${env.AWS_REGION}' \
                              --cluster '${env.ECS_CLUSTER}' \
                              --tasks '${env.ECS_TASK_ARN}'
                        """

                        def exitCode = sh(
                            script: """
                                aws ecs describe-tasks \
                                  --region '${env.AWS_REGION}' \
                                  --cluster '${env.ECS_CLUSTER}' \
                                  --tasks '${env.ECS_TASK_ARN}' \
                                  --query "tasks[0].containers[?name=='${env.ECS_CONTAINER_NAME}'].exitCode | [0]" \
                                  --output text
                            """,
                            returnStdout: true
                        ).trim()

                        def stopReason = sh(
                            script: """
                                aws ecs describe-tasks \
                                  --region '${env.AWS_REGION}' \
                                  --cluster '${env.ECS_CLUSTER}' \
                                  --tasks '${env.ECS_TASK_ARN}' \
                                  --query 'tasks[0].stoppedReason' \
                                  --output text
                            """,
                            returnStdout: true
                        ).trim()

                        echo "Container exit code : ${exitCode}"
                        echo "Task stopped reason : ${stopReason}"

                        if (exitCode != '0') {
                            error("Katalon tests failed — exitCode=${exitCode}, stoppedReason=${stopReason}, taskArn=${env.ECS_TASK_ARN}")
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                if (env.ECS_TASK_ARN?.trim()) {
                    echo "Task ARN  : ${env.ECS_TASK_ARN}"
                    echo "CW logs   : ${env.CW_LOG_GROUP}"
                    echo "Log stream: ecs/${env.ECS_CONTAINER_NAME}/${env.ECS_TASK_ID}"
                }
            }
            archiveArtifacts artifacts: 'ecs-overrides.json,ecs-network-config.json', allowEmptyArchive: true
            cleanWs(deleteDirs: true, notFailBuild: true)
        }
    }
}
