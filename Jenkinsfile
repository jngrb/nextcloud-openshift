pipeline {
    agent any
    stages {
        stage('Build info') {
            steps {
              sh 'env'
            }
        }
        stage('Checkout sources') {
            steps {
                checkout changelog: false, poll: false,
                    scm: [$class: 'GitSCM', branches: [[name: "${env.GIT_BRANCH}"]],
                    doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [],
                    userRemoteConfigs: [[url: "${env.GIT_URL}"]]]
            }
        }
        stage('Rebuild fixed nextcloud image') {
            steps {
                script {
                    if (env.BUILD_FIXED_IMAGE.toBoolean()) {
                        // consider changes in nc_image_fix/Dockerfile
                        openshift.withCluster() {
                            openshift.withProject(/*"${env.PROJECT_NAME}"*/) {
                                def buildSelector = openshift.selector("bc", 'nextcloud-image')
                                buildSelector.startBuild("--follow=true")
                                /* Alternatively to "--follow=true":
                                    * Do some parallel tasks while building.
                                    * When needed to wait for the build again and show logs, do:
                                    * build.logs('-f') */
                            }
                        }
                    }
                }
            }
        }
        stage('Rebuild nginx image') {
            steps {
                script {
                    // consider changes in Dockerfile and nginx.conf
                    openshift.withCluster() {
                        openshift.withProject(/*"${env.PROJECT_NAME}"*/) {
                            def buildSelector = openshift.selector("bc", 'nginx')
                            buildSelector.startBuild("--follow=true")
                            /* Alternatively to "--follow=true":
                                 * Do some parallel tasks while building.
                                 * When needed to wait for the build again and show logs, do:
                                 * build.logs('-f') */
                        }
                    }
                }
            }
        }
        stage('Apply configuration update') {
            steps {
                script {
                    // consider changes in nextcloud.yaml and nextcloud-cron.yaml
                    openshift.withCluster() {
                        openshift.withProject(/*"${env.PROJECT_NAME}"*/) {
                            def template = readFile 'nextcloud.yaml'
                            def config = null
                            if (env.BUILD_FIXED_IMAGE.toBoolean()) {
                                config = openshift.process(template,
                                  '-p', "PVC_SIZE=${env.PVC_SIZE}",
                                  '-p', "NEXTCLOUD_HOST=${env.NEXTCLOUD_HOST}",
                                  '-p', "NEXTCLOUD_IMAGESTREAM_NAME=nextcloud-fixed",
                                  '-p', "NEXTCLOUD_IMAGE_TAG=latest")
                            } else {
                                config = openshift.process(template,
                                  '-p', "PVC_SIZE=${env.PVC_SIZE}",
                                  '-p', "NEXTCLOUD_HOST=${env.NEXTCLOUD_HOST}",
                                  '-p', "NEXTCLOUD_IMAGE_TAG=${env.NEXTCLOUD_IMAGE_TAG}")
                            }
                            openshift.apply(config)

                            def cronTemplate = readFile 'nextcloud-cron.yaml'
                            // The cron job will always be done with the unfixed image
                            def cronConfig = openshift.process(cronTemplate,
                                  '-p', "NEXTCLOUD_IMAGE_TAG=${env.NEXTCLOUD_IMAGE_TAG}")
                            openshift.apply(cronConfig)

                            def templateName = 'nextcloud'
                            /*def rm = openshift.selector("dc", templateName)
                              .rollout().latest()*/
                            timeout(10) {
                                openshift.selector("dc", templateName)
                                  .related('pods').untilEach(1) {
                                    return (it.object().status.phase == "Running")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
