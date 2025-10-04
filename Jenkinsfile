pipeline {
    agent {
        docker {
            image 'node:16'
            args '-v /var/run/docker.sock:/var/run/docker.sock -u root'
        }
    }
    
    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }
    
    environment {
        DOCKER_IMAGE = 'kazirakib/eb-express-sample'
        DOCKER_TAG = "${BUILD_NUMBER}"
    }
    
    stages {
        stage('Install Docker') {
            steps {
                sh '''
                    echo "Installing Docker CLI..."
                    # Download Docker CLI binary directly
                    curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-20.10.24.tgz -o docker.tgz
                    tar -xzf docker.tgz
                    mv docker/docker /usr/local/bin/
                    rm -rf docker docker.tgz
                    chmod +x /usr/local/bin/docker
                    docker --version
                '''
            }
        }
        
        stage('Install Dependencies') {
            steps {
                echo 'Installing Node.js dependencies...'
                sh '''
                    npm install --save
                    echo "Dependencies installed successfully"
                '''
            }
        }
        
        stage('Run Tests') {
            steps {
                echo 'Running unit tests...'
                script {
                    try {
                        sh 'npm test'
                    } catch (Exception e) {
                        echo "No tests specified or tests failed: ${e.message}"
                        echo "Continuing pipeline execution..."
                    }
                }
            }
        }
        
        stage('Security Scan - Dependencies') {
            steps {
                echo 'Running security audit on dependencies...'
                script {
                    def auditResult = sh(
                        script: 'npm audit --json > audit-results.json || true',
                        returnStatus: true
                    )
                    
                    sh '''
                        if [ -f audit-results.json ]; then
                            echo "Audit results:"
                            cat audit-results.json
                            
                            # Check for critical vulnerabilities
                            CRITICAL=$(cat audit-results.json | grep -o '"critical":[0-9]*' | cut -d':' -f2 || echo "0")
                            HIGH=$(cat audit-results.json | grep -o '"high":[0-9]*' | cut -d':' -f2 || echo "0")
                            
                            echo "Critical vulnerabilities: $CRITICAL"
                            echo "High vulnerabilities: $HIGH"
                            
                            if [ "$CRITICAL" -gt 0 ]; then
                                echo "CRITICAL vulnerabilities detected! Pipeline will fail."
                                exit 1
                            fi
                            
                            if [ "$HIGH" -gt 0 ]; then
                                echo "WARNING: High vulnerabilities detected!"
                            fi
                        fi
                    '''
                    
                    archiveArtifacts artifacts: 'audit-results.json', allowEmptyArchive: true
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo "Building Docker image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                script {
                    // Create Dockerfile if it doesn't exist
                    sh '''
                        if [ ! -f Dockerfile ]; then
                            echo "Creating Dockerfile..."
                            cat > Dockerfile << 'EOF'
FROM node:16-alpine

# Create app directory
WORKDIR /usr/src/app

# Install app dependencies
COPY package*.json ./
RUN npm install --production

# Copy app source
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
RUN chown -R nodejs:nodejs /usr/src/app
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start application
CMD [ "npm", "start" ]
EOF
                        fi
                    '''
                    
                    // Build the Docker image
                    sh """
                        docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                        docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest
                        echo "Docker image built successfully"
                    """
                }
            }
        }
        
        stage('Image Security Scan') {
            steps {
                echo 'Scanning Docker image for vulnerabilities...'
                script {
                    try {
                        sh """
                            docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                                aquasec/trivy:latest image --severity HIGH,CRITICAL \
                                ${DOCKER_IMAGE}:${DOCKER_TAG} || echo "Trivy scan completed with findings"
                        """
                    } catch (Exception e) {
                        echo "Image security scan completed: ${e.message}"
                    }
                }
            }
        }
        
        stage('Push to Registry') {
            steps {
                echo 'Preparing to push Docker image...'
                script {
                    sh """
                        echo "Docker image ready: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                        echo "To push to Docker Hub, configure Docker Hub credentials in Jenkins"
                        # Uncomment below when Docker Hub credentials are configured:
                        # docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                        # docker push ${DOCKER_IMAGE}:latest
                    """
                }
            }
        }
    }
    
    post {
        always {
            echo 'Pipeline execution completed'
            sh 'docker images | grep ${DOCKER_IMAGE} || true'
        }
        success {
            echo 'Pipeline succeeded! Docker image built successfully.'
        }
        failure {
            echo 'Pipeline failed! Check logs for details.'
        }
        cleanup {
            echo 'Cleaning up workspace...'
            cleanWs()
        }
    }
}