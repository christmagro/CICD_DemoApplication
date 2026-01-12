pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: maven
    image: maven:3.8.5-openjdk-17
    command: ['cat']
    tty: true
  - name: docker-cli
    image: docker:24.0.6-git
    command: ['cat']
    env:
    - name: DOCKER_HOST
      value: tcp://localhost:2375
    tty: true
  - name: dind
    image: docker:24.0.6-dind
    securityContext:
      privileged: true
    env:
    - name: DOCKER_TLS_CERTDIR
      value: ""
    command: ["dockerd", "--host=tcp://localhost:2375", "--mtu=1400"]
    tty: true
"""
        }
    }

    environment {
        APP_NAME        = "app-demo-cicd-poc"
        DOCKER_USER     = "christmagro"
        GITOPS_REPO     = "github.com/christmagro/cicd_poc_argo_repo.git"
        DOCKER_CREDS    = credentials('docker-hub-creds')
        GITHUB_TOKEN    = credentials('github-token')
    }

    stages {
        stage('Build Jar') {
            steps {
                container('maven') {
                    sh 'mvn clean package -DskipTests'
                }
            }
        }

        stage('Build & Push Docker Image') {
            steps {
                container('docker-cli') {
                    script {
                        sh "git config --global --add safe.directory '*'"
                        def TAG = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                        def FULL_IMAGE = "${DOCKER_USER}/${APP_NAME}:${TAG}"

                        sh 'sleep 5'
                        sh "docker login -u ${DOCKER_CREDS_USR} -p ${DOCKER_CREDS_PSW}"
                        sh "docker build -t ${FULL_IMAGE} ."
                        sh "docker push ${FULL_IMAGE}"
                    }
                }
            }
        }

        stage('Update GitOps Repository') {
                    steps {
                        container('docker-cli') {
                            script {
                                // 1. CALCULATE ALL VARIABLES AT THE TOP (Global Scope)
                                def rawBranch = env.BRANCH_NAME
                                def branchSanitized = rawBranch.toLowerCase().replaceAll("[^a-z0-9]", "-")

                                def TAG = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                                def FULL_IMAGE = "${DOCKER_USER}/${APP_NAME}:${TAG}"

                                // Define specific hosts for each environment
                                def PROD_HOST = "${APP_NAME}.localhost"
                                def FEATURE_HOST = "${APP_NAME}-${branchSanitized}.localhost"

                                // 2. Setup Git environment
                                sh "git config --global --add safe.directory '*'"
                                sh "rm -rf gitops-repo"
                                sh "git clone https://${GITHUB_TOKEN}@${GITOPS_REPO} gitops-repo"

                                dir('gitops-repo') {
                                    if (branchSanitized == 'main' || branchSanitized == 'master') {
                                        // --- PRODUCTION LOGIC ---
                                        sh "sed -i 's|IMAGE_PLACEHOLDER|${FULL_IMAGE}|g' prod/deployment.yaml"
                                        sh "sed -i 's|APP_NAME_PLACEHOLDER|${APP_NAME}|g' prod/deployment.yaml"
                                        sh "sed -i 's|APP_NAME_PLACEHOLDER|${APP_NAME}|g' prod/service.yaml"
                                        sh "sed -i 's|APP_NAME_PLACEHOLDER|${APP_NAME}|g' prod/ingress.yaml"
                                        sh "sed -i 's|HOST_PLACEHOLDER|${PROD_HOST}|g' prod/ingress.yaml"
                                    } else {
                                        // --- FEATURE BRANCH LOGIC ---
                                        sh "mkdir -p features/${branchSanitized}"
                                        sh "cp templates/* features/${branchSanitized}/"

                                        sh "sed -i 's|IMAGE_PLACEHOLDER|${FULL_IMAGE}|g' features/${branchSanitized}/deployment.yaml"
                                        sh "sed -i 's|APP_NAME_PLACEHOLDER|${APP_NAME}|g' features/${branchSanitized}/deployment.yaml"
                                        sh "sed -i 's|APP_NAME_PLACEHOLDER|${APP_NAME}|g' features/${branchSanitized}/service.yaml"
                                        sh "sed -i 's|APP_NAME_PLACEHOLDER|${APP_NAME}|g' features/${branchSanitized}/ingress.yaml"
                                        sh "sed -i 's|HOST_PLACEHOLDER|${FEATURE_HOST}|g' features/${branchSanitized}/ingress.yaml"
                                    }

                                    // 3. Final Commit and Push
                                    sh "git config user.email 'jenkins@poc.com'"
                                    sh "git config user.name 'Jenkins CI'"
                                    sh "git add ."
                                    sh "git commit -m 'Deploy ${branchSanitized} - ${TAG}' || echo 'No changes to commit'"
                                    sh "git push origin main"
                                }
                            }
                        }
                    }
                }
    }
}