pipeline {
    options {
        skipDefaultCheckout()
        buildDiscarder(logRotator(numToKeepStr: '5'))
        timeout(time: 1, unit: 'HOURS')
    }
    agent {
        node {
            label 'base'
        }
    }
    environment {
        NETWORK_OPTS = '--network ci_agent'
    }
    stages {
        stage('Checkout & Stash') {
            steps {
                checkout scm
                stash includes: '**', name: 'project'
            }
        }
        stage('SonarQube analysis') {
            steps {
                unstash 'project'
                script {
                    scannerHome = tool 'SonarScanner';
                }
                withSonarQubeEnv(credentialsId: 'sonarqube-user-token',
                    installationName: 'SonarQube instance') {
                    sh "${scannerHome}/bin/sonar-scanner"
                }
            }
        }
        stage('Ubuntu') {
            agent {
                node {
                    label 'yap-ubuntu-20-v1'
                }
            }
            steps {
                container('yap') {
                    unstash 'project'
                    sh 'sudo yap build ubuntu . -s'
                    stash includes: 'artifacts/*.deb', name: 'artifacts-ubuntu'
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'artifacts/*.deb', fingerprint: true
                }
            }
        }
        stage('RHEL') {
            agent {
                node {
                    label 'yap-rocky-8-v1'
                }
            }
            steps {
                container('yap') {
                    unstash 'project'
                    sh 'sudo yap build rocky . -s'
                    stash includes: 'artifacts/*.rpm', name: 'artifacts-rocky'
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'artifacts/*.rpm', fingerprint: true
                }
            }
        }
        stage('Upload To Devel') {
            when {
                branch 'devel';
            }
            steps {
                unstash 'artifacts-ubuntu'
                unstash 'artifacts-rocky'

                script {
                    def server = Artifactory.server 'zextras-artifactory'
                    def buildInfo
                    def uploadSpecUbuntu
                    def uploadSpecRhel

                    buildInfo = Artifactory.newBuildInfo()

                    uploadSpecUbuntu = '''{
                        "files": [
                            {
                                "pattern": "artifacts/*.deb",
                                "target": "ubuntu-devel/pool/",
                                "props": "deb.distribution=focal;deb.distribution=jammy;deb.distribution=noble;deb.component=main;deb.architecture=amd64"
                            }
                        ]
                    }'''

                    uploadSpecRhel = '''{
                        "files": [
                            {
                                "pattern": "artifacts/(carbonio-openjdk)-(*).x86_64.rpm",
                                "target": "centos8-devel/zextras/{1}/{1}-{2}.x86_64.rpm",
                                "props": "rpm.metadata.arch=x86_64;rpm.metadata.vendor=zextras",
                                "exclusions": ["*openjdk-cacerts*.rpm"]
                            },
                            {
                                "pattern": "artifacts/(carbonio-openjdk-cacerts)-(*).x86_64.rpm",
                                "target": "centos8-devel/zextras/{1}/{1}-{2}.x86_64.rpm",
                                "props": "rpm.metadata.arch=x86_64;rpm.metadata.vendor=zextras"
                            },
                            {
                                "pattern": "artifacts/(carbonio-openjdk)-(*).x86_64.rpm",
                                "target": "rhel9-devel/zextras/{1}/{1}-{2}.x86_64.rpm",
                                "props": "rpm.metadata.arch=x86_64;rpm.metadata.vendor=zextras",
                                "exclusions": ["*openjdk-cacerts*.rpm"]
                            },
                            {
                                "pattern": "artifacts/(carbonio-openjdk-cacerts)-(*).x86_64.rpm",
                                "target": "rhel9-devel/zextras/{1}/{1}-{2}.x86_64.rpm",
                                "props": "rpm.metadata.arch=x86_64;rpm.metadata.vendor=zextras"
                            }
                        ]
                    }'''
                    server.upload spec: uploadSpecUbuntu, buildInfo: buildInfo, failNoOp: false
                    server.upload spec: uploadSpecRhel, buildInfo: buildInfo, failNoOp: false
                }
            }
        }
        stage('Upload & Promotion') {
            when {
                buildingTag()
            }
            steps {
                unstash 'artifacts-ubuntu'
                unstash 'artifacts-rocky'

                script {
                    def server = Artifactory.server 'zextras-artifactory'
                    def buildInfo
                    def uploadSpec
                    def config

                    //ubuntu
                    buildInfo = Artifactory.newBuildInfo()
                    buildInfo.name += '-ubuntu'
                    uploadSpec = '''{
                        "files": [
                            {
                                "pattern": "artifacts/*.deb",
                                "target": "ubuntu-rc/pool/",
                                "props": "deb.distribution=focal;deb.distribution=jammy;deb.distribution=noble;deb.component=main;deb.architecture=amd64"
                            }
                        ]
                    }'''
                    server.upload spec: uploadSpec, buildInfo: buildInfo, failNoOp: false
                    config = [
                            'buildName'          : buildInfo.name,
                            'buildNumber'        : buildInfo.number,
                            'sourceRepo'         : 'ubuntu-rc',
                            'targetRepo'         : 'ubuntu-release',
                            'comment'            : 'Do not change anything! Just press the button',
                            'status'             : 'Released',
                            'includeDependencies': false,
                            'copy'               : true,
                            'failFast'           : true
                    ]
                    Artifactory.addInteractivePromotion server: server,
                    promotionConfig: config,
                    displayName: 'Ubuntu Promotion to Release'
                    server.publishBuildInfo buildInfo

                    //rocky8
                    buildInfo = Artifactory.newBuildInfo()
                    buildInfo.name += '-centos8'
                    uploadSpec= '''{
                        "files": [
                            {
                                "pattern": "artifacts/(carbonio-openjdk)-(*).x86_64.rpm",
                                "target": "centos8-rc/zextras/{1}/{1}-{2}.x86_64.rpm",
                                "props": "rpm.metadata.arch=x86_64;rpm.metadata.vendor=zextras",
                                "exclusions": ["*openjdk-cacerts*.rpm"]
                            },
                            {
                                "pattern": "artifacts/(carbonio-openjdk-cacerts)-(*).x86_64.rpm",
                                "target": "centos8-rc/zextras/{1}/{1}-{2}.x86_64.rpm",
                                "props": "rpm.metadata.arch=x86_64;rpm.metadata.vendor=zextras"
                            }
                        ]
                    }'''
                    server.upload spec: uploadSpec, buildInfo: buildInfo, failNoOp: false
                    config = [
                            'buildName'          : buildInfo.name,
                            'buildNumber'        : buildInfo.number,
                            'sourceRepo'         : 'centos8-rc',
                            'targetRepo'         : 'centos8-release',
                            'comment'            : 'Do not change anything! Just press the button',
                            'status'             : 'Released',
                            'includeDependencies': false,
                            'copy'               : true,
                            'failFast'           : true
                    ]
                    Artifactory.addInteractivePromotion server: server,
                    promotionConfig: config,
                    displayName: 'RHEL8 Promotion to Release'
                    server.publishBuildInfo buildInfo

                    //rocky9
                    buildInfo = Artifactory.newBuildInfo()
                    buildInfo.name += '-rhel9'
                    uploadSpec= '''{
                        "files": [
                            {
                                "pattern": "artifacts/(carbonio-openjdk)-(*).x86_64.rpm",
                                "target": "rhel9-rc/zextras/{1}/{1}-{2}.x86_64.rpm",
                                "props": "rpm.metadata.arch=x86_64;rpm.metadata.vendor=zextras",
                                "exclusions": ["*openjdk-cacerts*.rpm"]
                            },
                            {
                                "pattern": "artifacts/(carbonio-openjdk-cacerts)-(*).x86_64.rpm",
                                "target": "rhel9-rc/zextras/{1}/{1}-{2}.x86_64.rpm",
                                "props": "rpm.metadata.arch=x86_64;rpm.metadata.vendor=zextras"
                            }
                        ]
                    }'''
                    server.upload spec: uploadSpec, buildInfo: buildInfo, failNoOp: false
                    config = [
                            'buildName'          : buildInfo.name,
                            'buildNumber'        : buildInfo.number,
                            'sourceRepo'         : 'rhel9-rc',
                            'targetRepo'         : 'rhel9-release',
                            'comment'            : 'Do not change anything! Just press the button',
                            'status'             : 'Released',
                            'includeDependencies': false,
                            'copy'               : true,
                            'failFast'           : true
                    ]
                    Artifactory.addInteractivePromotion server: server,
                    promotionConfig: config,
                    displayName: 'RHEL9 Promotion to Release'
                    server.publishBuildInfo buildInfo
                }
            }
        }
    }
}
