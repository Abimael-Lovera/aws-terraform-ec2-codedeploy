# Diagrama da Arquitetura AWS - Contador App

```
                                    🌐 INTERNET
                                         │
                              ┌─────────────────────┐
                              │   Internet Gateway  │
                              │  (contador-app-dev) │
                              └─────────────────────┘
                                         │
                              ┌─────────────────────┐
                              │    Route Table      │
                              │ 0.0.0.0/0 → IGW     │
                              └─────────────────────┘
                                         │
                    ┌────────────────────┼────────────────────┐
                    │                    │                    │
                    │                    │                    │
          ┌─────────────────┐           VPC            ┌─────────────────┐
          │   Subnet 0      │      10.0.0.0/16         │   Subnet 1      │
          │ 10.0.0.0/24     │                          │ 10.0.1.0/24     │
          │ (us-east-1a)    │                          │ (us-east-1b)    │
          └─────────────────┘                          └─────────────────┘
                    │                                            │
          ┌─────────────────┐                          ┌─────────────────┐
          │   EC2 Instance  │                          │   EC2 Instance  │
          │ contador-app-   │                          │ contador-app-   │
          │    dev-ec2-0    │                          │    dev-ec2-1    │
          │                 │                          │                 │
          │ t2.micro        │                          │ t2.micro        │
          │ Java 17         │                          │ Java 17         │
          │ CodeDeploy Agent│                          │ CodeDeploy Agent│
          │ Spring Boot App │                          │ Spring Boot App │
          └─────────────────┘                          └─────────────────┘
                    │                                            │
                    └────────────────┬───────────────────────────┘
                                     │
                              ┌─────────────────────┐
                              │   Security Group    │
                              │ ┌─────────────────┐ │
                              │ │ SSH: 22         │ │
                              │ │ 203.0.113.10/32 │ │
                              │ ├─────────────────┤ │
                              │ │ HTTP: 8080      │ │
                              │ │ 0.0.0.0/0       │ │
                              │ └─────────────────┘ │
                              └─────────────────────┘

```

## Fluxo de Deploy

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Developer     │    │   CodeDeploy    │    │   EC2 Instance  │
│                 │    │   Application   │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │                        │
         │ 1. Package JAR         │                        │
         │    + scripts +         │                        │
         │    appspec.yml         │                        │
         │                        │                        │
         │ 2. Upload to S3        │                        │
         │    or GitHub           │                        │
         │                        │                        │
         │ 3. Create Deployment   │                        │
         ├───────────────────────→│                        │
         │                        │                        │
         │                        │ 4. Download Package    │
         │                        ├───────────────────────→│
         │                        │                        │
         │                        │ 5. Execute Hooks:      │
         │                        │                        │
         │                        │    BeforeInstall       │
         │                        │    ├─ install_dependencies.sh
         │                        │                        │
         │                        │    ApplicationStop     │
         │                        │    ├─ stop_application.sh
         │                        │                        │
         │                        │    AfterInstall        │
         │                        │    ├─ install_systemd_service.sh
         │                        │                        │
         │                        │    ApplicationStart    │
         │                        │    ├─ start_application.sh
         │                        │                        │
         │                        │    ValidateService     │
         │                        │    ├─ validate_service.sh
         │                        │                        │
         │                        │ 6. Report Success      │
         │                        │    or Failure          │
         │                        │                        │
         │ 7. Deploy Status       │                        │
         │←───────────────────────│                        │
         │                        │                        │

```

## IAM Roles e Permissões

```
┌─────────────────────────────────────────────────────────────────┐
│                        IAM ROLES                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐              ┌─────────────────┐           │
│  │ Instance Role   │              │ Service Role    │           │
│  │ (EC2 Instances) │              │ (CodeDeploy)    │           │
│  │                 │              │                 │           │
│  │ Policies:       │              │ Policies:       │           │
│  │ • CodeDeploy    │              │ • AWSCodeDeploy │           │
│  │ • CloudWatch    │              │   Role          │           │
│  │ • SSM           │              │                 │           │
│  └─────────────────┘              └─────────────────┘           │
│           │                                  │                  │
│           │                                  │                  │
│  ┌─────────────────┐              ┌─────────────────┐           │
│  │ EC2 Instance-0  │              │ CodeDeploy App  │           │
│  │ EC2 Instance-1  │              │ contador-app-   │           │
│  │                 │              │    dev-app      │           │
│  └─────────────────┘              └─────────────────┘           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```
