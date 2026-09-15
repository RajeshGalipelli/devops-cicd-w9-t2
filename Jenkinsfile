pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 20, unit: 'MINUTES')
    }

    environment {
        IMAGE_NAME = 'devops-cicd-w9-t2'
        IMAGE_TAG = "v${BUILD_NUMBER}"
        IMAGE = "${IMAGE_NAME}:${IMAGE_TAG}"
        KUBECONFIG = '/var/lib/jenkins/.kube/config'
        K8S_DEPLOYMENT = 'devops-cicd-app'
        K8S_CONTAINER = 'devops-cicd-app'
        K8S_SERVICE = 'devops-cicd-service'
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Checking out source code...'

                git branch: 'main',
                    url: 'https://github.com/RajeshGalipelli/devops-cicd-w9-t2.git'
            }
        }

        stage('Validate Tools') {
            steps {
                sh '''
                    set -e

                    echo "=== Tool Versions ==="
                    python3 --version
                    docker --version
                    kubectl version --client
                    trivy --version

                    echo "=== Kubernetes Access ==="
                    kubectl get nodes
                '''
            }
        }

        stage('Build') {
            steps {
                echo "Compiling Python application..."

                sh '''
                    set -e
                    python3 -m py_compile app.py
                '''
            }
        }

        stage('Test') {
            steps {
                echo "Running application tests..."

                sh '''
                    set -e

                    if find . -maxdepth 2 -type f \\( \
                        -name 'test_*.py' \
                        -o -name '*_test.py' \
                    \\) | grep -q .; then

                        python3 -m unittest discover -v

                    else

                        echo "No Python unit-test files found."
                        echo "Application syntax validation completed successfully."

                    fi
                '''
            }
        }

        stage('Trivy Filesystem Scan') {
            steps {
                echo "Scanning source code and configuration..."

                sh '''
                    set -e

                    mkdir -p security-reports

                    trivy fs . \
                      --scanners vuln,misconfig,secret \
                      --severity HIGH,CRITICAL \
                      --exit-code 1 \
                      --no-progress \
                      -o security-reports/trivy-fs.txt
                '''
            }

            post {
                always {
                    archiveArtifacts(
                        artifacts: 'security-reports/trivy-fs.txt',
                        allowEmptyArchive: true
                    )
                }
            }
        }

        stage('Docker Build') {
            steps {
                echo "Building Docker image: ${IMAGE}"

                sh '''
                    set -e

                    docker build \
                      --pull \
                      -t "${IMAGE}" \
                      .
                '''
            }
        }

        stage('Trivy Image Scan') {
            steps {
                echo "Scanning Docker image for HIGH/CRITICAL vulnerabilities..."

                sh '''
                    set -e

                    trivy image \
                      --scanners vuln,secret \
                      --severity HIGH,CRITICAL \
                      --exit-code 1 \
                      --no-progress \
                      "${IMAGE}" \
                      -o security-reports/trivy-image.txt
                '''
            }

            post {
                always {
                    archiveArtifacts(
                        artifacts: 'security-reports/trivy-image.txt',
                        allowEmptyArchive: true
                    )
                }
            }
        }

        stage('Docker Test') {
            steps {
                echo "Testing application container..."

                sh '''
                    set -e

                    docker rm -f cicd-production-test 2>/dev/null || true

                    docker run -d \
                      --name cicd-production-test \
                      -p 5001:5000 \
                      "${IMAGE}"

                    trap 'docker rm -f cicd-production-test >/dev/null 2>&1 || true' EXIT

                    echo "Waiting for application..."
                    sleep 5

                    curl --fail --silent --show-error \
                      http://127.0.0.1:5001/

                    echo
                    echo "Docker application health check passed."
                '''
            }
        }

        stage('Load Image into K3s') {
            steps {
                echo "Importing image into K3s containerd..."

                sh '''
                    set -e

                   
		    docker save "${IMAGE}" | sudo -n /usr/local/sbin/k3s-import-image

                    echo "Image imported into K3s:"
                    sudo -n /usr/local/bin/k3s ctr images list | \
                      grep "${IMAGE_NAME}" || true
                '''
            }
        }

        stage('Deploy') {
            steps {
                script {

                    def previousImage = sh(
                        script: """
                            kubectl get deployment ${K8S_DEPLOYMENT} \
                              -o jsonpath='{.spec.template.spec.containers[0].image}' \
                              2>/dev/null || true
                        """,
                        returnStdout: true
                    ).trim()

                    env.PREVIOUS_IMAGE = previousImage

                    echo "Previous image: ${previousImage ?: 'none'}"
                    echo "Deploying new image: ${IMAGE}"

                    try {

                        sh '''
                            set -e

                            kubectl apply -f deployment.yml
                            kubectl apply -f service.yml

                            kubectl set image \
                              deployment/${K8S_DEPLOYMENT} \
                              ${K8S_CONTAINER}=${IMAGE}

                            kubectl rollout status \
                              deployment/${K8S_DEPLOYMENT} \
                              --timeout=120s
                        '''

                    } catch (err) {

                        echo "Deployment failed."

                        if (env.PREVIOUS_IMAGE?.trim()) {

                            echo "Rolling back to previous image: ${env.PREVIOUS_IMAGE}"

                            sh '''
                                kubectl set image \
                                  deployment/${K8S_DEPLOYMENT} \
                                  ${K8S_CONTAINER}=${PREVIOUS_IMAGE}

                                kubectl rollout status \
                                  deployment/${K8S_DEPLOYMENT} \
                                  --timeout=120s || true
                            '''

                        } else {

                            echo "No previous image exists. Rollback skipped."

                        }

                        throw err
                    }
                }
            }
        }

        stage('Health Verification') {
            steps {
                echo "Verifying Kubernetes deployment..."

                sh '''
                    set -e

                    kubectl get deployment ${K8S_DEPLOYMENT}
                    kubectl get pods -l app=${K8S_DEPLOYMENT} -o wide
                    kubectl get service ${K8S_SERVICE}

                    kubectl rollout status \
                      deployment/${K8S_DEPLOYMENT} \
                      --timeout=120s

                    READY=$(kubectl get deployment ${K8S_DEPLOYMENT} \
                      -o jsonpath='{.status.readyReplicas}')

                    DESIRED=$(kubectl get deployment ${K8S_DEPLOYMENT} \
                      -o jsonpath='{.spec.replicas}')

                    echo "Ready replicas: ${READY:-0}"
                    echo "Desired replicas: ${DESIRED}"

                    test "${READY:-0}" = "${DESIRED}"

                    echo "Kubernetes health verification passed."
                '''
            }
        }

        stage('Application Health Check') {
            steps {
                echo "Testing application through NodePort..."

                sh '''
                    set -e

                    NODE_IP=$(kubectl get nodes \
                      -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

                    echo "Testing application on ${NODE_IP}:30080"

                    curl --fail --silent --show-error \
                      --max-time 10 \
                      "http://${NODE_IP}:30080/"

                    echo
                    echo "Application health check passed."
                '''
            }
        }

        stage('Production Readiness Summary') {
            steps {
                sh '''
                    echo "======================================"
                    echo " PRODUCTION READINESS SUMMARY"
                    echo "======================================"
                    echo "Image: ${IMAGE}"
                    echo "Deployment: ${K8S_DEPLOYMENT}"
                    echo "Replicas:"
                    kubectl get deployment ${K8S_DEPLOYMENT}
                    echo
                    echo "Pods:"
                    kubectl get pods -l app=${K8S_DEPLOYMENT}
                    echo
                    echo "Service:"
                    kubectl get service ${K8S_SERVICE}
                    echo
                    echo "Security reports:"
                    ls -lh security-reports/ || true
                    echo "======================================"
                '''
            }
        }
    }

    post {

        always {
            sh '''
                docker rm -f cicd-production-test 2>/dev/null || true
                docker image prune -f >/dev/null 2>&1 || true
            '''

            archiveArtifacts(
                artifacts: 'security-reports/*',
                allowEmptyArchive: true
            )
        }

        success {
            echo 'Production-ready CI/CD pipeline completed successfully.'
        }

        failure {
            echo 'Pipeline failed. Check the failed stage and archived Trivy report.'
        }
    }
}
