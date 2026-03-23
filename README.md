# Katalon ECS Pipeline

Runs Katalon test suites on AWS ECS Fargate, triggered from a Jenkins pipeline on an EC2 agent.

---

## Architecture

```
GitHub (katalon_ecs repo)
        │
        │  Jenkinsfile checkout
        ▼
Jenkins EC2 Agent (JENKINS_TEST_INSTANCE, 10.0.2.172)
  • aws cli
  • IAM instance profile (ec2-ssm-role)
        │
        │  aws ecs run-task
        ▼
ECS Fargate (katalon-testing-dev-cluster)
  katalon-container
  Image: katalon-test-runner:katalonc-02
  Project: /katalon/project/Jenkins2Smoke.prj
        │
        ├── Outbound via NAT gateway (nat-05245ef75ddba3c59)
        ├── Logs → CloudWatch /ecs/katalon-testing-dev-katalon
        └── Results → Katalon TestOps (org 2333388)
```

---

## Key AWS Resources

| Resource | Value |
|---|---|
| AWS Account | 318798562215 |
| Region | us-west-2 |
| VPC | vpc-0c26152a2a6ff305f |
| ECS Cluster | katalon-testing-dev-cluster |
| Task Definition | katalon-testing-dev-katalon |
| Container Name | katalon-container |
| ECR Image | 318798562215.dkr.ecr.us-west-2.amazonaws.com/katalon-test-runner:katalonc-02 |
| CloudWatch Log Group | /ecs/katalon-testing-dev-katalon |
| Private Subnet (Fargate) | subnet-03edfae6295968a77 (10.0.10.0/24) |
| Public Subnet | subnet-00ba39cba9fde8ea9 (10.0.1.0/24) |
| NAT Gateway | nat-05245ef75ddba3c59 |
| ECS Security Group | sg-014254f1dc8168a1a |
| Jenkins Agent IP | 10.0.2.172 (i-06627a43be02b44e2) |
| Jenkins Controller | 10.0.2.80 (i-073281b4bb767be0b) |
| Katalon Org ID | 2333388 |

---

## Repository Layout

```
katalon_ecs/
├── Jenkinsfile                  # Pipeline definition
├── Dockerfile                   # Builds the Katalon runner image
├── katalon-task-def.json        # ECS task definition (for manual registration)
├── Jenkins2Smoke.prj            # Katalon project file
├── Test Suites/                 # Katalon test suites
├── Test Cases/                  # Katalon test cases
├── Scripts/                     # Katalon test scripts
├── Profiles/                    # Katalon execution profiles
├── Include/                     # Katalon config
├── GlobalVariables.glbl         # Katalon global variables
└── README.md                    # This file
```

---

## Jenkins Setup

### Agent Node (ec2-agent-01)
- **Instance**: i-06627a43be02b44e2 (JENKINS_TEST_INSTANCE, 10.0.2.172)
- **Label**: `ec2-agent`
- **Remote root**: `/home/ec2-user/jenkins`
- **Launch**: SSH, credential `ec2-agent-ssh` (lf-sysadm key pair)
- **Host Key Verification**: Non verifying
- **Java path**: `/usr/bin/java`

### Required Jenkins Credentials
| ID | Type | Value |
|---|---|---|
| `katalon-api-key` | Secret Text | Katalon API key from testops.katalon.io |
| `ec2-agent-ssh` | SSH Username with private key | lf-sysadm.pem, username: ec2-user |

### Pipeline Job Configuration
- **Job name**: katalon_test_1
- **Type**: Pipeline
- **Repo URL**: https://github.com/donmaslanka/katalon_ecs
- **Script Path**: Jenkinsfile
- **Branch**: main

---

## Running the Pipeline

Go to **Jenkins → katalon_test_1 → Build with Parameters**:

| Parameter | Default | Description |
|---|---|---|
| `TEST_SUITE` | `Test Suites/Smoke` | Katalon test suite to run |
| `KATALON_PROJECT_PATH` | `/katalon/project/Jenkins2Smoke.prj` | Project file path in container |
| `SUBNET_IDS` | `subnet-03edfae6295968a77` | Private subnet — routes via NAT gateway |
| `SECURITY_GROUP_IDS` | `sg-014254f1dc8168a1a` | ECS task security group |
| `ASSIGN_PUBLIC_IP` | `DISABLED` | Always DISABLED — NAT gateway handles egress |


---

## Updating Tests

When you change test cases or test suites:

1. Edit files in this repo (`Test Cases/`, `Test Suites/`, `Scripts/`)
2. Commit and push to `main`
3. Rebuild the Docker image:

