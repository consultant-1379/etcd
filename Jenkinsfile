def bob = 'python3 bob/bob.py'

pipeline {
    agent {
        node {
          label params.SLAVE
        }
     }
    environment {
           BRANCH=params.GERRIT_BRANCH.substring(GERRIT_BRANCH.lastIndexOf("-") + 1)
           HUB = credentials('eadphub-psw')
           KUBECONFIG = credentials('hoff102')
    }
    stages {
        stage('Prepare environment'){
          steps {
            echo "Update submodules to master fixed commit"
            sh "git submodule update --init --recursive"
            echo "Prepare Bob environment"
            sh "${bob} clean"
            echo "grant access for docker.sock which will use in java11 image"
            sh "sudo chmod 666 /var/run/docker.sock"
            withCredentials([string(credentialsId: 'hub-arm-seli-api-token', variable: 'SELI_API_TOKEN')]) {
                echo "Init environment"
                sh "${bob} init"
                sh "${bob} download-logshipper-interface"
            }
            echo "fetch and untar SHH"
            sh "${bob} hooklauncher-chart-fragments"
            withCredentials([string(credentialsId: 'hub-arm-rnd-ki-api-token', variable: 'RND_KI_API_TOKEN')]) {
                sh "${bob} logshipper-uplift"
            }
          }
        }

        stage('Scan Bazaar') {
             // This stage would update the PRIM ID, Restriction code (recode) into dependencies.yaml file
             when { expression { (params.IS_TEST_RELEASE=="false" && params.SCAN_BAZAAR=="true") } }
                 steps {
                    withCredentials([string(credentialsId: 'bazaar-token', variable: 'BAZAAR_TOKEN')]){
                       sh "${bob} scan-bazaar"
                       //Note that scan-bazaar stage would fail if any non permitted STAKO code (ESW3 or ESW4) has been used.
                    }
                 }
         }
        stage('Create ARMdocker credentials secret file') {
           steps {
               withCredentials([file(credentialsId: 'hub-armdocker-config-json', variable: 'DOCKER_CONFIG')]) {
                  sh 'cp $DOCKER_CONFIG armdocker-config.json'
               }
            }
        }
        stage('Bob Deploy For Agent') {
            steps {
                sh "export LOG_LEVEL=${params.BRA_LOG_LEVEL}; ${bob} bragent-install"
            }
        }
        stage('Specific FOSS stage') {
            when { expression { (params.IS_TEST_RELEASE=="false" && params.SPECIFIC_FOSS=="true") } }
            steps {
               script {
                        if (params.IS_PCR=="true") {
                            // sh "${bob} specific-foss"
                        }
               }
            }
        }
        stage('FOSSA Report Generation') {
            when { expression { (params.IS_TEST_RELEASE=="false" && params.FOSSA_REPORT=="true") } }
            steps {
                withCredentials([string(credentialsId: 'functional-user-fossa-api-token', variable: 'FOSSA_API_KEY'),
                                 usernamePassword(credentialsId: 'eadphub-psw', usernameVariable: 'GERRIT_USERNAME', passwordVariable: 'GERRIT_PASSWORD')]){
                    sh "${bob} fossa-init"
                    sh "${bob} fossa-analyze"
                    sh "${bob} fossa-scan-status-check"
                    sh "${bob} fossa-report-attribution"
                    sh "${bob} manage-fossa-report-licenses"
                }
                archiveArtifacts "doc/*fossa-report.json"
                archiveArtifacts "doc/*dependencies.yaml"
            }
        }
        stage('FOSSA License Selection') {
            when { expression { (params.IS_TEST_RELEASE=="false" && params.FOSSA_LICENSE_SELECTION=="true") } }
            steps {
                withCredentials([string(credentialsId: 'functional-user-fossa-api-token', variable: 'FOSSA_API_KEY'),
                                 usernamePassword(credentialsId: 'eadphub-psw', usernameVariable: 'GERRIT_USERNAME', passwordVariable: 'GERRIT_PASSWORD')]){
                    sh "${bob} dependency-update"
                    sh "${bob} select-licenses"
                }
                archiveArtifacts "doc/*fossa-report.json"
                archiveArtifacts "doc/*dependencies.yaml"
            }
        }
        stage('Validate Interface Fragment Schema') {
            when { expression { (params.IS_PCR=="true" && params.SKIP_VALIDATE_INTERFACE_SCHEMA=="false") } }
                steps {
                    sh "${bob} validate-interface-fragment"
                }
        }
        // this stage is added for testing purpose, if need to run this stage add GENERATE_SECURITY_ATTRIBUTES=="true" in jenkins PCR configuration
        stage('Generate Security Attributes') {
            when { expression { (params.GENERATE_SECURITY_ATTRIBUTES=="true") } }
            steps {
                withCredentials([usernamePassword(credentialsId: 'eadphub-psw', usernameVariable: 'GERRIT_USERNAME', passwordVariable: 'GERRIT_PASSWORD')]){
                    sh "${bob} validate-exemption-fragment"
                    sh "${bob} generate-security-attributes"

                    sh "${bob} validate-complete-security-attributes-json"
                    sh "${bob} generate-helm-template"
                    sh "${bob} generate-and-test-security-attributes-json"
                }
            }
        }
        stage('Lint files') {
            steps {
                sh "${bob} lint"
                sh "${bob} lint-helm3"
               }
        }
        stage('Sonarqube Analysis BrAgent') {
            when { expression { (params.IS_TEST_RELEASE=="false" && params.SONARQUBE_SCAN=="true") } }
            steps {
                withSonarQubeEnv('Sonarqube Server') {

                    sh "${bob} sonar:agent"
               }
            }
        }
        stage('Upload Service Ports JSON'){
            when { expression { (params.UPLOAD_SERVICE_PORTS=="true") } }
            steps{
                withCredentials([string(credentialsId: 'hub-arm-sero-api-token', variable: 'API_TOKEN')]) {
                    sh "${bob} handle-service-ports-docs:validate-and-upload-service-ports-file"
                }
            }
        }
        stage('Generate characteristics report formats') {
            when { expression { (params.CHARREPORT=="true") }}
                    steps {
                        withCredentials([string(credentialsId: 'hub-arm-sero-api-token', variable: 'API_TOKEN')]) {
                        sh "${bob} characteristics:pull"
                        sh "${bob} characteristics:generate-other-formats"
                        archiveArtifacts artifacts: 'characteristics_report.html, characteristics_report.pdf, characteristics_report.md', allowEmptyArchive: true
                    }
                }
        }
        stage('Generate files for Eridoc') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'eadphub-psw', usernameVariable: 'ERIDOC_USERNAME', passwordVariable: 'ERIDOC_PASSWORD')]) {
                    sh "${bob} surefire-report"
                    sh "${bob} handle-service-ports-docs:generate-service-ports-md-fragment"
                    sh "${bob} generate-docs"
                script{
                    if (params.UPLOAD=="true") {
                        echo "Eridoc upload"
                        sh "${bob} eridoc:upload"
                    }
                    else {
                        echo "Eridoc dry-run"
                        sh "${bob} eridoc:dryrun"
                    }
                 }
                }
            }
        }

        stage('Upload Metrics') {
            when { expression { (params.UPLOAD_METRICS=="false") } }
                steps{
                    withCredentials([string(credentialsId: 'hub-arm-sero-api-token', variable: 'API_TOKEN')]) {
                           sh "${bob} upload-pm-metrics"
                    }
                }
        }
        stage('Build httpprobe') {
            steps {

                sh "${bob} build-httpptobe"
            }
        }
        stage('Build docker image') {
            steps {
                script {
                     if (env.BRANCH == "master") {
                         sh "${bob} setup-repo-paths:is-master"
                     }
                     else {
                         sh "${bob} setup-repo-paths:is-dev"
                     }
                }
                withCredentials([usernamePassword(credentialsId: 'eadphub-psw', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                sh "${bob} image-build"
                }
            }
        }
        stage('Test docker image') {
            steps {
                sh "${bob} image-test"
            }
        }
        stage('Push docker image to internal repo') {
        when { expression { (params.UPLOAD_IMAGE=="true") } }
            steps {
                withCredentials([usernamePassword(credentialsId: 'eadphub-psw', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                sh "${bob} image-push-internal"
                }
            }
        }
        stage('Check CBOS Version') {
        when { expression { (params.IS_PCR=="true") || (params.IS_TEST_RELEASE=="true" && params.CHECK_CBOS_VERSION=="true") } }
                steps {
                        withCredentials([string(credentialsId: 'hub-arm-sero-api-token', variable: 'API_TOKEN'), string(credentialsId: 'hub-arm-seli-api-token', variable: 'SELI_API_TOKEN')])
                        {
                            script {
                                       catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE')
                                        {
                                            sh "${bob} check-cbo-version"
                                        }
                            }
                        }
                }
        }
        stage('PM Metrics Check') {
            when { expression { (params.IS_PCR=="true" && params.PM_Metrics_Check=="true") } }
             steps {
                 withCredentials([string(credentialsId: 'hub-arm-sero-api-token', variable: 'API_TOKEN')]) {
                    sh "${bob} pm-metrics-check"
                 }
             }
        }
        stage('DR Check docker image') {
        when { expression { (params.DR_CHECKER_IMAGE=="true") } }
            steps {
                sh "${bob} image-dr-check"

                publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: false,
                        keepAll: true,
                        reportDir: '.bob',
                        reportFiles: 'image_design-rule-check-report.html',
                        reportName: 'Docker_Image_Design_Rules_Report',
                        reportTitles: ''
                ])
            }
        }
        stage('Package helm Internal chart') {
            steps {
                  sh "${bob} helm-package-internal"
            }
        }
        stage('DR Check helm chart') {
            when { expression { (params.DR_CHECKER_CHART=="true") } }
            steps {
                 script {
                      try {
                         sh "${bob} helm-chart-check"
                      } catch (err) {
                         echo err
                      }
                 }
                publishHTML(target: [
                        allowMissing: false,
                        alwaysLinkToLastBuild: false,
                        keepAll: true,
                        reportDir: '.bob',
                        reportFiles: 'design-rule-check-report.html',
                        reportName: 'Helm_Chart_Design_Rules_Report',
                        reportTitles: ''
                ])
            }
        }
        stage('Upload helm internal chart') {
        when { expression { (params.UPLOAD_CHART=="true") } }
            steps {
                withCredentials([string(credentialsId: 'hub-arm-sero-api-token', variable: 'API_TOKEN')]) {
                  sh "${bob} helm-upload-internal"
                }
            }
        }
        stage('Service Footprint Checker') {
            when { expression { (params.IS_TEST_RELEASE=="true" && params.CHECK_FOOTPRINT=="true") } }
               steps {
                  withCredentials([string(credentialsId: 'hub-arm-sero-api-token', variable: 'API_TOKEN')]) {
                    sh "${bob} footprint-check"
                  }
               }
        }
        /* stage('pylint') {
          steps {
            sh 'python3 -m pylint --reports=n --rcfile=test/.pylintrc test/*.py'
          }
        }*/
        stage('[CERTOFF] Run tests without integration') {
            when { expression { (params.IS_RELEASE=="false" && params.TESTS=="true") } }
            steps {
               withCredentials([string(credentialsId: 'hub-arm-sero-api-token', variable: 'API_TOKEN')]) {
                timeout(time: 30, unit: 'MINUTES') {
                  sh "${bob} run-tests-certoff"
                }
                }
            }
        }
        stage('[CERTON] Run tests with integration') {
            when { expression { (params.IS_RELEASE=="false" && params.TESTS=="true") } }
            steps {
               withCredentials([string(credentialsId: 'hub-arm-sero-api-token', variable: 'API_TOKEN')]) {
                timeout(time: 50, unit: 'MINUTES') {
                  sh "${bob} run-tests-certon"
               }
                }
            }
        }
        stage('[CERTOFF-VERSIONS] Run upgrade/rollback from PRA and Devel') {
            when { expression { (params.IS_RELEASE=="false" && params.TESTS=="true") } }
            steps {
               withCredentials([string(credentialsId: 'hub-arm-sero-api-token', variable: 'API_TOKEN')]) {
                timeout(time: 30, unit: 'MINUTES') {
                  sh "${bob} run-tests-certoff-versions"
                }
                }
            }
        }
        stage('[CERTON-VERSIONS] Run upgrade/rollback from PRA and Devel') {
            when { expression { (params.IS_RELEASE=="false" && params.TESTS=="true") } }
            steps {
               withCredentials([string(credentialsId: 'hub-arm-sero-api-token', variable: 'API_TOKEN')]) {
                timeout(time: 30, unit: 'MINUTES') {
                  sh "${bob} run-tests-certon-versions"
                }
                }
            }
        }
        stage('Run Characteristics tests') {
            when { expression { (params.IS_RELEASE=="false" && params.CHARACTERISTICS_TESTS=="true") } }
            steps {
                    withCredentials([string(credentialsId: 'hub-arm-sero-api-token', variable: 'API_TOKEN')]) {
                    timeout(time: 50, unit: 'MINUTES'){
                        script{
                           sh "${bob} characteristics:assert-ready"
                           sh "${bob} run-characteristics-tests"
                           sh "${bob} characteristics:generate-report-input"
                           sh "${bob} characteristics:push-to-arm"
                        }
                    }
                }
            }
        }
        stage('Generate DP-RAF configuration') {
            when { expression { (params.IS_TEST_RELEASE=="false" && params.DPRAF=="true") } }
            steps {
               sh "${bob} generate-dpraf-configurations"
            }
        }
        stage('Validate DP-RAF configuration') {
            when { expression { (params.IS_TEST_RELEASE=="false" && params.DPRAF=="true") } }
            steps {
               sh "${bob} validate-dpraf-configuration"
            }
        }
        stage('Generate PRI') {
        when { expression { (params.IS_TEST_RELEASE=="false" && params.PRI=="true") } }
            steps {
                withCredentials([usernamePassword(credentialsId: 'eadphub-psw', usernameVariable: 'ERIDOC_USERNAME', passwordVariable: 'ERIDOC_PASSWORD'),string(credentialsId: 'eadphub-jira-pat', variable: 'JIRA_TOKEN')]) {
                script{
                    if (params.UPLOAD=="true") {
                        sh "${bob} doc-init:upload"
                    } else {
                        sh "${bob} doc-init:generate"
                    }
                }
                    sh "${bob} generate-pri"
                    archiveArtifacts 'build/pri.html'
                    archiveArtifacts 'build/pri.json'
                    archiveArtifacts 'build/pri.pdf'
                    publishHTML (target: [
                            allowMissing: false,
                            alwaysLinkToLastBuild: false,
                            keepAll: true,
                            reportDir: 'build/',
                            reportFiles: 'pri.html',
                            reportName: "PRI"
                    ])
                }
            }
        }

        stage('Munin Update') {
            when { expression { (params.IS_TEST_RELEASE=="false" && params.MUNIN_UPDATE=="true") } }
                steps {
                    withCredentials([string(credentialsId: 'munin_token', variable: 'MUNIN_TOKEN')]){
                        sh "${bob} munin-update-version"
                    }
                }
        }
        stage('Fetch Artifact Checksum') {
            when { expression { (params.IS_TEST_RELEASE=="false" && params.MUNIN_RELEASE=="true") } }
                steps {
                    withCredentials([string(credentialsId: 'hub-arm-sero-api-token', variable: 'API_TOKEN'), string(credentialsId: 'hub-arm-seli-api-token', variable: 'SELI_API_TOKEN')]) {
                        sh "${bob} fetch-artifact-checksums"
                    }
                }
        }
        stage('Set Release Artifacts in Munin') {
            when { expression { (params.IS_TEST_RELEASE=="false" && params.MUNIN_RELEASE=="true") } }
                steps {
                    withCredentials([string(credentialsId: 'munin_token', variable: 'MUNIN_TOKEN')]){
                        sh "${bob} munin-set-artifact"
                    }
                }
        }
        stage('Release version in Munin') {
            when { expression { (params.IS_TEST_RELEASE=="false" && params.MUNIN_RELEASE=="true") } }
                steps {
                    withCredentials([string(credentialsId: 'munin_token', variable: 'MUNIN_TOKEN')]){
                        sh "${bob} munin-release-version"
                    }
                }
        }
        stage('Generate License Fragment') {
           when { expression { (params.IS_TEST_RELEASE=="false" && params.LF=="true") } }
                steps {
                    withCredentials([string(credentialsId: 'functional-user-fossa-api-token', variable: 'FOSSA_API_KEY'), string(credentialsId: 'hub-arm-sero-api-token', variable: 'API_TOKEN'),
                                    usernamePassword(credentialsId: 'eadphub-psw', usernameVariable: 'GERRIT_USERNAME', passwordVariable: 'GERRIT_PASSWORD')]){
                           //sh "${bob} merge-dependencies"
                          //sh "${bob} generate-license-agreement"
                            // rpm-license-agreement-generate rule to be used generate RPM licenses
                           sh "${bob} rpm-license-agreement-generate"
                           sh "${bob} license-agreement-validate"
                           sh "${bob} license-agreement-doc-generate"
                    script {
                       if (params.UPLOAD=="true") {
                      // sh "${bob} upload-license-agreement"
                       }
                    }
                    archiveArtifacts "doc/*dependencies.yaml"
                    archiveArtifacts "doc/*license.agreement.json"
                    //archiveArtifacts "doc/license-agreement-doc.md"
                }
            }
        }
        stage('Structured-data generate') {
            when { expression { (params.STRUCTURED_DATA_GENERATE=="true") } }
            steps {
                    sh "${bob} structured-data-generate"
                    sh "${bob} structured-data-validate"
                    archiveArtifacts 'build/structured-output/*.json'
           }
        }

        stage('Structured-data upload') {
            when { expression { (params.STRUCTURED_DATA_GENERATE=="true") && (params.STRUCTURED_DATA_UPLOAD=="true") } }
            steps {
                withCredentials([string(credentialsId: 'hub-arm-sero-api-token', variable: 'API_TOKEN')]) {
                    sh "${bob} structured-data-upload"
                }
            }
        }
        stage('Bazaar Request') {
            when { expression { (params.IS_TEST_RELEASE=="false" && params.BAZAAR_REQUEST=="true") } }
                steps {
                    withCredentials([string(credentialsId: 'bazaar-token', variable: 'BAZAAR_TOKEN')]){
                        sh "${bob} bazaar-request"
                    }
                }
        }
        stage('Generate Software Vendor List') {
            when { expression { (params.IS_TEST_RELEASE=="false" && params.SVL=="true") } }
            steps {
                //sh "${bob} generate-svl"
                script {
                   if (params.UPLOAD=="true") {
                         //sh "${bob} svl-upload"
                       }
                }
            }
        }
        stage('Generate Marketplace Documents') {
           when { expression { (params.IS_TEST_RELEASE=="false" && params.MARKETPLACE_UPLOAD=="true") } }
           steps {
              withCredentials([string(credentialsId: 'hub-arm-sero-api-token', variable: 'API_TOKEN'),string(credentialsId: 'etcd-marketplace-token', variable: 'MARKETPLACE_TOKEN')]) {
               sh "${bob} generate-doc-zip-package"
               script {
                   if (params.UPLOAD=="true") {
                         sh "${bob} marketplace-upload:upload-doc-to-arm"
                         sh "${bob} marketplace-upload:refresh-adp-portal-marketplace"
                       }
                   }
                }
            }
        }
        stage('Register new version in EVMS') {
            when { expression { (params.IS_RELEASE=="true" && params.EVMS=="true") } }
            steps {
                withCredentials([usernamePassword(credentialsId: 'eadphub-psw', usernameVariable: 'EVMS_USERNAME', passwordVariable: 'EVMS_PASSWORD')])
                {
                    sh "${bob} evms-registration"
                }
            }
        }
        stage('Check EVMS registration') {
            when { expression { (params.IS_TEST_RELEASE=="false" && params.EVMS=="true") } }
            steps {
                withCredentials([usernamePassword(credentialsId: 'eadphub-psw', usernameVariable: 'EVMS_USERNAME', passwordVariable: 'EVMS_PASSWORD')])
                {
                    sh "${bob} evms-checker"
                }
            }
        }
        stage('[Release] Push docker image to public repo') {
            when { expression { (params.IS_RELEASE=="true" && params.PUBLISH=="true") } }
            steps {
                sh "${bob} image-publish"
            }
        }
        stage('[Release] Package and publish helm public chart') {
            when { expression { (params.IS_RELEASE=="true" && params.PUBLISH=="true") } }
            steps {
                withCredentials([string(credentialsId: 'hub-arm-sero-api-token', variable: 'API_TOKEN')]) {
                 sh "${bob} helm-package-public"
                 sh "${bob} helm-publish"
                }
            }
        }
        stage('[Release] Generate input for ADP staging') {
            when { expression { (params.IS_RELEASE=="true" && params.PUBLISH=="true") } }
            steps {
                sh "${bob} create-git-tag"
                sh "${bob} generate-input-for-adp-staging"
                archiveArtifacts "artifact.properties"
            }
        }
        stage('Cleanup Workspace') {
            steps {
                script {
                    sh "rm -rf \
                        defensicstar.tgz \
                        bragent/target/bragent-0.0.1-SNAPSHOT.jar \
                        bragent/Docker/target/bragent-0.0.1-SNAPSHOT.jar \
                        httpprobe/build/gocache \
                        Docker/metricsexporter/stdout-redirect \
                        Docker/stdout-redirect \
                        .bob/stdout-redirect \
                        .bob/stdout.tar \
                        .bob/container-structure-test"
                }
            }
        }
        /*stage('Register new version in Focal Point') {
            when { expression { (params.FOCAL_POINT=="true") } }
            steps {
                withCredentials([usernamePassword(credentialsId: 'eadphub-psw', usernameVariable: 'FOCALPOINT_USERNAME', passwordVariable: 'FOCALPOINT_PASSWORD')])
                {
                    sh "${bob} focalpoint-release"
                }
            }
        } */
    }
    post {
        always {
            archiveArtifacts artifacts: ".bob/*.log", allowEmptyArchive: true
            archiveArtifacts artifacts: 'build/**/**/*.*', allowEmptyArchive: true
            archiveArtifacts artifacts: 'build/**/*.*', allowEmptyArchive: true
            archiveArtifacts artifacts: 'build/*.*', allowEmptyArchive: true
            archiveArtifacts artifacts: "*.html", allowEmptyArchive: true
            archiveArtifacts artifacts: "pod_logs/*.log", allowEmptyArchive: true
            archiveArtifacts artifacts: 'evms.csv', allowEmptyArchive: true
            archiveArtifacts artifacts: ".bob/eric-data-distributed-coordinator-ed-internal/*.*", allowEmptyArchive: true
            archiveArtifacts artifacts: 'updated_adp_char_report.json', allowEmptyArchive: true
        }
        failure {
          script {
               if (params.IS_RELEASE=="true" && params.PUBLISH=="true") { // skip PCR job
               mail bcc: '', body: "Project: ${env.JOB_NAME} <br>Build Number: ${env.BUILD_NUMBER} <br> URL: ${env.BUILD_URL}", cc: '', charset: 'UTF-8', from: '', mimeType: 'text/html', replyTo: '', subject: "${currentBuild.currentResult}: ${env.JOB_NAME}", to: "koopa.troopas.external@ammeon.com";
                  }
             }
        }
        changed {
           script {
                if (params.IS_RELEASE=="true" && params.PUBLISH=="true") { // skip PCR job
                mail bcc: '', body: "Project: ${env.JOB_NAME} <br>Build Number: ${env.BUILD_NUMBER} <br> URL: ${env.BUILD_URL}", cc: '', charset: 'UTF-8', from: '', mimeType: 'text/html', replyTo: '', subject: "${currentBuild.currentResult}: ${env.JOB_NAME}", to: "koopa.troopas.external@ammeon.com";
                }
            }
         }
    }
}