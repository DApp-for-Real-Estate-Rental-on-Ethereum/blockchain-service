pipeline {
    agent any

    tools {
        nodejs 'NodeJS-18'  // Must match the name configured in Jenkins Tools
    }

    environment {
        DOCKER_IMAGE_NAME = 'medgm/real-estate-blockchain-service'
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    sh 'git rev-parse --short HEAD'
                }
            }
        }

        stage('Verify Project Layout') {
            steps {
                script {
                    sh '''
                        echo "Verifying blockchain-service repository layout..."
                        echo "Node version: $(node --version)"
                        echo "NPM version: $(npm --version)"
                        pwd
                        ls -la
                        if [ ! -f package.json ]; then
                            echo "ERROR: package.json not found!"
                            ls -la
                            exit 1
                        fi
                        echo "package.json found."
                        if [ ! -f hardhat.config.js ]; then
                            echo "ERROR: hardhat.config.js not found!"
                            exit 1
                        fi
                        echo "hardhat.config.js found."
                    '''
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                script {
                    sh '''
                        echo "Installing Node.js dependencies..."
                        npm ci || npm install
                    '''
                }
            }
        }

        stage('Compile Contracts') {
            steps {
                script {
                    sh '''
                        echo "Compiling Solidity smart contracts..."
                        npx hardhat compile
                    '''
                }
            }
        }

        stage('Run Tests') {
            steps {
                script {
                    sh '''
                        echo "Running Hardhat tests..."
                        npx hardhat test || true
                    '''
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh """
                        echo "Building Docker image for Blockchain Service..."
                        docker build -t ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} .
                        docker tag ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} ${DOCKER_IMAGE_NAME}:latest
                        GIT_COMMIT_SHORT=\$(git rev-parse --short HEAD)
                        docker tag ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} ${DOCKER_IMAGE_NAME}:\${GIT_COMMIT_SHORT}
                        echo "Docker images created:"
                        docker images | grep ${DOCKER_IMAGE_NAME}
                    """
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'docker-registry-creds', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                        sh """
                            echo "Logging into Docker Hub..."
                            echo \$DOCKER_PASSWORD | docker login -u \$DOCKER_USERNAME --password-stdin

                            GIT_COMMIT_SHORT=\$(git rev-parse --short HEAD)
                            echo "Pushing images to Docker Hub..."
                            docker push ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}
                            docker push ${DOCKER_IMAGE_NAME}:latest
                            docker push ${DOCKER_IMAGE_NAME}:\${GIT_COMMIT_SHORT}
                        """
                    }
                }
            }
        }

        stage('Deploy to Local Registry') {
            steps {
                script {
                    sh """
                        echo "Tagging and pushing to local registry..."
                        docker tag ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} localhost:5000/real-estate-blockchain-service:${BUILD_NUMBER}
                        docker tag ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} localhost:5000/real-estate-blockchain-service:latest

                        docker push localhost:5000/real-estate-blockchain-service:${BUILD_NUMBER}
                        docker push localhost:5000/real-estate-blockchain-service:latest

                        echo "Images in local registry:"
                        docker images | grep real-estate-blockchain-service
                    """
                }
            }
        }
    }

    post {
        always {
            script {
                sh """
                    echo "Cleaning up local Docker tags..."
                    docker rmi ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} || true
                    docker rmi ${DOCKER_IMAGE_NAME}:latest || true
                    docker rmi localhost:5000/real-estate-blockchain-service:${BUILD_NUMBER} || true
                """
            }
            // Clean workspace
            cleanWs()
        }
        success {
            echo "Blockchain-service pipeline completed successfully! 🎉"
        }
        failure {
            echo "Blockchain-service pipeline failed. ❌"
        }
    }
}
