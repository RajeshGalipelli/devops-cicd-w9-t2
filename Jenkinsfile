pipeline {
    agent any

    environment {
        IMAGE_NAME = 'devops-cicd-w9-t2'
        IMAGE_TAG = "v${BUILD_NUMBER}"
        KUBECONFIG = '/var/lib/jenkins/.kube/config'
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/RajeshGalipelli/devops-cicd-w9-t2.git'
            }
        }

        stage('Build') {
            steps {
                echo 'Building application...'
                sh 'python3 -m py_compile app.py'
            }
        }

        stage('Test') {
            steps {
                echo 'Testing application...'
                sh 'python3 -m py_compile app.py'
            }
        }

        stage('Docker Build') {
            steps {
                echo "Building Docker image ${IMAGE_NAME}:${IMAGE_TAG}"

                sh """
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                """
            }
        }

        stage('Docker Test') {
            steps {
                echo 'Testing Docker container...'

                sh """
                    docker rm -f cicd-test 2>/dev/null || true

                    docker run -d \
                      --name cicd-test \
                      -p 5001:5000 \
                      ${IMAGE_NAME}:${IMAGE_TAG}

                    sleep 5

                    curl -f http://localhost:5001

                    docker rm -f cicd-test
                """
            }
        }

        stage('Load Image into K3s') {
            steps {
                echo 'Loading Docker image into K3s...'

                sh """
                    docker save ${IMAGE_NAME}:${IMAGE_TAG} -o app-image.tar
                    sudo k3s ctr images import app-image.tar
                    rm -f app-image.tar
                """
            }
        }

        stage('Deploy') {
            steps {
                echo 'Deploying application to Kubernetes...'

                sh """
                    sed -i 's|image:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|' deployment.yml

                    kubectl apply -f deployment.yml
                    kubectl apply -f service.yml
                """
            }
        }

        stage('Rolling Update') {
            steps {
                echo 'Waiting for rolling deployment...'

                sh """
                    kubectl rollout status deployment/devops-cicd-app --timeout=120s
                """
            }
        }

        stage('Verify') {
            steps {
                echo 'Verifying deployment...'

                sh """
                    kubectl get deployment
                    kubectl get pods
                    kubectl get service
                """
            }
        }
    }

    post {
        success {
            echo 'CI/CD deployment completed successfully!'
        }

        failure {
            echo 'CI/CD deployment failed.'
        }
    }
}
