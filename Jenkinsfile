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
    image: docker:latest
    command: ['cat']
    tty: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
"""
        }
    }

    environment {
        APP_NAME        = "spring-poc"
        DOCKER_USER     = "your-dockerhub-username"
        GITOPS_REPO     = "github.com/your-username/your-gitops-repo.git"
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
                        TAG = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                        FULL_IMAGE = "${DOCKER_USER}/${APP_NAME}:${TAG}"

                        sh "docker login -u ${DOCKER_CREDS_USR} -p ${DOCKER_CREDS_PSW}"
                        sh "docker build -t ${FULL_IMAGE} ."
                        sh "docker push ${FULL_IMAGE}"
                    }
                }
            }
        }

        stage('Update GitOps Repository') {
            steps {
                container('docker-cli') { // Any container with git works
                    script {
                        def branch = env.BRANCH_NAME.replaceAll("/", "-") // Clean branch name

                        // Clone GitOps repo
                        sh "git clone https://${GITHUB_TOKEN}@${GITOPS_REPO} gitops-repo"

                        dir('gitops-repo') {
                            if (branch == 'main') {
                                // Logic for Production
                                sh "sed -i 's|IMAGE_PLACEHOLDER|${FULL_IMAGE}|g' prod/deployment.yaml"
                                sh "sed -i 's|APP_NAME_PLACEHOLDER|${APP_NAME}|g' prod/*.yaml"
                                sh "sed -i 's|HOST_PLACEHOLDER|${APP_NAME}.localhost|g' prod/ingress.yaml"
                            } else {
                                // Logic for Ephemeral Feature Branch
                                sh "mkdir -p features/${branch}"
                                sh "cp templates/* features/${branch}/"

                                // Replace placeholders globally
                                sh "sed -i 's|IMAGE_PLACEHOLDER|${FULL_IMAGE}|g' features/${branch}/*.yaml"
                                sh "sed -i 's|APP_NAME_PLACEHOLDER|${APP_NAME}|g' features/${branch}/*.yaml"
                                sh "sed -i 's|HOST_PLACEHOLDER|${APP_NAME}-${branch}.localhost|g' features/${branch}/ingress.yaml"
                            }

                            // Commit and Push
                            sh "git config user.email 'jenkins@example.com'"
                            sh "git config user.name 'Jenkins CI'"
                            sh "git add ."
                            sh "git commit -m 'Deploy ${APP_NAME} image ${TAG} to ${branch}'"
                            sh "git push origin main"
                        }
                    }
                }
            }
        }
    }
}