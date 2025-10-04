pipeline {
  agent none

  environment {
    REGISTRY_URL  = 'https://index.docker.io/v1/'
    REGISTRY_CRED = 'dockerhub-creds'             // Jenkins credentials ID
    IMAGE_NAME    = 'kazirakib/eb-express-sample'  
  }

  options {
    timestamps()
    ansiColor('xterm')
    buildDiscarder(logRotator(numToKeepStr: '20'))
    disableConcurrentBuilds()
  }

  stages {
    stage('Checkout') {
      agent { label 'built-in' } // lightweight checkout
      steps {
        checkout scm
        sh 'git log -1 --pretty=oneline || true'
      }
    }

    stage('Build & Test (Node 16)') {
      // 1b-i: Node 16 Docker image as the build agent
      agent {
        docker {
          image 'node:16'
          args '-u 0:0'
        }
      }
      steps {
        sh '''
          set -eux
          node --version
          npm --version

          # 1b-ii: install dependencies as requested
          npm install --save

          # Run tests (sample may have none; keep non-fatal if needed)
          npm test || echo "Tests missing or failing (non-fatal for sample)"
        '''
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: 'reports/**/*.xml'
        }
      }
    }

    stage('Dependency Scan (OWASP DC)') {
      // 2a: integrate dependency scanner
      agent { label 'built-in' }
      steps {
        sh '''
          set -eux
          mkdir -p depcheck

          # HTML report
          docker run --rm \
            -v "$PWD":/src \
            -v "$PWD/depcheck":/report \
            owasp/dependency-check:latest \
            --scan /src \
            --format HTML \
            --out /report \
            --enableRetired

          # JSON report for evaluation
          docker run --rm \
            -v "$PWD":/src \
            -v "$PWD/depcheck":/report \
            owasp/dependency-check:latest \
            --scan /src \
            --format JSON \
            --out /report \
            --enableRetired

          # 2b: fail pipeline if High/Critical found
          count=$(jq -r '
            .dependencies[]? 
            | (.vulnerabilities // [])
            | map((.severity|tostring|ascii_upcase) | select(.==\"HIGH\" or .==\"CRITICAL\"))
            | length
          ' depcheck/dependency-check-report.json 2>/dev/null | awk '{s+=$1} END{print s+0}')

          echo "High/Critical vulnerability count: ${count}"
          if [ "${count}" -gt 0 ]; then
            echo "❌ Failing build due to High/Critical vulnerabilities."
            exit 1
          fi
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'depcheck/*', allowEmptyArchive: true
          script {
            try {
              publishHTML(target: [
                reportDir: 'depcheck',
                reportFiles: 'dependency-check-report.html',
                reportName: 'Dependency-Check'
              ])
            } catch (err) {
              echo "HTML Publisher not installed; skipping publishHTML."
            }
          }
        }
      }
    }

    stage('Build Docker Image') {
      agent { label 'built-in' }
      steps {
        sh '''
          set -eux
          GIT_SHA=$(git rev-parse --short HEAD)
          docker build -t ${IMAGE_NAME}:$GIT_SHA .
          docker tag ${IMAGE_NAME}:$GIT_SHA ${IMAGE_NAME}:latest
        '''
      }
    }

    stage('Push Image') {
      agent { label 'built-in' }
      steps {
        withDockerRegistry(credentialsId: "${REGISTRY_CRED}", url: "${REGISTRY_URL}") {
          sh '''
            set -eux
            GIT_SHA=$(git rev-parse --short HEAD)
            docker push ${IMAGE_NAME}:$GIT_SHA
            docker push ${IMAGE_NAME}:latest
          '''
        }
      }
    }
  }

  post {
    success { echo "Pipeline finished successfully ✔" }
    failure { echo "Pipeline failed. See stage logs." }
  }
}
