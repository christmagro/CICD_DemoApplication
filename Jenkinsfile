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
    image: docker:24.0.6-git # Changed to -git version
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
    tty: true
"""
        }
    }

    environment {
        APP_NAME        = "app-demo-cicd-poc"
        DOCKER_USER     = "christmagro"
        GITOPS_REPO     = "https://github.com/christmagro/cicd_poc_argo_repo.git"

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
                        // Git is now available in this container!
                        sh "git config --global --add safe.directory '*'"

                        def TAG = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                        def FULL_IMAGE = "${DOCKER_USER}/${APP_NAME}:${TAG}"

                        sh 'sleep 5' // Give DinD time to warm up

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
                        sh "git config --global --add safe.directory '*'"

                        def TAG = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                        def FULL_IMAGE = "${DOCKER_USER}/${APP_NAME}:${TAG}"
                        def branch = env.BRANCH_NAME.replaceAll("/", "-")

                        sh "rm -rf gitops-repo"
                        sh "git clone https://${GITHUB_TOKEN}@${GITOPS_REPO} gitops-repo"

                        dir('gitops-repo') {
                            if (branch == 'main' || branch == 'master') {
                                sh "sed -i 's|IMAGE_PLACEHOLDER|${FULL_IMAGE}|g' prod/deployment.yaml"
                                sh "sed -i 's|APP_NAME_PLACEHOLDER|${APP_NAME}|g' prod/*.yaml"
                                sh "sed -i 's|HOST_PLACEHOLDER|${APP_NAME}.localhost|g' prod/ingress.yaml"
                            } else {
                                sh "mkdir -p features/${branch}"
                                sh "cp templates/* features/${branch}/"

                                sh "sed -i 's|IMAGE_PLACEHOLDER|${FULL_IMAGE}|g' features/${branch}/*.yaml"
                                sh "sed -i 's|APP_NAME_PLACEHOLDER|${APP_NAME}|g' features/${branch}/*.yaml"
                                sh "sed -i 's|HOST_PLACEHOLDER|${APP_NAME}-${branch}.localhost|g' features/${branch}/ingress.yaml"
                            }

                            sh "git config user.email 'jenkins@poc.com'"
                            sh "git config user.name 'Jenkins CI'"
                            sh "git add ."
                            sh "git commit -m 'Deploy ${branch} - ${TAG}'"
                            sh "git push origin main"
                        }
                    }
                }
            }
        }
    }
}