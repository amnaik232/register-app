pipeline {
    agent any

    tools {
        maven 'maven3'
        jdk 'java 17'
    }

    environment {
        DOCKER_IMAGE = "mangtha/register-app"
        IMAGE_TAG    = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('clean work space') {
            steps {
                cleanWs()
            }
        }
        stage('checkout from scm') {
            steps {
                git branch: 'main', credentialsId: 'github', url: 'https://github.com/amnaik232/register-app.git'
            }
        }
        stage('build application') {
            steps {
                sh 'mvn clean package'
            }
        }
        stage('test application') {
            steps {
                sh 'mvn test'
            }
        }
        stage('sonarqube') {
            steps {
                withSonarQubeEnv(installationName: 'sonarqube', credentialsId: 'jenkinssonarqubetoken') {
                    sh 'mvn org.sonarsource.scanner.maven:sonar-maven-plugin:sonar'
                }
            }
        }
        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        stage('Docker Build') {
            steps {
                sh 'docker build -t $DOCKER_IMAGE:$IMAGE_TAG -t $DOCKER_IMAGE:latest .'
            }
        }
        stage('Trivy Image Scan') {
            steps {
                sh '''
                    mkdir -p /home/ubuntu/trivy-tmp /home/ubuntu/trivy-cache
                    TMPDIR=/home/ubuntu/trivy-tmp trivy image --cache-dir /home/ubuntu/trivy-cache --severity HIGH,CRITICAL --exit-code 0 --format table -o trivy-report.txt $DOCKER_IMAGE:$IMAGE_TAG
                    cat trivy-report.txt
                '''
            }
        }
        stage('Docker Push') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerpassword', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push $DOCKER_IMAGE:$IMAGE_TAG
                        docker push $DOCKER_IMAGE:latest
                        docker logout
                    '''
                }
            }
        }
        stage('Update K8s Manifest') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'github', usernameVariable: 'GIT_USER', passwordVariable: 'GIT_TOKEN')]) {
                    sh '''
                        git config user.name "jenkins"
                        git config user.email "jenkins@ci.local"
                        sed -i "s|image: mangtha/register-app:.*|image: ${DOCKER_IMAGE}:${IMAGE_TAG}|g" k8s/deployment.yaml
                        git add k8s/deployment.yaml
                        git diff --cached --quiet || git commit -m "Update image tag to ${IMAGE_TAG} [skip ci]"
                        git push https://${GIT_USER}:${GIT_TOKEN}@github.com/amnaik232/register-app.git HEAD:main
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'trivy-report.txt', allowEmptyArchive: true
        }
    }
}