```powershell
cd C:\Users\dmasl\Desktop\Work\LeadFusion\katalon_ecs

aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 318798562215.dkr.ecr.us-west-2.amazonaws.com

docker build --no-cache -t 318798562215.dkr.ecr.us-west-2.amazonaws.com/katalon-test-runner:katalonc-03 .
docker push 318798562215.dkr.ecr.us-west-2.amazonaws.com/katalon-test-runner:katalonc-03
```

4. Update `katalon-task-def.json` — change image tag to `katalonc-03`
5. Register new task definition:

```powershell
aws ecs register-task-definition --cli-input-json file://katalon-task-def.json --region us-west-2
```

6. Trigger the pipeline

**Tagging convention**: increment the suffix for each new build (`katalonc-01`, `katalonc-02`, `katalonc-03`...)

---

## Viewing Test Results

### CloudWatch Logs
The pipeline prints the exact log stream in the build output:
```
Log stream: ecs/katalon-container/<task-id>
```

Fetch logs:
```powershell
MSYS_NO_PATHCONV=1 aws logs get-log-events `
  --log-group-name /ecs/katalon-testing-dev-katalon `
  --log-stream-name ecs/katalon-container/<task-id> `
  --region us-west-2 `
  --query 'events[*].message' `
  --output text | Out-File -Encoding utf8 katalon-log.txt
notepad katalon-log.txt
```

### Katalon TestOps
Results are reported to https://testops.katalon.io under org 2333388.

---

## Exit Codes

| Code | Meaning |
|---|---|
| 0 | All tests passed |
| 2 | License/project error (check API key and project path) |
| 5 | Tests ran but one or more failed |


---

## Troubleshooting

### Pipeline stuck on "waiting to schedule task"
- Jenkins node `ec2-agent-01` is offline
- Go to **Jenkins → Manage Jenkins → Nodes → ec2-agent-01 → Launch agent**
- If it fails, SSH may be down — check instance `i-06627a43be02b44e2` is running:
  ```powershell
  aws ec2 describe-instances --instance-ids i-06627a43be02b44e2 --region us-west-2 --query 'Reservations[0].Instances[0].State.Name' --output text
  ```

### ECS task fails with CannotPullContainerError
- ECR image tag doesn't exist
- Check available tags: `aws ecr describe-images --repository-name katalon-test-runner --region us-west-2 --query 'imageDetails[*].imageTags' --output table`
- Rebuild and push the image, re-register task definition

### Katalon exits with code 2 — license activation failed
- API key is wrong or expired — verify at testops.katalon.io → Settings → API Key
- Container can't reach testops.katalon.io — check NAT gateway is available:
  ```powershell
  aws ec2 describe-nat-gateways --region us-west-2 --filter "Name=nat-gateway-id,Values=nat-05245ef75ddba3c59" --query 'NatGateways[0].State' --output text
  ```
- Verify private subnet routes through NAT:
  ```powershell
  aws ec2 describe-route-tables --region us-west-2 --filters "Name=association.subnet-id,Values=subnet-03edfae6295968a77" --query 'RouteTables[0].Routes' --output table
  ```

### Katalon exits with code 5 — tests failed
- Infrastructure is working correctly — this is a test failure
- Check CloudWatch logs for the specific test case that failed
- Check Katalon TestOps for detailed reports

### Invalid project path error
- The image doesn't contain `Jenkins2Smoke.prj`
- Rebuild the image with `--no-cache` from the repo root
- Verify before pushing: `docker run --rm <image> cat /katalon/project/Jenkins2Smoke.prj`

### aws ecs wait times out
- Default waiter polls for 10 minutes — if tests take longer, increase pipeline timeout
- Check if the task is still running: `aws ecs list-tasks --cluster katalon-testing-dev-cluster --region us-west-2`

---

## IAM Roles

| Role | Purpose |
|---|---|
| `ec2-ssm-role` | Jenkins agent EC2 instance profile — allows ECS run-task |
| `katalon-execution-role-v4` | ECS task execution — pulls ECR image, writes CloudWatch logs |
| `katalon-task-role-v4` | ECS container runtime — S3 access for results |

---

## Network

| Resource | Value |
|---|---|
| VPC CIDR | 10.0.0.0/16 |
| Public subnets | 10.0.1.0/24, 10.0.2.0/24 |
| Private subnets | 10.0.10.0/24, 10.0.11.0/24 |
| NAT gateway | nat-05245ef75ddba3c59 in subnet-00ba39cba9fde8ea9 |
| EIP for NAT | 54.200.81.121 (eipalloc-025893a7f565fe045) |
| Fargate tasks run in | subnet-03edfae6295968a77 (10.0.10.0/24) |
