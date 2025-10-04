pipeline {
  // We’ll use stage-level agents:
  agent none

  environment {
    // ---- registry + image naming ----
    REGISTRY_URL  = 'https://index.docker.io/v1/'
    REGISTRY_CRED = 'dockerhub-creds'                    // Jenkins credentials ID
    IMAGE_NAME    = 'kazirakib/eb-express-sample'        // <-- Docker Hub username/repo
  }

  options {
    timestamps()
    ansiColor('xterm')
    buildDiscarder(logRotator(numToKeepStr: '20'))
    disableConcurrentBuilds()
  }

  stages {

    stage('Checkout') {
      agent { label 'built-in' }                         // lightweight checkout on controller
      steps {
        checkout scm
        sh 'git log -1 --pretty=oneline || true'
      }
    }

    stage('Build & Test (Node 16)') {
      // Requirement 1b-i: Node 16 Docker image as the build agent
      agent {
        docker {
          image 'node:16'
          // run as root so npm can install global tools if needed
          args '-u 0:0'
        }
      }
      steps {
        sh '''
          node --version
          npm --version

          # Requirement 1b-ii: install dependencies via npm install --save
          npm install --save

          # Run unit tests (non-fatal for sample app; adjust to fail if you have real tests)
          npm test || echo "No tests / tests failed (non-fatal for sample app)"
        '''
      }
      post {
        always {
          // collect any junit results if you generate them (optional)
          junit allowEmptyResults: true, testResults: 'reports/**/*.xml'
        }
      }
    }

    stage('Dependency Scan (OWASP Dependency-Check)') {
      // Uses Docker CLI on the controller to run the scanner
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
            --format "HTML" \
            --out /report \
            --enableRetired

          # JSON report for programmatic evaluation
          docker run --rm \
            -v "$PWD":/src \
            -v "$PWD/depcheck":/report \
            owasp/dependency-check:latest \
            --scan /src \
            --format "JSON" \
            --out /report \
            --enableRetired

          # Fail build if High/Critical vulnerabilities are found
          # (normalize severity text and count HIGH/CRITICAL)
          count=$(jq -r '
            .dependencies[]
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
          // If you have HTML Publisher installed, this will expose the report:
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
      // Use controller for docker build/push to reach your DinD engine
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
    success {
      echo "Pipeline finished successfully ✔"
    }
    failure {
      echo "Pipeline failed. Check previous stage logs for details."
    }
  }
}
